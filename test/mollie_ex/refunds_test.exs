defmodule MollieEx.RefundsTest do
  use ExUnit.Case, async: false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Refund
  alias MollieEx.Refunds
  alias MollieEx.Types.{Link, Money}

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_refunds_secret"
  @refund_fixture Path.expand("../fixtures/mollie/refunds/create_success.json", __DIR__)
  @refund_list_fixture Path.expand("../fixtures/mollie/refunds/list_success.json", __DIR__)

  test "creates a refund with camelCased body and caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/payments/tr_123/refunds"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert header(conn, "idempotency-key") == "refund-123"

      assert_json_body(conn, %{
        "amount" => %{"currency" => "EUR", "value" => "10.00"},
        "description" => "Refund order #123",
        "externalReference" => %{"id" => "refund-ext-123", "type" => "acquirer-reference"},
        "metadata" => %{
          "order_id" => "123",
          "nested_meta" => %{"line_id" => "1"}
        },
        "reverseRouting" => true,
        "routingReversals" => [
          %{
            "amount" => %{"currency" => "EUR", "value" => "5.00"},
            "source" => %{"organizationId" => "org_123", "type" => "organization"}
          }
        ]
      })

      refund_fixture_response(conn, 201)
    end)

    params = %{
      amount: %{currency: "EUR", value: "10.00"},
      description: "Refund order #123",
      external_reference: %{type: "acquirer-reference", id: "refund-ext-123"},
      metadata: %{"order_id" => "123", "nested_meta" => %{"line_id" => "1"}},
      reverse_routing: true,
      routing_reversals: [
        %{
          amount: %{currency: "EUR", value: "5.00"},
          source: %{type: "organization", organization_id: "org_123"}
        }
      ]
    }

    assert {:ok, %Refund{} = refund} =
             Refunds.create(client(), "tr_123", params, idempotency_key: "refund-123")

    assert refund.id == "re_123"
    assert refund.status == "pending"

    assert refund.amount == %Money{
             currency: "EUR",
             value: "10.00",
             raw: %{"currency" => "EUR", "value" => "10.00"}
           }

    assert %Link{href: "https://api.mollie.com/v2/payments/tr_123"} =
             refund.links["payment"]

    assert refund.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "adds testmode for OAuth create requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "amount" => %{"currency" => "EUR", "value" => "10.00"},
        "description" => "Refund order #123",
        "testmode" => false
      })

      refund_fixture_response(conn, 201)
    end)

    client =
      Client.new!(
        oauth_token: "access_test_secret",
        testmode: true,
        transport: {:req_test, __MODULE__}
      )

    assert {:ok, %Refund{id: "re_123"}} =
             Refunds.create(
               client,
               "tr_123",
               %{amount: %{currency: "EUR", value: "10.00"}, description: "Refund order #123"},
               testmode: false
             )
  end

  test "retrieves a refund with embed and OAuth testmode query params" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/payments/tr_123/refunds/re_123"
      assert URI.decode_query(conn.query_string) == %{"embed" => "payment", "testmode" => "false"}
      assert_empty_body(conn)

      refund_fixture_response(conn, 200)
    end)

    client =
      Client.new!(
        oauth_token: "access_test_secret",
        testmode: true,
        transport: {:req_test, __MODULE__}
      )

    assert {:ok, %Refund{id: "re_123"}} =
             Refunds.get(client, "tr_123", "re_123", embed: "payment", testmode: false)
  end

  test "lists refunds with pagination and embed options" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/payments/tr_123/refunds"

      assert URI.decode_query(conn.query_string) == %{
               "embed" => "payment",
               "from" => "re_from",
               "limit" => "1"
             }

      assert_empty_body(conn)

      refund_list_fixture_response(conn, 200)
    end)

    assert {:ok, %MollieList{} = refund_list} =
             Refunds.list(client(), "tr_123", from: "re_from", limit: 1, embed: "payment")

    assert refund_list.count == 1
    assert [%Refund{id: "re_list_123", status: "queued"}] = refund_list.data

    assert %Link{href: "https://api.mollie.com/v2/payments/tr_123/refunds?from=re_next&limit=1"} =
             refund_list.links["next"]
  end

  test "cancels a refund with caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v2/payments/tr_123/refunds/re_123"
      assert conn.query_string == ""
      assert header(conn, "idempotency-key") == "cancel-refund-123"
      assert_empty_body(conn)

      no_content_response(conn)
    end)

    assert {:ok, :no_content} =
             Refunds.cancel(client(), "tr_123", "re_123", idempotency_key: "cancel-refund-123")
  end

  test "adds testmode query param for OAuth cancel requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert URI.decode_query(conn.query_string) == %{"testmode" => "false"}
      no_content_response(conn)
    end)

    client =
      Client.new!(
        oauth_token: "access_test_secret",
        testmode: true,
        transport: {:req_test, __MODULE__}
      )

    assert {:ok, :no_content} = Refunds.cancel(client, "tr_123", "re_123", testmode: false)
  end

  test "rejects testmode for API-key refund requests before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "re_123"})
    end)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Refunds.create(client(), "tr_123", %{description: "Refund", testmode: true})

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Refunds.get(client(), "tr_123", "re_123", testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Refunds.list(client(), "tr_123", testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Refunds.cancel(client(), "tr_123", "re_123", testmode: true)

    refute_receive :request_sent, 10
  end

  test "does not retry refund create without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    assert {:error, %Error{type: :server_error, status: 503}} =
             Refunds.create(client(max_retries: 1), "tr_123", %{description: "Refund"})
  end

  test "retries refund create with the same caller idempotency key and body" do
    expected_body = %{
      "amount" => %{"currency" => "EUR", "value" => "10.00"},
      "description" => "Refund order #123"
    }

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "refund-123"
      assert_json_body(conn, expected_body)

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "refund-123"
      assert_json_body(conn, expected_body)
      refund_fixture_response(conn, 201)
    end)

    assert {:ok, %Refund{id: "re_123"}} =
             Refunds.create(
               client(max_retries: 1),
               "tr_123",
               %{amount: %{currency: "EUR", value: "10.00"}, description: "Refund order #123"},
               idempotency_key: "refund-123"
             )
  end

  test "does not retry refund cancel without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    assert {:error, %Error{type: :server_error, status: 503}} =
             Refunds.cancel(client(max_retries: 1), "tr_123", "re_123")
  end

  test "retries refund cancel with the same caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "cancel-refund-123"
      assert_empty_body(conn)

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "cancel-refund-123"
      assert_empty_body(conn)
      no_content_response(conn)
    end)

    assert {:ok, :no_content} =
             Refunds.cancel(
               client(max_retries: 1),
               "tr_123",
               "re_123",
               idempotency_key: "cancel-refund-123"
             )
  end

  test "returns API errors for refund calls" do
    cases = [
      {:create, 409, :api_error},
      {:get, 404, :not_found},
      {:list, 400, :api_error},
      {:cancel, 429, :rate_limited}
    ]

    for {operation, status, type} <- cases do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(status)
        |> Req.Test.json(%{
          "status" => status,
          "title" => "Refund error",
          "_links" => %{"documentation" => %{"href" => "https://docs.mollie.com/"}}
        })
      end)

      assert {:error, %Error{} = error} = call_operation(operation, client(max_retries: 0))
      assert error.type == type
      assert error.status == status
      assert error.raw["title"] == "Refund error"
    end
  end

  test "returns timeout errors for refund calls" do
    for {operation, expected_operation} <- [
          {:create, :refunds_create},
          {:get, :refunds_get},
          {:list, :refunds_list},
          {:cancel, :refunds_cancel}
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

    assert {:error, %Error{} = error} = Refunds.get(client(), "tr_123", "re_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.operation == :refunds_get
  end

  test "returns decode errors for invalid refund response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"status" => "pending"})
    end)

    assert {:error, %Error{} = error} = Refunds.get(client(), "tr_123", "re_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_refund_response
    assert error.operation == :refunds_get
    assert error.raw == %{"status" => "pending"}
  end

  test "returns decode errors for invalid refund list response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"count" => 1, "_embedded" => %{"refunds" => %{}}, "_links" => %{}})
    end)

    assert {:error, %Error{} = error} = Refunds.list(client(), "tr_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_list_response
    assert error.operation == :refunds_list
  end

  test "returns decode errors for invalid embedded refund list items" do
    invalid_refund = %{"status" => "queued"}

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"refunds" => [invalid_refund]},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{} = error} = Refunds.list(client(), "tr_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_refund_response
    assert error.operation == :refunds_list
    assert error.raw == invalid_refund
  end

  test "returns decode errors for invalid cancel responses" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"id" => "re_123"})
    end)

    assert {:error, %Error{} = error} = Refunds.cancel(client(), "tr_123", "re_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_no_content_response
    assert error.operation == :refunds_cancel
  end

  test "rejects invalid local inputs before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "re_123"})
    end)

    assert {:error, %Error{reason: :invalid_refund_params}} =
             Refunds.create(client(), "tr_123", "bad")

    assert {:error, %Error{reason: :invalid_payment_id}} =
             Refunds.create(client(), "", %{description: "Refund"})

    assert {:error, %Error{reason: :invalid_refund_id}} =
             Refunds.get(client(), "tr_123", "")

    assert {:error, %Error{reason: :invalid_payment_id}} =
             Refunds.list(client(), "")

    assert {:error, %Error{reason: :invalid_refund_id}} =
             Refunds.cancel(client(), "tr_123", "")

    assert {:error, %Error{reason: :invalid_options}} =
             Refunds.create(client(), "tr_123", %{description: "Refund"}, "bad")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Refunds.get(client(), "tr_123", "re_123", unknown: true)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Refunds.list(client(), "tr_123", unknown: true)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Refunds.cancel(client(), "tr_123", "re_123", unknown: true)

    assert {:error, %Error{reason: {:invalid_option, :from}}} =
             Refunds.list(client(), "tr_123", from: "")

    assert {:error, %Error{reason: {:invalid_option, :limit}}} =
             Refunds.list(client(), "tr_123", limit: 251)

    assert {:error, %Error{reason: :invalid_testmode}} =
             Refunds.create(
               Client.new!(oauth_token: "access_test_secret", transport: {:req_test, __MODULE__}),
               "tr_123",
               %{description: "Refund"},
               testmode: "true"
             )

    assert {:error, %Error{reason: :invalid_testmode}} =
             Refunds.cancel(
               Client.new!(oauth_token: "access_test_secret", transport: {:req_test, __MODULE__}),
               "tr_123",
               "re_123",
               testmode: "true"
             )

    refute_receive :request_sent, 10
  end

  test "emits safe request telemetry for successful refund calls" do
    prefix = [:mollie_refunds_test_success]
    attach_telemetry(prefix, [[:request, :start], [:request, :stop]])

    Req.Test.expect(__MODULE__, fn conn ->
      refund_fixture_response(conn, 201)
    end)

    assert {:ok, %Refund{}} =
             Refunds.create(
               client(telemetry_prefix: prefix),
               "tr_123",
               %{description: "Refund order #123"},
               idempotency_key: "refund-123"
             )

    assert_success_telemetry(
      prefix,
      :refunds_create,
      "POST",
      "/payments/{paymentId}/refunds",
      201
    )

    Req.Test.expect(__MODULE__, fn conn ->
      refund_fixture_response(conn, 200)
    end)

    assert {:ok, %Refund{}} =
             Refunds.get(client(telemetry_prefix: prefix), "tr_123", "re_123")

    assert_success_telemetry(
      prefix,
      :refunds_get,
      "GET",
      "/payments/{paymentId}/refunds/{refundId}",
      200
    )

    Req.Test.expect(__MODULE__, fn conn ->
      refund_list_fixture_response(conn, 200)
    end)

    assert {:ok, %MollieList{}} =
             Refunds.list(client(telemetry_prefix: prefix), "tr_123")

    assert_success_telemetry(prefix, :refunds_list, "GET", "/payments/{paymentId}/refunds", 200)

    Req.Test.expect(__MODULE__, fn conn ->
      no_content_response(conn)
    end)

    assert {:ok, :no_content} =
             Refunds.cancel(
               client(telemetry_prefix: prefix),
               "tr_123",
               "re_123",
               idempotency_key: "cancel-refund-123"
             )

    assert_success_telemetry(
      prefix,
      :refunds_cancel,
      "DELETE",
      "/payments/{paymentId}/refunds/{refundId}",
      204
    )
  end

  test "emits safe decode exception and rate limit telemetry" do
    prefix = [:mollie_refunds_test_errors]

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
             Refunds.get(client(telemetry_prefix: prefix), "tr_123", "re_123")

    decode_event = prefix ++ [:decode, :exception]
    request_exception_event = prefix ++ [:request, :exception]

    assert_receive {:telemetry, ^decode_event, %{duration: _duration}, decode_metadata}
    assert decode_metadata.error_type == :decode
    assert decode_metadata.reason == :invalid_refund_response
    assert decode_metadata.path_template == "/payments/{paymentId}/refunds/{refundId}"

    assert_receive {:telemetry, ^request_exception_event, %{duration: _duration},
                    exception_metadata}

    assert exception_metadata.error_type == :decode

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(429)
      |> Req.Test.json(%{"status" => 429, "title" => "Too Many Requests"})
    end)

    assert {:error, %Error{type: :rate_limited}} =
             Refunds.get(client(telemetry_prefix: prefix, max_retries: 0), "tr_123", "re_123")

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
    Refunds.create(client, "tr_123", %{description: "Refund order #123"})
  end

  defp call_operation(:get, client), do: Refunds.get(client, "tr_123", "re_123")
  defp call_operation(:list, client), do: Refunds.list(client, "tr_123")
  defp call_operation(:cancel, client), do: Refunds.cancel(client, "tr_123", "re_123")

  defp client(opts \\ []) do
    [api_key: @api_key, transport: {:req_test, __MODULE__}]
    |> Keyword.merge(opts)
    |> Client.new!()
  end

  defp refund_fixture_response(conn, status) do
    conn
    |> Plug.Conn.put_resp_header("content-type", "application/hal+json")
    |> Plug.Conn.send_resp(status, File.read!(@refund_fixture))
  end

  defp refund_list_fixture_response(conn, status) do
    conn
    |> Plug.Conn.put_resp_header("content-type", "application/hal+json")
    |> Plug.Conn.send_resp(status, File.read!(@refund_list_fixture))
  end

  defp no_content_response(conn) do
    Plug.Conn.send_resp(conn, 204, "")
  end

  defp assert_json_body(conn, expected) do
    assert {:ok, decoded} =
             conn
             |> Req.Test.raw_body()
             |> IO.iodata_to_binary()
             |> Jason.decode()

    assert decoded == expected
  end

  defp assert_empty_body(conn) do
    assert conn |> Req.Test.raw_body() |> IO.iodata_to_binary() == ""
  end

  defp header(conn, name) do
    conn.req_headers
    |> List.keyfind(name, 0)
    |> case do
      {^name, value} -> value
      nil -> nil
    end
  end

  defp assert_success_telemetry(prefix, operation, method, path_template, status) do
    start_event = prefix ++ [:request, :start]
    stop_event = prefix ++ [:request, :stop]

    assert_receive {:telemetry, ^start_event, %{system_time: system_time}, start_metadata}
    assert is_integer(system_time)
    assert start_metadata.operation == operation
    assert start_metadata.method == method
    assert start_metadata.path_template == path_template

    assert_receive {:telemetry, ^stop_event, %{duration: duration}, stop_metadata}
    assert is_integer(duration)
    assert stop_metadata.status == status
    assert stop_metadata.operation == operation

    telemetry_text = inspect([start_metadata, stop_metadata])
    refute telemetry_text =~ @api_key
    refute telemetry_text =~ "refund-123"
    refute telemetry_text =~ "cancel-refund-123"
    refute telemetry_text =~ "Refund order #123"
    refute telemetry_text =~ "authorization"
  end

  defp attach_telemetry(prefix, suffixes) do
    handler_id = {__MODULE__, self(), make_ref()}
    events = Enum.map(suffixes, &(prefix ++ &1))

    :telemetry.attach_many(
      handler_id,
      events,
      &__MODULE__.handle_telemetry/4,
      self()
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  def handle_telemetry(event, measurements, metadata, test_pid) do
    send(test_pid, {:telemetry, event, measurements, metadata})
  end
end
