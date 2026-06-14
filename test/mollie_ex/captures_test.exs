defmodule MollieEx.CapturesTest do
  use ExUnit.Case, async: false

  alias MollieEx.Capture
  alias MollieEx.Captures
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.TestSupport
  alias MollieEx.Types.{Link, Money}

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_captures_secret"

  test "creates a capture with camelCased body and caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/payments/tr_123/captures"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert header(conn, "idempotency-key") == "capture-123"

      assert_json_body(conn, %{
        "amount" => %{"currency" => "EUR", "value" => "10.00"},
        "description" => "Capture order #123",
        "metadata" => %{
          "order_id" => "123",
          "nested_meta" => %{"line_id" => "1"}
        }
      })

      fixture_response(conn, "captures/create_success.json", 201)
    end)

    params = %{
      amount: %{currency: "EUR", value: "10.00"},
      description: "Capture order #123",
      metadata: %{"order_id" => "123", "nested_meta" => %{"line_id" => "1"}}
    }

    assert {:ok, %Capture{} = capture} =
             Captures.create(client(), "tr_123", params, idempotency_key: "capture-123")

    assert capture.id == "cpt_123"
    assert capture.status == "pending"

    assert capture.amount == %Money{
             currency: "EUR",
             value: "10.00",
             raw: %{"currency" => "EUR", "value" => "10.00"}
           }

    assert %Link{href: "https://api.mollie.com/v2/payments/tr_123"} =
             capture.links["payment"]

    assert capture.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "adds testmode for OAuth create requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "amount" => %{"currency" => "EUR", "value" => "10.00"},
        "description" => "Capture order #123",
        "testmode" => false
      })

      fixture_response(conn, "captures/create_success.json", 201)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %Capture{id: "cpt_123"}} =
             Captures.create(
               client,
               "tr_123",
               %{amount: %{currency: "EUR", value: "10.00"}, description: "Capture order #123"},
               testmode: false
             )
  end

  test "honors params-level testmode for OAuth create requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "description" => "Capture order #123",
        "testmode" => false
      })

      fixture_response(conn, "captures/create_success.json", 201)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %Capture{id: "cpt_123"}} =
             Captures.create(client, "tr_123", %{
               description: "Capture order #123",
               testmode: false
             })
  end

  test "retrieves a capture with embed and OAuth testmode query params" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/payments/tr_123/captures/cpt_123"
      assert URI.decode_query(conn.query_string) == %{"embed" => "payment", "testmode" => "false"}
      assert_empty_body(conn)

      fixture_response(conn, "captures/create_success.json", 200)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %Capture{id: "cpt_123"}} =
             Captures.get(client, "tr_123", "cpt_123", embed: "payment", testmode: false)
  end

  test "lists captures with pagination and embed options" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/payments/tr_123/captures"

      assert URI.decode_query(conn.query_string) == %{
               "embed" => "payment",
               "from" => "cpt_from",
               "limit" => "1"
             }

      assert_empty_body(conn)

      fixture_response(conn, "captures/list_success.json", 200)
    end)

    assert {:ok, %MollieList{} = capture_list} =
             Captures.list(client(), "tr_123", from: "cpt_from", limit: 1, embed: "payment")

    assert capture_list.count == 1
    assert [%Capture{id: "cpt_list_123", status: "succeeded"}] = capture_list.data

    assert %Link{
             href: "https://api.mollie.com/v2/payments/tr_123/captures?from=cpt_next&limit=1"
           } = capture_list.links["next"]
  end

  test "adds testmode query param for OAuth list requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert URI.decode_query(conn.query_string) == %{"testmode" => "false"}
      fixture_response(conn, "captures/list_success.json", 200)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %MollieList{}} = Captures.list(client, "tr_123", testmode: false)
  end

  test "rejects testmode for unsupported capture requests before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "cpt_123"})
    end)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Captures.create(client(), "tr_123", %{description: "Capture", testmode: true})

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Captures.create(client(), "tr_123", %{description: "Capture"}, testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Captures.get(client(), "tr_123", "cpt_123", testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Captures.list(client(), "tr_123", testmode: true)

    refute_receive :request_sent, 10
  end

  test "does not retry capture create without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    assert {:error, %Error{type: :server_error, status: 503}} =
             Captures.create(client(max_retries: 1), "tr_123", %{description: "Capture"})
  end

  test "retries capture create with the same caller idempotency key and body" do
    expected_body = %{
      "amount" => %{"currency" => "EUR", "value" => "10.00"},
      "description" => "Capture order #123"
    }

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "capture-123"
      assert_json_body(conn, expected_body)

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "capture-123"
      assert_json_body(conn, expected_body)
      fixture_response(conn, "captures/create_success.json", 201)
    end)

    assert {:ok, %Capture{id: "cpt_123"}} =
             Captures.create(
               client(max_retries: 1),
               "tr_123",
               %{amount: %{currency: "EUR", value: "10.00"}, description: "Capture order #123"},
               idempotency_key: "capture-123"
             )
  end

  test "retries safe capture get requests without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil
      fixture_response(conn, "captures/create_success.json", 200)
    end)

    assert {:ok, %Capture{id: "cpt_123"}} =
             Captures.get(client(max_retries: 1), "tr_123", "cpt_123")
  end

  test "returns API errors for capture calls" do
    cases = [
      {:create, 422, :validation},
      {:get, 404, :not_found},
      {:list, 400, :api_error}
    ]

    for {operation, status, type} <- cases do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(status)
        |> Req.Test.json(%{
          "status" => status,
          "title" => "Capture error",
          "_links" => %{"documentation" => %{"href" => "https://docs.mollie.com/"}}
        })
      end)

      assert {:error, %Error{} = error} = call_operation(operation, client(max_retries: 0))
      assert error.type == type
      assert error.status == status
      assert error.raw["title"] == "Capture error"
    end
  end

  test "returns timeout errors for capture calls" do
    for {operation, expected_operation} <- [
          {:create, :captures_create},
          {:get, :captures_get},
          {:list, :captures_list}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, %Error{} = error} = call_operation(operation, client(max_retries: 0))
      assert error.type == :timeout
      assert error.operation == expected_operation
    end
  end

  test "returns decode errors for malformed JSON responses" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.send_resp(200, "{")
    end)

    assert {:error, %Error{} = error} = Captures.get(client(), "tr_123", "cpt_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.operation == :captures_get
  end

  test "returns decode errors for invalid capture response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"status" => "pending"})
    end)

    assert {:error, %Error{} = error} = Captures.get(client(), "tr_123", "cpt_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_capture_response
    assert error.operation == :captures_get
    assert error.raw == %{"status" => "pending"}
  end

  test "returns decode errors for invalid capture list response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"count" => 1, "_embedded" => %{"captures" => %{}}, "_links" => %{}})
    end)

    assert {:error, %Error{} = error} = Captures.list(client(), "tr_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_list_response
    assert error.operation == :captures_list
  end

  test "returns decode errors for invalid embedded capture list items" do
    invalid_capture = %{"status" => "pending"}

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"captures" => [invalid_capture]},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{} = error} = Captures.list(client(), "tr_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_capture_response
    assert error.operation == :captures_list
    assert error.raw == invalid_capture
  end

  test "rejects invalid local inputs before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "cpt_123"})
    end)

    assert {:error, %Error{reason: :invalid_capture_params}} =
             Captures.create(client(), "tr_123", "bad")

    assert {:error, %Error{reason: :invalid_payment_id}} =
             Captures.create(client(), "", %{description: "Capture"})

    assert {:error, %Error{reason: :invalid_capture_id}} =
             Captures.get(client(), "tr_123", "")

    assert {:error, %Error{reason: :invalid_payment_id}} =
             Captures.list(client(), "")

    assert {:error, %Error{reason: :invalid_options}} =
             Captures.create(client(), "tr_123", %{description: "Capture"}, "bad")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Captures.create(client(), "tr_123", %{description: "Capture"}, unknown: true)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Captures.get(client(), "tr_123", "cpt_123", unknown: true)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Captures.list(client(), "tr_123", unknown: true)

    assert {:error, %Error{reason: {:invalid_option, :from}}} =
             Captures.list(client(), "tr_123", from: "")

    assert {:error, %Error{reason: {:invalid_option, :limit}}} =
             Captures.list(client(), "tr_123", limit: 251)

    assert {:error, %Error{reason: :invalid_testmode}} =
             Captures.create(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               "tr_123",
               %{description: "Capture"},
               testmode: "true"
             )

    assert {:error, %Error{reason: :invalid_testmode}} =
             Captures.get(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               "tr_123",
               "cpt_123",
               testmode: "true"
             )

    assert {:error, %Error{reason: :invalid_testmode}} =
             Captures.list(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               "tr_123",
               testmode: "true"
             )

    refute_receive :request_sent, 10
  end

  test "emits safe request telemetry for successful capture calls" do
    prefix = [:mollie_captures_test_success]
    attach_telemetry(prefix, [[:request, :start], [:request, :stop]])

    Req.Test.expect(__MODULE__, fn conn ->
      fixture_response(conn, "captures/create_success.json", 201)
    end)

    assert {:ok, %Capture{}} =
             Captures.create(
               client(telemetry_prefix: prefix),
               "tr_123",
               %{description: "Capture order #123"},
               idempotency_key: "capture-123"
             )

    assert_success_telemetry(
      prefix,
      :captures_create,
      "POST",
      "/payments/{paymentId}/captures",
      201,
      [@api_key, "capture-123", "Capture order #123", "authorization"]
    )

    Req.Test.expect(__MODULE__, fn conn ->
      fixture_response(conn, "captures/create_success.json", 200)
    end)

    assert {:ok, %Capture{}} =
             Captures.get(client(telemetry_prefix: prefix), "tr_123", "cpt_123")

    assert_success_telemetry(
      prefix,
      :captures_get,
      "GET",
      "/payments/{paymentId}/captures/{captureId}",
      200,
      [@api_key, "capture-123", "Capture order #123", "authorization"]
    )

    Req.Test.expect(__MODULE__, fn conn ->
      fixture_response(conn, "captures/list_success.json", 200)
    end)

    assert {:ok, %MollieList{}} =
             Captures.list(client(telemetry_prefix: prefix), "tr_123")

    assert_success_telemetry(
      prefix,
      :captures_list,
      "GET",
      "/payments/{paymentId}/captures",
      200,
      [@api_key, "capture-123", "Capture order #123", "authorization"]
    )
  end

  test "emits safe decode exception and rate limit telemetry" do
    prefix = [:mollie_captures_test_errors]

    attach_telemetry(prefix, [
      [:request, :start],
      [:request, :stop],
      [:request, :exception],
      [:decode, :exception],
      [:rate_limit]
    ])

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"status" => "pending"})
    end)

    assert {:error, %Error{type: :decode}} =
             Captures.get(client(telemetry_prefix: prefix), "tr_123", "cpt_123")

    decode_event = prefix ++ [:decode, :exception]
    request_exception_event = prefix ++ [:request, :exception]

    assert_receive {:telemetry, ^decode_event, %{duration: _duration}, decode_metadata}
    assert decode_metadata.error_type == :decode
    assert decode_metadata.reason == :invalid_capture_response
    assert decode_metadata.path_template == "/payments/{paymentId}/captures/{captureId}"

    assert_receive {:telemetry, ^request_exception_event, %{duration: _duration},
                    exception_metadata}

    assert exception_metadata.error_type == :decode

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(429)
      |> Req.Test.json(%{"status" => 429, "title" => "Too Many Requests"})
    end)

    assert {:error, %Error{type: :rate_limited}} =
             Captures.get(client(telemetry_prefix: prefix, max_retries: 0), "tr_123", "cpt_123")

    rate_limit_event = prefix ++ [:rate_limit]
    stop_event = prefix ++ [:request, :stop]

    assert_receive {:telemetry, ^stop_event, %{duration: _duration}, stop_metadata}
    assert stop_metadata.status == 429
    assert stop_metadata.error_type == :rate_limited

    assert_receive {:telemetry, ^rate_limit_event, %{duration: _duration}, rate_limit_metadata}
    assert rate_limit_metadata.status == 429
    assert rate_limit_metadata.error_type == :rate_limited

    telemetry_text =
      inspect([decode_metadata, exception_metadata, stop_metadata, rate_limit_metadata])

    refute telemetry_text =~ @api_key
    refute telemetry_text =~ "Too Many Requests"
    refute telemetry_text =~ "authorization"
  end

  defp call_operation(:create, client) do
    Captures.create(client, "tr_123", %{description: "Capture order #123"})
  end

  defp call_operation(:get, client), do: Captures.get(client, "tr_123", "cpt_123")
  defp call_operation(:list, client), do: Captures.list(client, "tr_123")

  defp client(opts \\ []) do
    [api_key: @api_key]
    |> Keyword.merge(opts)
    |> then(&TestSupport.client(__MODULE__, &1))
  end
end
