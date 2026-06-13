defmodule MollieEx.PaymentRoutesTest do
  use ExUnit.Case, async: false

  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.PaymentRoutes
  alias MollieEx.Route
  alias MollieEx.TestSupport
  alias MollieEx.Types.{Link, Money}

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_payment_routes_secret"
  @route_fixture Path.expand("../fixtures/mollie/payment_routes/get_success.json", __DIR__)
  @route_list_fixture Path.expand("../fixtures/mollie/payment_routes/list_success.json", __DIR__)

  test "creates a payment route with camelCased body and caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/payments/tr_123/routes"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert header(conn, "idempotency-key") == "route-123"

      assert_json_body(conn, %{
        "amount" => %{"currency" => "EUR", "value" => "10.00"},
        "destination" => %{"type" => "organization", "organizationId" => "org_123"},
        "description" => "Payment for order #123"
      })

      route_fixture_response(conn, 201)
    end)

    params = %{
      amount: %{currency: "EUR", value: "10.00"},
      destination: %{type: "organization", organization_id: "org_123"},
      description: "Payment for order #123"
    }

    assert {:ok, %Route{} = route} =
             PaymentRoutes.create(client(), "tr_123", params, idempotency_key: "route-123")

    assert route.id == "crt_123"
    assert route.payment_id == "tr_123"
    assert route.destination == %{"type" => "organization", "organizationId" => "org_123"}

    assert route.amount == %Money{
             currency: "EUR",
             value: "10.00",
             raw: %{"currency" => "EUR", "value" => "10.00"}
           }

    assert %Link{href: "https://api.mollie.com/v2/payments/tr_123"} =
             route.links["payment"]

    assert route.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "adds testmode for OAuth create requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "amount" => %{"currency" => "EUR", "value" => "10.00"},
        "destination" => %{"type" => "organization", "organizationId" => "org_123"},
        "description" => "Payment for order #123",
        "testmode" => false
      })

      route_fixture_response(conn, 201)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %Route{id: "crt_123"}} =
             PaymentRoutes.create(
               client,
               "tr_123",
               Map.put(valid_params(), :description, "Payment for order #123"),
               testmode: false
             )
  end

  test "honors params-level testmode for OAuth create requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "amount" => %{"currency" => "EUR", "value" => "10.00"},
        "destination" => %{"type" => "organization", "organizationId" => "org_123"},
        "testmode" => false
      })

      route_fixture_response(conn, 201)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %Route{id: "crt_123"}} =
             PaymentRoutes.create(client, "tr_123", Map.put(valid_params(), :testmode, false))
  end

  test "retrieves a payment route" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/payments/tr_123/routes/crt_123"
      assert conn.query_string == ""
      assert_empty_body(conn)

      route_fixture_response(conn, 200)
    end)

    assert {:ok, %Route{id: "crt_123", payment_id: "tr_123"}} =
             PaymentRoutes.get(client(), "tr_123", "crt_123")
  end

  test "lists payment routes" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/payments/tr_123/routes"
      assert conn.query_string == ""
      assert_empty_body(conn)

      route_list_fixture_response(conn, 200)
    end)

    assert {:ok, %MollieList{} = route_list} = PaymentRoutes.list(client(), "tr_123")
    assert route_list.count == 1
    assert [%Route{id: "crt_list_123", payment_id: "tr_123"}] = route_list.data

    assert %Link{href: "https://api.mollie.com/v2/payments/tr_123/routes"} =
             route_list.links["self"]
  end

  test "adds testmode query param for OAuth list requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert URI.decode_query(conn.query_string) == %{"testmode" => "false"}
      route_list_fixture_response(conn, 200)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %MollieList{}} = PaymentRoutes.list(client, "tr_123", testmode: false)
  end

  test "rejects unsupported route options before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "crt_123"})
    end)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             PaymentRoutes.list(client(), "tr_123", testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             PaymentRoutes.create(client(), "tr_123", valid_params(), testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             PaymentRoutes.create(client(), "tr_123", Map.put(valid_params(), :testmode, true))

    assert {:error, %Error{reason: {:unsupported_option, :testmode}}} =
             PaymentRoutes.get(client(), "tr_123", "crt_123", testmode: true)

    refute_receive :request_sent, 10
  end

  test "does not retry route create without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    assert {:error, %Error{type: :server_error, status: 503}} =
             PaymentRoutes.create(client(max_retries: 1), "tr_123", valid_params())
  end

  test "retries route create with the same caller idempotency key and body" do
    expected_body = %{
      "amount" => %{"currency" => "EUR", "value" => "10.00"},
      "destination" => %{"type" => "organization", "organizationId" => "org_123"}
    }

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "route-123"
      assert_json_body(conn, expected_body)

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "route-123"
      assert_json_body(conn, expected_body)
      route_fixture_response(conn, 201)
    end)

    assert {:ok, %Route{id: "crt_123"}} =
             PaymentRoutes.create(
               client(max_retries: 1),
               "tr_123",
               valid_params(),
               idempotency_key: "route-123"
             )
  end

  test "retries safe route get and list requests without idempotency key" do
    for operation <- [:get, :list] do
      Req.Test.expect(__MODULE__, fn conn ->
        assert header(conn, "idempotency-key") == nil

        conn
        |> Plug.Conn.put_status(503)
        |> Req.Test.json(%{"status" => 503})
      end)

      Req.Test.expect(__MODULE__, fn conn ->
        assert header(conn, "idempotency-key") == nil
        route_response(operation, conn)
      end)

      assert {:ok, _result} = call_operation(operation, client(max_retries: 1))
    end
  end

  test "returns API errors for route calls" do
    cases = [
      {:create, 422, :validation},
      {:get, 404, :not_found},
      {:list, 429, :rate_limited}
    ]

    for {operation, status, type} <- cases do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(status)
        |> Req.Test.json(%{
          "status" => status,
          "title" => "Route error",
          "_links" => %{"documentation" => %{"href" => "https://docs.mollie.com/"}}
        })
      end)

      assert {:error, %Error{} = error} = call_operation(operation, client(max_retries: 0))
      assert error.type == type
      assert error.status == status
      assert error.raw["title"] == "Route error"
    end
  end

  test "returns timeout errors for route calls" do
    for {operation, expected_operation} <- [
          {:create, :payment_routes_create},
          {:get, :payment_routes_get},
          {:list, :payment_routes_list}
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

    assert {:error, %Error{} = error} = PaymentRoutes.get(client(), "tr_123", "crt_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.operation == :payment_routes_get
  end

  test "returns decode errors for invalid route response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "route"})
    end)

    assert {:error, %Error{} = error} = PaymentRoutes.get(client(), "tr_123", "crt_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_route_response
    assert error.operation == :payment_routes_get
    assert error.raw == %{"resource" => "route"}
  end

  test "returns decode errors for invalid route list response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"count" => 1, "_embedded" => %{"routes" => %{}}, "_links" => %{}})
    end)

    assert {:error, %Error{} = error} = PaymentRoutes.list(client(), "tr_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_list_response
    assert error.operation == :payment_routes_list
  end

  test "returns decode errors for invalid embedded route list items" do
    invalid_route = %{"resource" => "route"}

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"routes" => [invalid_route]},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{} = error} = PaymentRoutes.list(client(), "tr_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_route_response
    assert error.operation == :payment_routes_list
    assert error.raw == invalid_route
  end

  test "rejects invalid local inputs before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "crt_123"})
    end)

    assert {:error, %Error{reason: :invalid_client}} =
             PaymentRoutes.create("bad", "tr_123", valid_params())

    assert {:error, %Error{reason: :invalid_payment_id}} =
             PaymentRoutes.create(client(), "", valid_params())

    assert {:error, %Error{reason: :invalid_route_params}} =
             PaymentRoutes.create(client(), "tr_123", "bad")

    assert {:error, %Error{reason: :missing_amount}} =
             PaymentRoutes.create(client(), "tr_123", %{destination: %{type: "organization"}})

    assert {:error, %Error{reason: :missing_destination}} =
             PaymentRoutes.create(client(), "tr_123", %{amount: %{value: "10.00"}})

    assert {:error, %Error{reason: :invalid_route_id}} =
             PaymentRoutes.get(client(), "tr_123", "")

    assert {:error, %Error{reason: :invalid_options}} =
             PaymentRoutes.list(client(), "tr_123", "bad")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             PaymentRoutes.list(client(), "tr_123", unknown: true)

    assert {:error, %Error{reason: :invalid_testmode}} =
             PaymentRoutes.list(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               "tr_123",
               testmode: "true"
             )

    refute_receive :request_sent, 10
  end

  test "emits safe request telemetry for successful route calls" do
    prefix = [:mollie_payment_routes_test_success]
    attach_telemetry(prefix, [[:request, :start], [:request, :stop]])

    Req.Test.expect(__MODULE__, fn conn ->
      route_fixture_response(conn, 201)
    end)

    assert {:ok, %Route{}} =
             PaymentRoutes.create(
               client(telemetry_prefix: prefix),
               "tr_123",
               valid_params(),
               idempotency_key: "route-123"
             )

    assert_success_telemetry(
      prefix,
      :payment_routes_create,
      "POST",
      "/payments/{paymentId}/routes",
      201,
      [@api_key, "crt_123", "authorization"]
    )

    Req.Test.expect(__MODULE__, fn conn ->
      route_fixture_response(conn, 200)
    end)

    assert {:ok, %Route{}} =
             PaymentRoutes.get(client(telemetry_prefix: prefix), "tr_123", "crt_123")

    assert_success_telemetry(
      prefix,
      :payment_routes_get,
      "GET",
      "/payments/{paymentId}/routes/{routeId}",
      200,
      [@api_key, "crt_123", "authorization"]
    )

    Req.Test.expect(__MODULE__, fn conn ->
      route_list_fixture_response(conn, 200)
    end)

    assert {:ok, %MollieList{}} =
             PaymentRoutes.list(client(telemetry_prefix: prefix), "tr_123")

    assert_success_telemetry(
      prefix,
      :payment_routes_list,
      "GET",
      "/payments/{paymentId}/routes",
      200,
      [@api_key, "crt_123", "authorization"]
    )
  end

  test "emits safe decode exception and rate limit telemetry" do
    prefix = [:mollie_payment_routes_test_errors]

    attach_telemetry(prefix, [
      [:request, :start],
      [:request, :stop],
      [:request, :exception],
      [:decode, :exception],
      [:rate_limit]
    ])

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "route"})
    end)

    assert {:error, %Error{type: :decode}} =
             PaymentRoutes.get(client(telemetry_prefix: prefix), "tr_123", "crt_123")

    decode_event = prefix ++ [:decode, :exception]
    request_exception_event = prefix ++ [:request, :exception]

    assert_receive {:telemetry, ^decode_event, %{duration: _duration}, decode_metadata}
    assert decode_metadata.error_type == :decode
    assert decode_metadata.reason == :invalid_route_response
    assert decode_metadata.path_template == "/payments/{paymentId}/routes/{routeId}"

    assert_receive {:telemetry, ^request_exception_event, %{duration: _duration},
                    exception_metadata}

    assert exception_metadata.error_type == :decode

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(429)
      |> Req.Test.json(%{"status" => 429, "title" => "Too Many Requests"})
    end)

    assert {:error, %Error{type: :rate_limited}} =
             PaymentRoutes.get(
               client(telemetry_prefix: prefix, max_retries: 0),
               "tr_123",
               "crt_123"
             )

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

  defp call_operation(:create, client), do: PaymentRoutes.create(client, "tr_123", valid_params())
  defp call_operation(:get, client), do: PaymentRoutes.get(client, "tr_123", "crt_123")
  defp call_operation(:list, client), do: PaymentRoutes.list(client, "tr_123")

  defp client(opts \\ []) do
    [api_key: @api_key]
    |> Keyword.merge(opts)
    |> then(&TestSupport.client(__MODULE__, &1))
  end

  defp valid_params do
    %{
      amount: %{currency: "EUR", value: "10.00"},
      destination: %{type: "organization", organization_id: "org_123"}
    }
  end

  defp route_response(:list, conn), do: route_list_fixture_response(conn, 200)
  defp route_response(_operation, conn), do: route_fixture_response(conn, 200)

  defp route_fixture_response(conn, status), do: fixture_response(conn, @route_fixture, status)

  defp route_list_fixture_response(conn, status) do
    fixture_response(conn, @route_list_fixture, status)
  end
end
