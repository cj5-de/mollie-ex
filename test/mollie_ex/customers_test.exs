defmodule MollieEx.CustomersTest do
  use ExUnit.Case, async: false

  alias MollieEx.Client
  alias MollieEx.Customer
  alias MollieEx.Customers
  alias MollieEx.Error
  alias MollieEx.Types.Link

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_customers_secret"
  @customer_fixture Path.expand("../fixtures/mollie/customers/get_success.json", __DIR__)

  test "creates a customer with pass-through metadata and caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/customers"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert header(conn, "idempotency-key") == "customer-123"

      assert_json_body(conn, %{
        "name" => "Jane Doe",
        "email" => "jane@example.org",
        "locale" => "en_US",
        "metadata" => %{
          "crm_id" => "customer-123",
          "nested_value" => %{"kept_value" => true}
        }
      })

      customer_fixture_response(conn, 201)
    end)

    assert {:ok, %Customer{} = customer} =
             Customers.create(client(), create_params(), idempotency_key: "customer-123")

    assert customer.id == "cst_123"
    assert customer.name == "Jane Doe"
    assert customer.metadata["crm_id"] == "customer-123"

    assert %Link{href: "https://api.mollie.com/v2/customers/cst_123"} =
             customer.links["self"]

    assert customer.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "adds testmode for OAuth create requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "name" => "Jane Doe",
        "email" => "jane@example.org",
        "locale" => "en_US",
        "metadata" => %{
          "crm_id" => "customer-123",
          "nested_value" => %{"kept_value" => true}
        },
        "testmode" => false
      })

      customer_fixture_response(conn, 201)
    end)

    client =
      Client.new!(
        oauth_token: "access_test_secret",
        testmode: true,
        transport: {:req_test, __MODULE__}
      )

    assert {:ok, %Customer{id: "cst_123"}} =
             Customers.create(client, create_params(), testmode: false)
  end

  test "honors params-level testmode for OAuth create requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "name" => "Jane Doe",
        "email" => "jane@example.org",
        "locale" => "en_US",
        "metadata" => %{
          "crm_id" => "customer-123",
          "nested_value" => %{"kept_value" => true}
        },
        "testmode" => false
      })

      customer_fixture_response(conn, 201)
    end)

    client =
      Client.new!(
        oauth_token: "access_test_secret",
        testmode: true,
        transport: {:req_test, __MODULE__}
      )

    assert {:ok, %Customer{id: "cst_123"}} =
             Customers.create(client, Map.put(create_params(), :testmode, false))
  end

  test "retrieves a customer with include and OAuth testmode query params" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/customers/cst_123"

      assert URI.decode_query(conn.query_string) == %{
               "include" => "events",
               "testmode" => "false"
             }

      assert_empty_body(conn)

      customer_fixture_response(conn, 200)
    end)

    client =
      Client.new!(
        oauth_token: "access_test_secret",
        testmode: true,
        transport: {:req_test, __MODULE__}
      )

    assert {:ok, %Customer{id: "cst_123"}} =
             Customers.get(client, "cst_123", include: "events", testmode: false)
  end

  test "rejects API-key testmode before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "cst_123"})
    end)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Customers.create(client(), create_params(), testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Customers.create(client(), Map.put(create_params(), :testmode, true))

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Customers.get(client(), "cst_123", testmode: true)

    refute_receive :request_sent, 10
  end

  test "does not retry customer create without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    assert {:error, %Error{type: :server_error, status: 503}} =
             Customers.create(client(max_retries: 1), create_params())
  end

  test "retries customer create with the same caller idempotency key and body" do
    expected_body = %{
      "name" => "Jane Doe",
      "email" => "jane@example.org",
      "locale" => "en_US",
      "metadata" => %{
        "crm_id" => "customer-123",
        "nested_value" => %{"kept_value" => true}
      }
    }

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "customer-123"
      assert_json_body(conn, expected_body)

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "customer-123"
      assert_json_body(conn, expected_body)
      customer_fixture_response(conn, 201)
    end)

    assert {:ok, %Customer{id: "cst_123"}} =
             Customers.create(
               client(max_retries: 1),
               create_params(),
               idempotency_key: "customer-123"
             )
  end

  test "retries safe customer get without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil
      customer_fixture_response(conn, 200)
    end)

    assert {:ok, %Customer{id: "cst_123"}} = Customers.get(client(max_retries: 1), "cst_123")
  end

  test "returns API errors for customer calls" do
    cases = [
      {:create, 422, :validation},
      {:get, 404, :not_found},
      {:get, 429, :rate_limited}
    ]

    for {operation, status, type} <- cases do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(status)
        |> Req.Test.json(%{
          "status" => status,
          "title" => "Customer error",
          "_links" => %{"documentation" => %{"href" => "https://docs.mollie.com/"}}
        })
      end)

      assert {:error, %Error{} = error} = call_operation(operation, client(max_retries: 0))
      assert error.type == type
      assert error.status == status
      assert error.raw["title"] == "Customer error"
    end
  end

  test "returns timeout errors for customer calls" do
    for {operation, expected_operation} <- [
          {:create, :customers_create},
          {:get, :customers_get}
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

    assert {:error, %Error{} = error} = Customers.get(client(), "cst_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.operation == :customers_get
  end

  test "returns decode errors for invalid customer response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "customer"})
    end)

    assert {:error, %Error{} = error} = Customers.get(client(), "cst_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_customer_response
    assert error.operation == :customers_get
    assert error.raw == %{"resource" => "customer"}
  end

  test "rejects invalid local inputs before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "cst_123"})
    end)

    assert {:error, %Error{reason: :invalid_client}} =
             Customers.create("bad", create_params())

    assert {:error, %Error{reason: :invalid_customer_params}} =
             Customers.create(client(), "bad")

    assert {:error, %Error{reason: :invalid_customer_id}} =
             Customers.get(client(), "")

    assert {:error, %Error{reason: :invalid_options}} =
             Customers.get(client(), "cst_123", "bad")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Customers.get(client(), "cst_123", unknown: true)

    assert {:error, %Error{reason: {:invalid_option, :include}}} =
             Customers.get(client(), "cst_123", include: "")

    assert {:error, %Error{reason: :invalid_testmode}} =
             Customers.create(
               Client.new!(oauth_token: "access_test_secret", transport: {:req_test, __MODULE__}),
               create_params(),
               testmode: "true"
             )

    assert {:error, %Error{reason: :invalid_testmode}} =
             Customers.get(
               Client.new!(oauth_token: "access_test_secret", transport: {:req_test, __MODULE__}),
               "cst_123",
               testmode: "true"
             )

    refute_receive :request_sent, 10
  end

  test "emits safe request telemetry for successful customer calls" do
    prefix = [:mollie_customers_test_success]
    attach_telemetry(prefix, [[:request, :start], [:request, :stop]])

    Req.Test.expect(__MODULE__, fn conn ->
      customer_fixture_response(conn, 201)
    end)

    assert {:ok, %Customer{}} =
             Customers.create(
               client(telemetry_prefix: prefix),
               create_params(),
               idempotency_key: "customer-123"
             )

    assert_success_telemetry(prefix, :customers_create, "POST", "/customers", 201)

    Req.Test.expect(__MODULE__, fn conn ->
      customer_fixture_response(conn, 200)
    end)

    assert {:ok, %Customer{}} = Customers.get(client(telemetry_prefix: prefix), "cst_123")

    assert_success_telemetry(prefix, :customers_get, "GET", "/customers/{customerId}", 200)
  end

  test "emits safe decode exception and rate limit telemetry" do
    prefix = [:mollie_customers_test_errors]

    attach_telemetry(prefix, [
      [:request, :start],
      [:request, :stop],
      [:request, :exception],
      [:decode, :exception],
      [:rate_limit]
    ])

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "customer"})
    end)

    assert {:error, %Error{type: :decode}} =
             Customers.get(client(telemetry_prefix: prefix), "cst_123")

    decode_event = prefix ++ [:decode, :exception]
    request_exception_event = prefix ++ [:request, :exception]

    assert_receive {:telemetry, ^decode_event, %{duration: _duration}, decode_metadata}
    assert decode_metadata.error_type == :decode
    assert decode_metadata.reason == :invalid_customer_response
    assert decode_metadata.path_template == "/customers/{customerId}"

    assert_receive {:telemetry, ^request_exception_event, %{duration: _duration},
                    exception_metadata}

    assert exception_metadata.error_type == :decode

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(429)
      |> Req.Test.json(%{"status" => 429, "title" => "Too Many Requests"})
    end)

    assert {:error, %Error{type: :rate_limited}} =
             Customers.get(client(telemetry_prefix: prefix, max_retries: 0), "cst_123")

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

  defp call_operation(:create, client), do: Customers.create(client, create_params())
  defp call_operation(:get, client), do: Customers.get(client, "cst_123")

  defp client(opts \\ []) do
    [api_key: @api_key, transport: {:req_test, __MODULE__}]
    |> Keyword.merge(opts)
    |> Client.new!()
  end

  defp create_params do
    %{
      name: "Jane Doe",
      email: "jane@example.org",
      locale: "en_US",
      metadata: %{
        "crm_id" => "customer-123",
        "nested_value" => %{"kept_value" => true}
      }
    }
  end

  defp customer_fixture_response(conn, status) do
    conn
    |> Plug.Conn.put_resp_header("content-type", "application/hal+json")
    |> Plug.Conn.send_resp(status, File.read!(@customer_fixture))
  end

  defp assert_json_body(conn, expected) do
    assert conn |> Req.Test.raw_body() |> Jason.decode!() == expected
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
    refute telemetry_text =~ "cst_123"
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
