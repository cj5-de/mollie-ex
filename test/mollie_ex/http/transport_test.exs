defmodule MollieEx.HTTP.TransportTest do
  use ExUnit.Case, async: true

  alias Finch.Pool.Manager, as: FinchPoolManager
  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.{Request, Response, Transport}

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_transport_secret"

  defmodule UnencodableBody do
    defstruct [:marker]
  end

  test "sends method path headers and JSON body through Req.Test" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/payments"
      assert conn.query_string == "include=details"
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert header(conn, "user-agent") =~ ~r/^mollie_ex\/.+ elixir\/.+ otp\/.+/
      assert header(conn, "idempotency-key") == "order-123"

      assert {:ok, %{"description" => "Order #123"}} =
               conn
               |> Req.Test.raw_body()
               |> IO.iodata_to_binary()
               |> Jason.decode()

      Req.Test.json(conn, %{"id" => "tr_123", "status" => "open"})
    end)

    client = client()

    request = %Request{
      method: :post,
      path: "/payments",
      query: [include: "details"],
      body: %{"description" => "Order #123"},
      idempotency_key: " order-123 ",
      idempotency_policy: :optional,
      operation: :payments_create
    }

    assert {:ok, %Response{} = response} = Transport.request(client, request)
    assert response.status == 200
    assert response.body == %{"id" => "tr_123", "status" => "open"}
    assert response.raw == response.body
  end

  test "maps JSON encoding failures into SDK errors before auth and transport" do
    test_pid = self()
    marker = "json-body-secret-marker"

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    client =
      Client.new!(
        api_key: fn ->
          send(test_pid, :auth_resolved)
          @api_key
        end,
        transport: {:req_test, __MODULE__}
      )

    request = %Request{
      method: :post,
      path: "/payments",
      body: %{"payload" => %UnencodableBody{marker: marker}},
      idempotency_key: "order-123",
      idempotency_policy: :optional,
      operation: :payments_create
    }

    assert {:error, %Error{} = error} = Transport.request(client, request)
    assert error.type == :configuration
    assert error.reason == :invalid_json_body
    assert error.method == :post
    assert error.path == "/payments"
    assert error.operation == :payments_create
    assert error.body == nil
    assert error.raw == nil

    refute_receive :auth_resolved, 10
    refute_receive :request_sent, 10

    rendered =
      Enum.join([inspect(error), Exception.message(error), inspect(Map.from_struct(error))], "\n")

    refute rendered =~ marker
  end

  test "does not send custom transport-owned headers" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert headers(conn, "authorization") == ["Bearer #{@api_key}"]
      assert headers(conn, "accept") == ["application/json"]
      assert headers(conn, "content-type") == ["application/json"]
      assert headers(conn, "user-agent") == [header(conn, "user-agent")]
      assert header(conn, "user-agent") =~ ~r/^mollie_ex\/.+ elixir\/.+ otp\/.+/
      assert headers(conn, "idempotency-key") == ["order-123"]
      assert header(conn, "x-request-trace") == "trace-123"
      assert header(conn, "x-atom-trace") == "atom-trace"

      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    request = %Request{
      method: :post,
      path: "/payments",
      headers: [
        {"authorization", "Bearer caller"},
        {"Authorization", "Bearer caller-2"},
        {:authorization, "Bearer atom-caller"},
        {"accept", "text/plain"},
        {"content-type", "text/plain"},
        {:user_agent, "caller-agent"},
        {"idempotency-key", "caller-key"},
        {"x-request-trace", "trace-123"},
        {:x_atom_trace, "atom-trace"}
      ],
      body: %{"description" => "Order #123"},
      idempotency_key: "order-123",
      idempotency_policy: :optional
    }

    assert {:ok, %Response{}} = Transport.request(client(), request)
  end

  test "does not send unsupported idempotency keys" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil
      assert headers(conn, "idempotency-key") == []

      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    request = %Request{
      method: :get,
      path: "/payments/tr_123",
      headers: [
        {"idempotency-key", "header-key"},
        {"Idempotency-Key", "header-key-2"},
        idempotency_key: "atom-header-key"
      ],
      idempotency_key: "order-123",
      idempotency_policy: :unsupported
    }

    assert {:ok, %Response{}} = Transport.request(client(), request)
  end

  test "sends only policy-owned idempotency keys when custom headers include one" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert headers(conn, "idempotency-key") == ["order-123"]

      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    request = %Request{
      method: :post,
      path: "/payments",
      headers: [
        {"idempotency-key", "header-key"},
        {"Idempotency-Key", "header-key-2"},
        idempotency_key: "atom-header-key"
      ],
      body: %{"description" => "Order #123"},
      idempotency_key: "order-123",
      idempotency_policy: :optional
    }

    assert {:ok, %Response{}} = Transport.request(client(), request)
  end

  test "decodes HAL JSON successful responses" do
    body = %{
      "id" => "tr_123",
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/payments/tr_123",
          "type" => "application/hal+json"
        }
      }
    }

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/hal+json")
      |> Plug.Conn.send_resp(200, Jason.encode!(body))
    end)

    request = %Request{method: :get, path: "/payments/tr_123"}

    assert {:ok, %Response{} = response} = Transport.request(client(), request)
    assert response.body == body
    assert response.raw == body
  end

  test "keeps non-JSON response bodies raw" do
    body = ~s({"id":"tr_123"})

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "text/plain")
      |> Plug.Conn.send_resp(200, body)
    end)

    request = %Request{method: :get, path: "/payments/tr_123"}

    assert {:ok, %Response{body: ^body, raw: ^body}} = Transport.request(client(), request)
  end

  test "retries safe GET requests on transient server errors" do
    Req.Test.expect(__MODULE__, fn conn ->
      transient_json(conn, 503)
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    client = Client.new!(api_key: @api_key, transport: {:req_test, __MODULE__}, max_retries: 1)
    request = %Request{method: :get, path: "/payments/tr_123"}

    assert {:ok, %Response{body: %{"id" => "tr_123"}}} = Transport.request(client, request)
  end

  test "does not retry when retry policy is disabled" do
    Req.Test.expect(__MODULE__, fn conn ->
      transient_json(conn, 503)
    end)

    client = Client.new!(api_key: @api_key, transport: {:req_test, __MODULE__}, max_retries: 1)
    request = %Request{method: :get, path: "/payments/tr_123", retry_policy: :disabled}

    assert {:error, %Error{type: :server_error, status: 503}} =
             Transport.request(client, request)
  end

  test "does not retry writes without an idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      transient_json(conn, 503)
    end)

    client = Client.new!(api_key: @api_key, transport: {:req_test, __MODULE__}, max_retries: 1)

    request = %Request{
      method: :post,
      path: "/payments",
      body: %{"description" => "Order #123"},
      idempotency_policy: :optional
    }

    assert {:error, %Error{type: :server_error, status: 503}} =
             Transport.request(client, request)
  end

  test "does not follow redirects for non-idempotent writes" do
    body = %{"description" => "Order #123"}

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/payments"
      assert header(conn, "idempotency-key") == nil
      assert_json_body(conn, body)

      conn
      |> Plug.Conn.put_resp_header("location", "/v2/redirected-payments")
      |> Plug.Conn.put_status(307)
      |> Req.Test.json(%{"status" => 307})
    end)

    client = Client.new!(api_key: @api_key, transport: {:req_test, __MODULE__}, max_retries: 1)

    request = %Request{
      method: :post,
      path: "/payments",
      body: body,
      idempotency_policy: :optional
    }

    assert {:error, %Error{type: :api_error, status: 307}} =
             Transport.request(client, request)
  end

  test "retries idempotent writes with the same key and body" do
    body = %{"description" => "Order #123"}

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "order-123"
      assert_json_body(conn, body)

      transient_json(conn, 503)
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "order-123"
      assert_json_body(conn, body)

      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    client = Client.new!(api_key: @api_key, transport: {:req_test, __MODULE__}, max_retries: 1)

    request = %Request{
      method: :post,
      path: "/payments",
      body: body,
      idempotency_key: "order-123",
      idempotency_policy: :optional
    }

    assert {:ok, %Response{body: %{"id" => "tr_123"}}} = Transport.request(client, request)
  end

  test "honors the client retry budget" do
    Req.Test.expect(__MODULE__, 2, fn conn ->
      transient_json(conn, 503)
    end)

    client = Client.new!(api_key: @api_key, transport: {:req_test, __MODULE__}, max_retries: 1)
    request = %Request{method: :get, path: "/payments/tr_123"}

    assert {:error, %Error{type: :server_error, status: 503}} =
             Transport.request(client, request)
  end

  test "falls back to exponential retry delay for malformed Retry-After headers" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("retry-after", "not-a-date")
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    client = Client.new!(api_key: @api_key, transport: {:req_test, __MODULE__}, max_retries: 1)
    request = %Request{method: :get, path: "/payments/tr_123"}

    assert {:ok, %Response{body: %{"id" => "tr_123"}}} = Transport.request(client, request)
  end

  test "falls back to exponential retry delay for duplicate Retry-After headers" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.prepend_resp_headers([{"retry-after", "0"}, {"retry-after", "1"}])
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    client = Client.new!(api_key: @api_key, transport: {:req_test, __MODULE__}, max_retries: 1)
    request = %Request{method: :get, path: "/payments/tr_123"}

    assert {:ok, %Response{body: %{"id" => "tr_123"}}} = Transport.request(client, request)
  end

  test "rejects missing required idempotency keys before sending" do
    client =
      Client.new!(
        api_key: fn -> raise "auth should not be resolved" end,
        transport: {:req_test, __MODULE__}
      )

    for key <- [nil, "", "  "] do
      request = %Request{
        method: :post,
        path: "/transfers",
        idempotency_key: key,
        idempotency_policy: :required,
        operation: :transfers_create
      }

      assert {:error, %Error{} = error} = Transport.request(client, request)
      assert error.type == :configuration
      assert error.reason == :missing_idempotency_key
      assert error.method == :post
      assert error.path == "/transfers"
      assert error.operation == :transfers_create
    end
  end

  test "rejects header-unsafe optional idempotency keys before auth and transport" do
    test_pid = self()
    marker = "marker-crlf-key"
    unsafe_key = marker <> "\r\nX-Leak: yes"

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    client =
      Client.new!(
        api_key: fn ->
          send(test_pid, :auth_resolved)
          @api_key
        end,
        transport: {:req_test, __MODULE__}
      )

    request = %Request{
      method: :post,
      path: "/payments",
      body: %{"description" => "Order #123"},
      idempotency_key: unsafe_key,
      idempotency_policy: :optional,
      operation: :payments_create
    }

    assert {:error, %Error{} = error} = Transport.request(client, request)
    assert error.type == :configuration
    assert error.reason == :invalid_idempotency_key
    assert error.method == :post
    assert error.path == "/payments"
    assert error.operation == :payments_create
    assert error.idempotency_key_fingerprint =~ ~r/^sha256:[0-9a-f]{16}$/

    refute_receive :auth_resolved, 10
    refute_receive :request_sent, 10

    rendered =
      Enum.join([inspect(error), Exception.message(error), inspect(Map.from_struct(error))], "\n")

    refute rendered =~ marker
    refute rendered =~ "X-Leak"
  end

  test "rejects non-ASCII optional idempotency keys before auth and transport" do
    test_pid = self()
    marker = "order-é"

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    client =
      Client.new!(
        api_key: fn ->
          send(test_pid, :auth_resolved)
          @api_key
        end,
        transport: {:req_test, __MODULE__}
      )

    request = %Request{
      method: :post,
      path: "/payments",
      body: %{"description" => "Order #123"},
      idempotency_key: marker,
      idempotency_policy: :optional,
      operation: :payments_create
    }

    assert {:error, %Error{} = error} = Transport.request(client, request)
    assert error.type == :configuration
    assert error.reason == :invalid_idempotency_key
    assert error.method == :post
    assert error.path == "/payments"
    assert error.operation == :payments_create
    assert error.idempotency_key_fingerprint =~ ~r/^sha256:[0-9a-f]{16}$/

    refute_receive :auth_resolved, 10
    refute_receive :request_sent, 10

    rendered =
      Enum.join([inspect(error), Exception.message(error), inspect(Map.from_struct(error))], "\n")

    refute rendered =~ marker
  end

  test "rejects non-binary optional idempotency keys before auth and transport" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    client =
      Client.new!(
        api_key: fn ->
          send(test_pid, :auth_resolved)
          @api_key
        end,
        transport: {:req_test, __MODULE__}
      )

    for key <- [123, :order_key, %{key: "order-123"}] do
      request = %Request{
        method: :post,
        path: "/payments",
        body: %{"description" => "Order #123"},
        idempotency_key: key,
        idempotency_policy: :optional,
        operation: :payments_create
      }

      assert {:error, %Error{} = error} = Transport.request(client, request)
      assert error.type == :configuration
      assert error.reason == :invalid_idempotency_key
      assert error.method == :post
      assert error.path == "/payments"
      assert error.operation == :payments_create
      assert error.idempotency_key_fingerprint =~ ~r/^sha256:[0-9a-f]{16}$/
    end

    refute_receive :auth_resolved, 10
    refute_receive :request_sent, 10
  end

  test "rejects header-unsafe required idempotency keys before sending" do
    client =
      Client.new!(
        api_key: fn -> raise "auth should not be resolved" end,
        transport: {:req_test, __MODULE__}
      )

    for {key, marker} <- [
          {"order-123\t", "order-123"},
          {"order-123" <> <<0>>, "order-123"},
          {"order-123" <> <<255>>, "order-123"},
          {"order-é", "order-é"}
        ] do
      request = %Request{
        method: :post,
        path: "/transfers",
        idempotency_key: key,
        idempotency_policy: :required,
        operation: :transfers_create
      }

      assert {:error, %Error{} = error} = Transport.request(client, request)
      assert error.type == :configuration
      assert error.reason == :invalid_idempotency_key
      assert error.method == :post
      assert error.path == "/transfers"
      assert error.operation == :transfers_create
      assert error.idempotency_key_fingerprint =~ ~r/^sha256:[0-9a-f]{16}$/

      refute inspect(error) =~ marker
      refute Exception.message(error) =~ marker
    end
  end

  test "maps API errors into SDK errors with response diagnostics" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("x-request-id", "req_123")
      |> Plug.Conn.put_status(422)
      |> Req.Test.json(%{
        "title" => "Unprocessable Entity",
        "detail" => "api_key=raw_secret",
        "field" => "amount.value",
        "_links" => %{
          "documentation" => %{
            "href" => "https://docs.mollie.com/reference/error-handling",
            "type" => "text/html"
          }
        },
        "extra" => "preserved"
      })
    end)

    request = %Request{method: :get, path: "/payments/tr_123", operation: :payments_get}

    assert {:error, %Error{} = error} = Transport.request(client(), request)
    assert error.type == :validation
    assert error.status == 422
    assert error.method == :get
    assert error.path == "/payments/tr_123"
    assert error.operation == :payments_get
    assert error.request_id == "req_123"
    assert error.title == "Unprocessable Entity"
    assert error.detail == "api_key=[REDACTED]"
    assert error.field == "amount.value"

    assert error.links == %{
             "documentation" => %{
               "href" => "https://docs.mollie.com/reference/error-handling",
               "type" => "text/html"
             }
           }

    assert error.raw["detail"] == "api_key=[REDACTED]"
    assert error.raw["extra"] == "preserved"
  end

  test "maps HAL JSON API errors into SDK errors with response diagnostics" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "Application/Hal+Json; charset=utf-8")
      |> Plug.Conn.put_resp_header("x-request-id", "req_hal_123")
      |> Plug.Conn.put_status(422)
      |> Plug.Conn.send_resp(
        422,
        Jason.encode!(%{
          "title" => "Unprocessable Entity",
          "detail" => "The amount is invalid.",
          "field" => "amount.value",
          "_links" => %{
            "documentation" => %{
              "href" => "https://docs.mollie.com/reference/error-handling",
              "type" => "text/html"
            }
          }
        })
      )
    end)

    request = %Request{method: :get, path: "/payments/tr_123", operation: :payments_get}

    assert {:error, %Error{} = error} = Transport.request(client(), request)
    assert error.type == :validation
    assert error.status == 422
    assert error.request_id == "req_hal_123"
    assert error.title == "Unprocessable Entity"
    assert error.detail == "The amount is invalid."
    assert error.field == "amount.value"

    assert error.links == %{
             "documentation" => %{
               "href" => "https://docs.mollie.com/reference/error-handling",
               "type" => "text/html"
             }
           }

    assert error.raw["_links"] == error.links
  end

  test "maps common API status codes" do
    cases = [
      {401, :authentication},
      {403, :authorization},
      {404, :not_found},
      {408, :timeout},
      {429, :rate_limited},
      {504, :timeout},
      {500, :server_error}
    ]

    for {status, type} <- cases do
      name = :"#{__MODULE__}.#{status}"

      Req.Test.expect(name, fn conn ->
        conn
        |> Plug.Conn.put_status(status)
        |> Req.Test.json(%{"status" => status})
      end)

      client = Client.new!(api_key: @api_key, transport: {:req_test, name})
      request = %Request{method: :get, path: "/payments/tr_123", retry_policy: :disabled}

      assert {:error, %Error{type: ^type, status: ^status}} = Transport.request(client, request)
    end
  end

  test "maps malformed JSON into decode errors with redacted raw body" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, "api_key=raw_secret")
    end)

    request = %Request{method: :get, path: "/payments/tr_123"}

    assert {:error, %Error{} = error} = Transport.request(client(), request)
    assert error.type == :decode
    assert error.status == 200
    assert error.raw == "api_key=[REDACTED]"
  end

  test "maps Req transport timeouts into timeout errors" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    request = %Request{method: :get, path: "/payments/tr_123", retry_policy: :disabled}

    assert {:error, %Error{} = error} = Transport.request(client(), request)
    assert error.type == :timeout
    assert error.path == "/payments/tr_123"
  end

  test "rejects invalid per-call timeout overrides before Req" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    request = %Request{
      method: :get,
      path: "/payments/tr_123",
      operation: :payments_get,
      retry_policy: :disabled
    }

    for opts <- [
          [pool_timeout: nil],
          [receive_timeout: "1000"],
          [request_timeout: 0]
        ] do
      assert {:error, %Error{} = error} = Transport.request(client(), request, opts)
      assert error.type == :configuration
      assert error.reason == :invalid_timeout
      assert error.method == :get
      assert error.path == "/payments/tr_123"
      assert error.operation == :payments_get
    end

    refute_receive :request_sent, 10
  end

  test "preserves Req transport error reasons" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.transport_error(conn, :econnrefused)
    end)

    request = %Request{method: :get, path: "/payments/tr_123", retry_policy: :disabled}

    assert {:error, %Error{} = error} = Transport.request(client(), request)
    assert error.type == :transport
    assert error.reason == :econnrefused
    assert error.path == "/payments/tr_123"
  end

  test "preserves Req HTTP error reasons" do
    Req.Test.expect(__MODULE__, fn conn ->
      Plug.Conn.put_private(
        conn,
        :req_test_exception,
        Req.HTTPError.exception(protocol: :http2, reason: :pool_not_available)
      )
    end)

    request = %Request{method: :get, path: "/payments/tr_123", retry_policy: :disabled}

    assert {:error, %Error{} = error} = Transport.request(client(), request)
    assert error.type == :transport
    assert error.reason == :pool_not_available
    assert error.path == "/payments/tr_123"
  end

  test "retries safe GET requests on HTTP/2 connection closed errors" do
    Req.Test.expect(__MODULE__, fn conn ->
      http2_error(conn, :connection_closed)
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    client = Client.new!(api_key: @api_key, transport: {:req_test, __MODULE__}, max_retries: 1)
    request = %Request{method: :get, path: "/payments/tr_123"}

    assert {:ok, %Response{body: %{"id" => "tr_123"}}} = Transport.request(client, request)
  end

  test "retries idempotent writes on HTTP/2 disconnected errors" do
    body = %{"description" => "Order #123"}

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "order-123"
      assert_json_body(conn, body)

      http2_error(conn, :disconnected)
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "order-123"
      assert_json_body(conn, body)

      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    client = Client.new!(api_key: @api_key, transport: {:req_test, __MODULE__}, max_retries: 1)

    request = %Request{
      method: :post,
      path: "/payments",
      body: body,
      idempotency_key: "order-123",
      idempotency_policy: :optional
    }

    assert {:ok, %Response{body: %{"id" => "tr_123"}}} = Transport.request(client, request)
  end

  test "does not retry non-idempotent writes on HTTP/2 disconnected errors" do
    body = %{"description" => "Order #123"}

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil
      assert_json_body(conn, body)

      http2_error(conn, :disconnected)
    end)

    client = Client.new!(api_key: @api_key, transport: {:req_test, __MODULE__}, max_retries: 1)

    request = %Request{
      method: :post,
      path: "/payments",
      body: body,
      idempotency_policy: :optional
    }

    assert {:error, %Error{} = error} = Transport.request(client, request)
    assert error.type == :transport
    assert error.reason == :disconnected
  end

  test "maps live Finch receive timeouts into timeout errors" do
    {:ok, listen_socket} =
      :gen_tcp.listen(0, [
        :binary,
        active: false,
        packet: :raw,
        reuseaddr: true,
        ip: {127, 0, 0, 1}
      ])

    {:ok, port} = :inet.port(listen_socket)
    test_pid = self()

    server_pid =
      spawn(fn ->
        {:ok, socket} = :gen_tcp.accept(listen_socket)
        send(test_pid, :slow_server_accepted)
        Process.sleep(100)
        :gen_tcp.close(socket)
        :gen_tcp.close(listen_socket)
      end)

    on_exit(fn ->
      Process.exit(server_pid, :kill)
      :gen_tcp.close(listen_socket)
    end)

    finch_name = :"#{__MODULE__}.TimeoutFinch.#{System.unique_integer([:positive])}"
    start_supervised!({Finch, name: finch_name})

    client =
      Client.new!(
        api_key: @api_key,
        base_url: "http://127.0.0.1:#{port}/v2",
        finch_name: finch_name,
        receive_timeout: 50,
        request_timeout: 200,
        max_retries: 0
      )

    request = %Request{method: :get, path: "/slow", retry_policy: :disabled}

    assert {:error, %Error{} = error} = Transport.request(client, request)
    assert_receive :slow_server_accepted
    assert error.type == :timeout
    assert error.path == "/slow"
  end

  test "maps live Finch pool checkout timeouts into timeout errors" do
    bypass = Bypass.open()
    test_pid = self()
    finch_name = :"#{__MODULE__}.PoolTimeoutFinch.#{System.unique_integer([:positive])}"

    start_supervised!(
      {Finch,
       name: finch_name,
       pools: %{
         :default => [size: 1, count: 1]
       }}
    )

    Bypass.expect(bypass, "GET", "/v2/hold", fn conn ->
      send(test_pid, :pool_connection_checked_out)
      Process.sleep(500)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "held"}))
    end)

    holder =
      Task.async(fn ->
        Req.get!(
          "http://localhost:#{bypass.port}/v2/hold",
          finch: finch_name,
          receive_timeout: 1_000,
          pool_timeout: 100
        )
      end)

    assert_receive :pool_connection_checked_out, 1_000

    client =
      Client.new!(
        api_key: @api_key,
        base_url: "http://localhost:#{bypass.port}/v2",
        finch_name: finch_name,
        pool_timeout: 10,
        receive_timeout: 1_000,
        request_timeout: 1_000,
        max_retries: 0
      )

    request = %Request{method: :get, path: "/payments/tr_123", retry_policy: :disabled}

    assert {:error, %Error{} = error} = Transport.request(client, request)
    assert error.type == :timeout
    assert error.reason == :timeout

    assert %Req.Response{status: 200} = Task.await(holder, 2_000)
  end

  test "maps missing custom Finch supervisors into transport errors" do
    finch_name = :"#{__MODULE__}.MissingFinch.#{System.unique_integer([:positive])}"

    client =
      Client.new!(
        api_key: @api_key,
        base_url: "http://127.0.0.1:9/v2",
        finch_name: finch_name,
        max_retries: 0
      )

    request = %Request{method: :get, path: "/payments/tr_123", retry_policy: :disabled}

    assert {:error, %Error{} = error} = Transport.request(client, request)
    assert error.type == :transport
    assert error.reason == :finch_not_started
    assert error.path == "/payments/tr_123"
  end

  test "resolves function credentials at the transport boundary" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "authorization") == "Bearer #{@api_key}"

      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    client = Client.new!(api_key: fn -> @api_key end, transport: {:req_test, __MODULE__})
    request = %Request{method: :get, path: "/payments/tr_123"}

    assert {:ok, %Response{}} = Transport.request(client, request)
  end

  test "uses a caller supplied Finch instance" do
    bypass = Bypass.open()
    finch_name = :"#{__MODULE__}.Finch.#{System.unique_integer([:positive])}"

    start_supervised!(
      {Finch,
       name: finch_name,
       pools: %{
         :default => [size: 1, count: 2]
       }}
    )

    Bypass.expect(bypass, "GET", "/v2/payments/tr_123", fn conn ->
      assert header(conn, "authorization") == "Bearer #{@api_key}"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "tr_123"}))
    end)

    client =
      Client.new!(
        api_key: @api_key,
        base_url: "http://localhost:#{bypass.port}/v2",
        finch_name: finch_name
      )

    request = %Request{method: :get, path: "/payments/tr_123"}

    assert {:ok, %Response{body: %{"id" => "tr_123"}}} = Transport.request(client, request)

    assert {_pid, _pool_name, _pool_mod, pool_count, pool_config} =
             FinchPoolManager.get_pool_supervisor(
               finch_name,
               Finch.Pool.new("http://localhost:#{bypass.port}/v2")
             )

    assert pool_count == 2
    assert pool_config.size == 1
  end

  defp client do
    Client.new!(api_key: @api_key, transport: {:req_test, __MODULE__})
  end

  defp header(conn, name) do
    conn.req_headers
    |> List.keyfind(name, 0)
    |> case do
      {^name, value} -> value
      nil -> nil
    end
  end

  defp headers(conn, name) do
    for {^name, value} <- conn.req_headers, do: value
  end

  defp http2_error(conn, reason) do
    Plug.Conn.put_private(
      conn,
      :req_test_exception,
      Req.HTTPError.exception(protocol: :http2, reason: reason)
    )
  end

  defp transient_json(conn, status) do
    conn
    |> Plug.Conn.put_resp_header("retry-after", "0")
    |> Plug.Conn.put_status(status)
    |> Req.Test.json(%{"status" => status})
  end

  defp assert_json_body(conn, expected) do
    assert {:ok, decoded} =
             conn
             |> Req.Test.raw_body()
             |> IO.iodata_to_binary()
             |> Jason.decode()

    assert decoded == expected
  end
end
