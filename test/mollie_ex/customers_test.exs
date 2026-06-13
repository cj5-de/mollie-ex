defmodule MollieEx.CustomersTest do
  use ExUnit.Case, async: false

  alias MollieEx.Customer
  alias MollieEx.Customers
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Payment
  alias MollieEx.TestSupport
  alias MollieEx.Types.Link

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_customers_secret"
  @customer_fixture Path.expand("../fixtures/mollie/customers/get_success.json", __DIR__)
  @customer_list_fixture Path.expand("../fixtures/mollie/customers/list_success.json", __DIR__)
  @payment_list_fixture Path.expand("../fixtures/mollie/payments/list_success.json", __DIR__)

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

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

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

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

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

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %Customer{id: "cst_123"}} =
             Customers.get(client, "cst_123", include: "events", testmode: false)
  end

  test "lists customers with pagination and OAuth testmode query params" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/customers"

      assert URI.decode_query(conn.query_string) == %{
               "from" => "cst_from",
               "limit" => "1",
               "sort" => "asc",
               "testmode" => "false"
             }

      assert_empty_body(conn)

      customer_list_fixture_response(conn, 200)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %MollieList{} = customer_list} =
             Customers.list(client, from: "cst_from", limit: 1, sort: :asc, testmode: false)

    assert customer_list.count == 1
    assert [%Customer{id: "cst_list_123", name: "Jane List"}] = customer_list.data

    assert %Link{href: "https://api.mollie.com/v2/customers?from=cst_next&limit=1"} =
             customer_list.links["next"]
  end

  test "lists payments for a customer with pagination, profile, sort, and OAuth testmode" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/customers/cst_123/payments"

      assert URI.decode_query(conn.query_string) == %{
               "from" => "tr_from",
               "limit" => "1",
               "profileId" => "pfl_override",
               "sort" => "desc",
               "testmode" => "false"
             }

      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      payment_list_fixture_response(conn, 200)
    end)

    client =
      TestSupport.client(__MODULE__,
        oauth_token: "access_test_secret",
        profile_id: "pfl_default",
        testmode: true
      )

    assert {:ok, %MollieList{} = payment_list} =
             Customers.list_payments(client, "cst_123",
               from: "tr_from",
               limit: 1,
               profile_id: "pfl_override",
               sort: :desc,
               testmode: false
             )

    assert payment_list.count == 1
    assert [%Payment{id: "tr_list_123", description: "Order #12345"}] = payment_list.data

    assert %Link{href: "https://api.mollie.com/v2/payments?from=tr_next&limit=1"} =
             payment_list.links["next"]
  end

  test "updates a customer with pass-through metadata and caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v2/customers/cst_123"
      assert conn.query_string == ""
      assert header(conn, "idempotency-key") == "customer-update-123"

      assert_json_body(conn, %{
        "name" => "Jane Updated",
        "metadata" => %{
          "crm_id" => "customer-456",
          "nested_value" => %{"kept_value" => true}
        }
      })

      customer_fixture_response(conn, 200)
    end)

    params = %{
      name: "Jane Updated",
      metadata: %{
        "crm_id" => "customer-456",
        "nested_value" => %{"kept_value" => true}
      }
    }

    assert {:ok, %Customer{id: "cst_123"}} =
             Customers.update(client(), "cst_123", params, idempotency_key: "customer-update-123")
  end

  test "adds testmode for OAuth update requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "name" => "Jane Updated",
        "testmode" => false
      })

      customer_fixture_response(conn, 200)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %Customer{id: "cst_123"}} =
             Customers.update(client, "cst_123", %{name: "Jane Updated"}, testmode: false)
  end

  test "deletes a customer and returns no content" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v2/customers/cst_123"
      assert conn.query_string == ""
      assert header(conn, "idempotency-key") == "customer-delete-123"
      assert_empty_body(conn)

      no_content_response(conn)
    end)

    assert {:ok, :no_content} =
             Customers.delete(client(), "cst_123", idempotency_key: "customer-delete-123")
  end

  test "sends testmode in the body for OAuth delete requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v2/customers/cst_123"
      assert conn.query_string == ""
      assert_json_body(conn, %{"testmode" => false})

      no_content_response(conn)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, :no_content} = Customers.delete(client, "cst_123", testmode: false)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v2/customers/cst_123"
      assert conn.query_string == ""
      assert_json_body(conn, %{"testmode" => true})

      no_content_response(conn)
    end)

    assert {:ok, :no_content} = Customers.delete(client, "cst_123")
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

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Customers.list(client(), testmode: true)

    assert {:error, %Error{reason: :unsupported_profile_id}} =
             Customers.list_payments(client(), "cst_123", profile_id: "pfl_123")

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Customers.list_payments(client(), "cst_123", testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Customers.update(client(), "cst_123", %{name: "Jane"}, testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Customers.update(client(), "cst_123", %{name: "Jane", testmode: true})

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Customers.delete(client(), "cst_123", testmode: true)

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

  test "retries customer update and delete with caller idempotency keys" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "customer-update-123"
      assert_json_body(conn, %{"name" => "Jane Updated"})

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "customer-update-123"
      assert_json_body(conn, %{"name" => "Jane Updated"})
      customer_fixture_response(conn, 200)
    end)

    assert {:ok, %Customer{id: "cst_123"}} =
             Customers.update(
               client(max_retries: 1),
               "cst_123",
               %{name: "Jane Updated"},
               idempotency_key: "customer-update-123"
             )

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "customer-delete-123"

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "customer-delete-123"
      no_content_response(conn)
    end)

    assert {:ok, :no_content} =
             Customers.delete(
               client(max_retries: 1),
               "cst_123",
               idempotency_key: "customer-delete-123"
             )
  end

  test "retries safe customer get and payment list requests without idempotency key" do
    for operation <- [:get, :list_payments] do
      Req.Test.expect(__MODULE__, fn conn ->
        assert header(conn, "idempotency-key") == nil

        conn
        |> Plug.Conn.put_status(503)
        |> Req.Test.json(%{"status" => 503})
      end)

      Req.Test.expect(__MODULE__, fn conn ->
        assert header(conn, "idempotency-key") == nil
        customer_response(operation, conn)
      end)

      assert {:ok, _result} = call_operation(operation, client(max_retries: 1))
    end
  end

  test "does not retry customer update and delete without idempotency keys" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    assert {:error, %Error{type: :server_error, status: 503}} =
             Customers.update(client(max_retries: 1), "cst_123", %{name: "Jane Updated"})

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    assert {:error, %Error{type: :server_error, status: 503}} =
             Customers.delete(client(max_retries: 1), "cst_123")
  end

  test "returns API errors for customer calls" do
    cases = [
      {:create, 422, :validation},
      {:get, 404, :not_found},
      {:list, 400, :api_error},
      {:list_payments, 400, :api_error},
      {:update, 422, :validation},
      {:delete, 404, :not_found},
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
          {:get, :customers_get},
          {:list, :customers_list},
          {:list_payments, :customers_list_payments},
          {:update, :customers_update},
          {:delete, :customers_delete}
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

  test "returns decode errors for invalid customer list response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"count" => 1, "_embedded" => %{"customers" => %{}}})
    end)

    assert {:error, %Error{} = error} = Customers.list(client())
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_list_response
    assert error.operation == :customers_list
  end

  test "returns decode errors for invalid customer payments list response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"count" => 1, "_embedded" => %{"payments" => %{}}})
    end)

    assert {:error, %Error{} = error} = Customers.list_payments(client(), "cst_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_list_response
    assert error.operation == :customers_list_payments
  end

  test "returns decode errors for invalid customer delete responses" do
    Req.Test.expect(__MODULE__, fn conn ->
      customer_fixture_response(conn, 200)
    end)

    assert {:error, %Error{} = error} = Customers.delete(client(), "cst_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_no_content_response
    assert error.operation == :customers_delete
  end

  test "rejects invalid local inputs before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "cst_123"})
    end)

    assert {:error, %Error{reason: :invalid_client}} =
             Customers.create("bad", create_params())

    assert {:error, %Error{reason: :invalid_client}} =
             Customers.list_payments("bad", "cst_123")

    assert {:error, %Error{reason: :invalid_customer_params}} =
             Customers.create(client(), "bad")

    assert {:error, %Error{reason: :invalid_customer_id}} =
             Customers.get(client(), "")

    assert {:error, %Error{reason: :invalid_customer_id}} =
             Customers.update(client(), "", %{name: "Jane"})

    assert {:error, %Error{reason: :invalid_customer_id}} =
             Customers.delete(client(), "")

    assert {:error, %Error{reason: :invalid_customer_id}} =
             Customers.list_payments(client(), "")

    assert {:error, %Error{reason: :invalid_customer_params}} =
             Customers.update(client(), "cst_123", "bad")

    assert {:error, %Error{reason: :invalid_options}} =
             Customers.get(client(), "cst_123", "bad")

    assert {:error, %Error{reason: :invalid_options}} =
             Customers.list(client(), "bad")

    assert {:error, %Error{reason: :invalid_options}} =
             Customers.update(client(), "cst_123", %{name: "Jane"}, "bad")

    assert {:error, %Error{reason: :invalid_options}} =
             Customers.delete(client(), "cst_123", "bad")

    assert {:error, %Error{reason: :invalid_options}} =
             Customers.list_payments(client(), "cst_123", "bad")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Customers.get(client(), "cst_123", unknown: true)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Customers.list(client(), unknown: true)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Customers.list_payments(client(), "cst_123", unknown: true)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Customers.update(client(), "cst_123", %{name: "Jane"}, unknown: true)

    assert {:error, %Error{reason: {:invalid_option, :include}}} =
             Customers.get(client(), "cst_123", include: "")

    assert {:error, %Error{reason: {:invalid_option, :from}}} =
             Customers.list(client(), from: "")

    assert {:error, %Error{reason: {:invalid_option, :limit}}} =
             Customers.list(client(), limit: 251)

    assert {:error, %Error{reason: {:invalid_option, :sort}}} =
             Customers.list(client(), sort: :newest)

    assert {:error, %Error{reason: {:invalid_option, :from}}} =
             Customers.list_payments(client(), "cst_123", from: "")

    assert {:error, %Error{reason: {:invalid_option, :limit}}} =
             Customers.list_payments(client(), "cst_123", limit: 251)

    assert {:error, %Error{reason: {:invalid_option, :sort}}} =
             Customers.list_payments(client(), "cst_123", sort: :newest)

    assert {:error, %Error{reason: :invalid_testmode}} =
             Customers.create(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               create_params(),
               testmode: "true"
             )

    assert {:error, %Error{reason: :invalid_testmode}} =
             Customers.get(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               "cst_123",
               testmode: "true"
             )

    assert {:error, %Error{reason: :invalid_testmode}} =
             Customers.list(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               testmode: "true"
             )

    assert {:error, %Error{reason: :missing_profile_id}} =
             Customers.list_payments(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               "cst_123"
             )

    assert {:error, %Error{reason: :invalid_profile_id}} =
             Customers.list_payments(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               "cst_123",
               profile_id: ""
             )

    assert {:error, %Error{reason: :invalid_testmode}} =
             Customers.list_payments(
               TestSupport.client(__MODULE__,
                 oauth_token: "access_test_secret",
                 profile_id: "pfl_123"
               ),
               "cst_123",
               testmode: "true"
             )

    assert {:error, %Error{reason: :invalid_testmode}} =
             Customers.update(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               "cst_123",
               %{name: "Jane"},
               testmode: "true"
             )

    assert {:error, %Error{reason: :invalid_testmode}} =
             Customers.delete(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
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

    assert_success_telemetry(
      prefix,
      :customers_create,
      "POST",
      "/customers",
      201,
      [@api_key, "cst_123", "authorization"]
    )

    Req.Test.expect(__MODULE__, fn conn ->
      customer_fixture_response(conn, 200)
    end)

    assert {:ok, %Customer{}} = Customers.get(client(telemetry_prefix: prefix), "cst_123")

    assert_success_telemetry(
      prefix,
      :customers_get,
      "GET",
      "/customers/{customerId}",
      200,
      [@api_key, "cst_123", "authorization"]
    )

    Req.Test.expect(__MODULE__, fn conn ->
      customer_list_fixture_response(conn, 200)
    end)

    assert {:ok, %MollieList{}} = Customers.list(client(telemetry_prefix: prefix))

    assert_success_telemetry(
      prefix,
      :customers_list,
      "GET",
      "/customers",
      200,
      [@api_key, "cst_123", "authorization"]
    )

    Req.Test.expect(__MODULE__, fn conn ->
      payment_list_fixture_response(conn, 200)
    end)

    assert {:ok, %MollieList{}} =
             Customers.list_payments(client(telemetry_prefix: prefix), "cst_123")

    assert_success_telemetry(
      prefix,
      :customers_list_payments,
      "GET",
      "/customers/{customerId}/payments",
      200,
      [@api_key, "cst_123", "authorization"]
    )

    Req.Test.expect(__MODULE__, fn conn ->
      customer_fixture_response(conn, 200)
    end)

    assert {:ok, %Customer{}} =
             Customers.update(
               client(telemetry_prefix: prefix),
               "cst_123",
               %{name: "Jane Updated"},
               idempotency_key: "customer-update-123"
             )

    assert_success_telemetry(
      prefix,
      :customers_update,
      "PATCH",
      "/customers/{customerId}",
      200,
      [@api_key, "cst_123", "authorization"]
    )

    Req.Test.expect(__MODULE__, fn conn ->
      no_content_response(conn)
    end)

    assert {:ok, :no_content} =
             Customers.delete(
               client(telemetry_prefix: prefix),
               "cst_123",
               idempotency_key: "customer-delete-123"
             )

    assert_success_telemetry(
      prefix,
      :customers_delete,
      "DELETE",
      "/customers/{customerId}",
      204,
      [@api_key, "cst_123", "authorization"]
    )
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
  defp call_operation(:list, client), do: Customers.list(client)
  defp call_operation(:list_payments, client), do: Customers.list_payments(client, "cst_123")
  defp call_operation(:update, client), do: Customers.update(client, "cst_123", %{name: "Jane"})
  defp call_operation(:delete, client), do: Customers.delete(client, "cst_123")

  defp client(opts \\ []) do
    [api_key: @api_key]
    |> Keyword.merge(opts)
    |> then(&TestSupport.client(__MODULE__, &1))
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

  defp customer_fixture_response(conn, status),
    do: fixture_response(conn, @customer_fixture, status)

  defp customer_response(:list_payments, conn), do: payment_list_fixture_response(conn, 200)
  defp customer_response(_operation, conn), do: customer_fixture_response(conn, 200)

  defp customer_list_fixture_response(conn, status) do
    fixture_response(conn, @customer_list_fixture, status)
  end

  defp payment_list_fixture_response(conn, status) do
    fixture_response(conn, @payment_list_fixture, status)
  end
end
