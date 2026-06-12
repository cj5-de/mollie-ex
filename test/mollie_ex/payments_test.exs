defmodule MollieEx.PaymentsTest do
  use ExUnit.Case, async: false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Payment
  alias MollieEx.Payments
  alias MollieEx.Types.{Link, Money}

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_payments_secret"
  @payment_fixture Path.expand("../fixtures/mollie/payments/create_success.json", __DIR__)
  @payment_list_fixture Path.expand("../fixtures/mollie/payments/list_success.json", __DIR__)

  test "creates a payment with camelCased body, include query, and caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/payments"
      assert URI.decode_query(conn.query_string) == %{"include" => "details.qrCode"}
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert header(conn, "idempotency-key") == "order-123"

      assert_json_body(conn, %{
        "amount" => %{"currency" => "EUR", "value" => "10.00"},
        "description" => "Order #123",
        "redirectUrl" => "https://example.test/return",
        "webhookUrl" => "https://example.test/webhook",
        "billingAddress" => %{"givenName" => "Ada"},
        "extraMerchantData" => %{
          "customer_account_info" => %{"account_age" => 12},
          "shipping_address" => %{"street_and_number" => "Main 1"}
        },
        "metadata" => %{
          "order_id" => "123",
          "nested_meta" => %{"line_id" => "1"},
          "items" => [%{"sku_id" => "sku_123"}]
        }
      })

      payment_fixture_response(conn, 201)
    end)

    params = %{
      "webhook_url" => "https://example.test/webhook",
      amount: %{currency: "EUR", value: "10.00"},
      description: "Order #123",
      redirect_url: "https://example.test/return",
      billing_address: %{given_name: "Ada"},
      extra_merchant_data: %{
        "customer_account_info" => %{"account_age" => 12},
        "shipping_address" => %{"street_and_number" => "Main 1"}
      },
      metadata: %{
        "order_id" => "123",
        "nested_meta" => %{"line_id" => "1"},
        "items" => [%{"sku_id" => "sku_123"}]
      }
    }

    assert {:ok, %Payment{} = payment} =
             Payments.create(client(), params,
               idempotency_key: "order-123",
               include: "details.qrCode"
             )

    assert payment.id == "tr_123"
    assert payment.status == "open"

    assert payment.amount == %Money{
             currency: "EUR",
             value: "10.00",
             raw: %{"currency" => "EUR", "value" => "10.00"}
           }

    assert %Link{href: "https://www.mollie.com/checkout/select-method/tr_123"} =
             payment.links["checkout"]

    assert payment.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "adds profileId and testmode for OAuth create requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "amount" => %{"currency" => "EUR", "value" => "10.00"},
        "description" => "Order #123",
        "profileId" => "pfl_override",
        "redirectUrl" => "https://example.test/return",
        "testmode" => false
      })

      payment_fixture_response(conn, 201)
    end)

    client =
      Client.new!(
        oauth_token: "access_test_secret",
        profile_id: "pfl_default",
        testmode: true,
        transport: {:req_test, __MODULE__}
      )

    assert {:ok, %Payment{id: "tr_123"}} =
             Payments.create(
               client,
               %{
                 amount: %{currency: "EUR", value: "10.00"},
                 description: "Order #123",
                 redirect_url: "https://example.test/return"
               },
               profile_id: "pfl_override",
               testmode: false
             )
  end

  test "honors params-level testmode false over OAuth client default" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "amount" => %{"currency" => "EUR", "value" => "10.00"},
        "description" => "Order #123",
        "profileId" => "pfl_default",
        "redirectUrl" => "https://example.test/return",
        "testmode" => false
      })

      payment_fixture_response(conn, 201)
    end)

    client =
      Client.new!(
        oauth_token: "access_test_secret",
        profile_id: "pfl_default",
        testmode: true,
        transport: {:req_test, __MODULE__}
      )

    assert {:ok, %Payment{id: "tr_123"}} =
             Payments.create(client, %{
               amount: %{currency: "EUR", value: "10.00"},
               description: "Order #123",
               redirect_url: "https://example.test/return",
               testmode: false
             })
  end

  test "requires profileId for non-API-key create requests" do
    client = Client.new!(oauth_token: "access_test_secret", transport: {:req_test, __MODULE__})

    assert {:error, %Error{} = error} =
             Payments.create(client, %{description: "Order #123"})

    assert error.type == :configuration
    assert error.reason == :missing_profile_id
  end

  test "rejects profileId and testmode for API-key create requests before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    assert {:error, %Error{reason: :unsupported_profile_id}} =
             Payments.create(client(), %{description: "Order #123", profile_id: "pfl_123"})

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Payments.create(client(), %{description: "Order #123", testmode: true})

    refute_receive :request_sent, 10
  end

  test "does not retry payment create without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    client = client(max_retries: 1)

    assert {:error, %Error{type: :server_error, status: 503}} =
             Payments.create(client, %{description: "Order #123"})
  end

  test "updates a payment with camelCased body and caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v2/payments/tr_123"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert header(conn, "idempotency-key") == "update-123"

      assert_json_body(conn, %{
        "description" => "Updated order #123",
        "redirectUrl" => "https://example.test/updated-return",
        "cancelUrl" => nil,
        "billingAddress" => %{"givenName" => "Ada", "streetAndNumber" => "Main 1"},
        "shippingAddress" => %{"familyName" => "Lovelace"},
        "extraMerchantData" => %{
          "customer_account_info" => %{"account_age" => 12},
          "shipping_address" => %{"street_and_number" => "Main 1"}
        },
        "metadata" => %{
          "order_id" => "123",
          "nested_meta" => %{"line_id" => "1"},
          "items" => [%{"sku_id" => "sku_123"}]
        }
      })

      payment_fixture_response(conn, 200)
    end)

    params = %{
      description: "Updated order #123",
      redirect_url: "https://example.test/updated-return",
      cancel_url: nil,
      billing_address: %{given_name: "Ada", street_and_number: "Main 1"},
      shipping_address: %{family_name: "Lovelace"},
      extra_merchant_data: %{
        "customer_account_info" => %{"account_age" => 12},
        "shipping_address" => %{"street_and_number" => "Main 1"}
      },
      metadata: %{
        "order_id" => "123",
        "nested_meta" => %{"line_id" => "1"},
        "items" => [%{"sku_id" => "sku_123"}]
      }
    }

    assert {:ok, %Payment{id: "tr_123"} = payment} =
             Payments.update(client(), "tr_123", params, idempotency_key: "update-123")

    assert payment.status == "open"
  end

  test "honors opts-level testmode false for OAuth update requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "description" => "Updated order #123",
        "testmode" => false
      })

      payment_fixture_response(conn, 200)
    end)

    client =
      Client.new!(
        oauth_token: "access_test_secret",
        profile_id: "pfl_default",
        testmode: true,
        transport: {:req_test, __MODULE__}
      )

    assert {:ok, %Payment{id: "tr_123"}} =
             Payments.update(
               client,
               "tr_123",
               %{description: "Updated order #123", testmode: true},
               testmode: false
             )
  end

  test "rejects profileId and testmode for payment update requests before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    assert {:error, %Error{reason: :unsupported_profile_id}} =
             Payments.update(client(), "tr_123", %{
               description: "Order #123",
               profile_id: "pfl_123"
             })

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Payments.update(client(), "tr_123", %{description: "Order #123", testmode: true})

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Payments.update(client(), "tr_123", %{description: "Order #123"}, testmode: true)

    refute_receive :request_sent, 10
  end

  test "does not retry payment update without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    client = client(max_retries: 1)

    assert {:error, %Error{type: :server_error, status: 503}} =
             Payments.update(client, "tr_123", %{description: "Updated order #123"})
  end

  test "retries payment update with the same caller idempotency key and body" do
    expected_body = %{"description" => "Updated order #123"}

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert header(conn, "idempotency-key") == "update-123"
      assert_json_body(conn, expected_body)

      conn
      |> Plug.Conn.put_resp_header("retry-after", "0")
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert header(conn, "idempotency-key") == "update-123"
      assert_json_body(conn, expected_body)

      payment_fixture_response(conn, 200)
    end)

    assert {:ok, %Payment{id: "tr_123"}} =
             Payments.update(
               client(max_retries: 1),
               "tr_123",
               %{description: "Updated order #123"},
               idempotency_key: "update-123"
             )
  end

  test "cancels a payment with caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v2/payments/tr_123"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert header(conn, "idempotency-key") == "cancel-123"
      assert_empty_body(conn)

      payment_fixture_response(conn, 200)
    end)

    assert {:ok, %Payment{id: "tr_123"} = payment} =
             Payments.cancel(client(), "tr_123", idempotency_key: "cancel-123")

    assert payment.status == "open"
  end

  test "honors opts-level testmode false for OAuth cancel requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert_json_body(conn, %{"testmode" => false})

      payment_fixture_response(conn, 200)
    end)

    client =
      Client.new!(
        oauth_token: "access_test_secret",
        profile_id: "pfl_default",
        testmode: true,
        transport: {:req_test, __MODULE__}
      )

    assert {:ok, %Payment{id: "tr_123"}} =
             Payments.cancel(client, "tr_123", testmode: false)
  end

  test "rejects testmode for payment cancel requests before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Payments.cancel(client(), "tr_123", testmode: true)

    refute_receive :request_sent, 10
  end

  test "does not retry payment cancel without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    client = client(max_retries: 1)

    assert {:error, %Error{type: :server_error, status: 503}} =
             Payments.cancel(client, "tr_123")
  end

  test "retries payment cancel with the same caller idempotency key and body" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert header(conn, "idempotency-key") == "cancel-123"
      assert_empty_body(conn)

      conn
      |> Plug.Conn.put_resp_header("retry-after", "0")
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert header(conn, "idempotency-key") == "cancel-123"
      assert_empty_body(conn)

      payment_fixture_response(conn, 200)
    end)

    assert {:ok, %Payment{id: "tr_123"}} =
             Payments.cancel(client(max_retries: 1), "tr_123", idempotency_key: "cancel-123")
  end

  test "gets a payment with include and embed query params" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/payments/tr_123"

      assert URI.decode_query(conn.query_string) == %{
               "embed" => "refunds",
               "include" => "details.remainderDetails"
             }

      assert header(conn, "idempotency-key") == nil

      payment_fixture_response(conn, 200)
    end)

    assert {:ok, %Payment{id: "tr_123"}} =
             Payments.get(client(), "tr_123",
               include: "details.remainderDetails",
               embed: "refunds"
             )
  end

  test "gets OAuth payments in client testmode" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert URI.decode_query(conn.query_string) == %{"testmode" => "true"}

      payment_fixture_response(conn, 200)
    end)

    client =
      Client.new!(
        organization_token: "org_test_secret",
        profile_id: "pfl_123",
        testmode: true,
        transport: {:req_test, __MODULE__}
      )

    assert {:ok, %Payment{id: "tr_123"}} = Payments.get(client, "tr_123")
  end

  test "lists payments with pagination query params" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/payments"

      assert URI.decode_query(conn.query_string) == %{
               "from" => "tr_from",
               "limit" => "2",
               "sort" => "asc"
             }

      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert header(conn, "idempotency-key") == nil

      payment_list_fixture_response(conn, 200)
    end)

    assert {:ok, %MollieList{} = list} =
             Payments.list(client(), from: "tr_from", limit: 2, sort: :asc)

    assert list.count == 1

    assert %Link{href: "https://api.mollie.com/v2/payments?from=tr_next&limit=1"} =
             list.links["next"]

    assert [%Payment{id: "tr_list_123"} = payment] = list.data
    assert payment.amount == %Money{currency: "EUR", value: "75.00", raw: payment.amount.raw}
    assert payment.metadata == %{"order_id" => "12345"}
    assert payment.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "lists OAuth payments with profileId and explicit false testmode" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert URI.decode_query(conn.query_string) == %{
               "profileId" => "pfl_override",
               "testmode" => "false"
             }

      payment_list_fixture_response(conn, 200)
    end)

    client =
      Client.new!(
        organization_token: "org_test_secret",
        profile_id: "pfl_default",
        testmode: true,
        transport: {:req_test, __MODULE__}
      )

    assert {:ok, %MollieList{data: [%Payment{id: "tr_list_123"}]}} =
             Payments.list(client, profile_id: "pfl_override", testmode: false)
  end

  test "requires profileId for non-API-key list requests" do
    client = Client.new!(oauth_token: "access_test_secret", transport: {:req_test, __MODULE__})

    assert {:error, %Error{} = error} = Payments.list(client)
    assert error.type == :configuration
    assert error.reason == :missing_profile_id
  end

  test "rejects profileId and testmode for API-key list requests before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"count" => 0, "_embedded" => %{}, "_links" => %{}})
    end)

    assert {:error, %Error{reason: :unsupported_profile_id}} =
             Payments.list(client(), profile_id: "pfl_123")

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Payments.list(client(), testmode: true)

    refute_receive :request_sent, 10
  end

  test "maps payment API errors through the SDK error model" do
    for {status, type} <- [
          {401, :authentication},
          {404, :not_found},
          {422, :validation},
          {429, :rate_limited},
          {503, :server_error}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-request-id", "req_#{status}")
        |> Plug.Conn.put_status(status)
        |> Req.Test.json(%{
          "status" => status,
          "title" => "Mollie error",
          "detail" => "Payment failed",
          "_links" => %{"documentation" => %{"href" => "https://docs.mollie.com/"}}
        })
      end)

      assert {:error, %Error{} = error} = Payments.get(client(max_retries: 0), "tr_#{status}")
      assert error.type == type
      assert error.status == status
      assert error.operation == :payments_get
      assert error.request_id == "req_#{status}"
      assert error.raw["detail"] == "Payment failed"
    end
  end

  test "maps payment list API errors through the SDK error model" do
    for {status, type} <- [
          {401, :authentication},
          {404, :not_found},
          {422, :validation},
          {429, :rate_limited},
          {503, :server_error}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-request-id", "req_list_#{status}")
        |> Plug.Conn.put_status(status)
        |> Req.Test.json(%{
          "status" => status,
          "title" => "Mollie error",
          "detail" => "Payment list failed"
        })
      end)

      assert {:error, %Error{} = error} = Payments.list(client(max_retries: 0))
      assert error.type == type
      assert error.status == status
      assert error.operation == :payments_list
      assert error.request_id == "req_list_#{status}"
      assert error.raw["detail"] == "Payment list failed"
    end
  end

  test "maps payment update API errors through the SDK error model" do
    for {status, type} <- [
          {401, :authentication},
          {404, :not_found},
          {422, :validation},
          {429, :rate_limited},
          {503, :server_error}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-request-id", "req_update_#{status}")
        |> Plug.Conn.put_status(status)
        |> Req.Test.json(%{
          "status" => status,
          "title" => "Mollie error",
          "detail" => "Payment update failed"
        })
      end)

      assert {:error, %Error{} = error} =
               Payments.update(client(max_retries: 0), "tr_#{status}", %{description: "Updated"})

      assert error.type == type
      assert error.status == status
      assert error.operation == :payments_update
      assert error.request_id == "req_update_#{status}"
      assert error.raw["detail"] == "Payment update failed"
    end
  end

  test "maps payment cancel API errors through the SDK error model" do
    for {status, type} <- [
          {401, :authentication},
          {404, :not_found},
          {422, :validation},
          {429, :rate_limited},
          {503, :server_error}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-request-id", "req_cancel_#{status}")
        |> Plug.Conn.put_status(status)
        |> Req.Test.json(%{
          "status" => status,
          "title" => "Mollie error",
          "detail" => "Payment cancel failed"
        })
      end)

      assert {:error, %Error{} = error} =
               Payments.cancel(client(max_retries: 0), "tr_#{status}")

      assert error.type == type
      assert error.status == status
      assert error.operation == :payments_cancel
      assert error.request_id == "req_cancel_#{status}"
      assert error.raw["detail"] == "Payment cancel failed"
    end
  end

  test "maps malformed payment JSON into decode errors" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.send_resp(200, "{")
    end)

    assert {:error, %Error{} = error} = Payments.get(client(max_retries: 0), "tr_123")
    assert error.type == :decode
    assert error.operation == :payments_get
    assert error.raw == "{"
  end

  test "maps malformed payment update JSON into decode errors" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.send_resp(200, "{")
    end)

    assert {:error, %Error{} = error} =
             Payments.update(client(max_retries: 0), "tr_123", %{description: "Updated"})

    assert error.type == :decode
    assert error.operation == :payments_update
    assert error.raw == "{"
  end

  test "maps malformed payment cancel JSON into decode errors" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.send_resp(200, "{")
    end)

    assert {:error, %Error{} = error} = Payments.cancel(client(max_retries: 0), "tr_123")
    assert error.type == :decode
    assert error.operation == :payments_cancel
    assert error.raw == "{"
  end

  test "maps malformed payment list JSON into decode errors" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.send_resp(200, "{")
    end)

    assert {:error, %Error{} = error} = Payments.list(client(max_retries: 0))
    assert error.type == :decode
    assert error.operation == :payments_list
    assert error.raw == "{"
  end

  test "maps transport timeouts into timeout errors" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Error{} = error} = Payments.get(client(max_retries: 0), "tr_123")
    assert error.type == :timeout
    assert error.operation == :payments_get

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Error{} = error} = Payments.list(client(max_retries: 0))
    assert error.type == :timeout
    assert error.operation == :payments_list

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Error{} = error} =
             Payments.update(client(max_retries: 0), "tr_123", %{description: "Updated"})

    assert error.type == :timeout
    assert error.operation == :payments_update

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Error{} = error} = Payments.cancel(client(max_retries: 0), "tr_123")
    assert error.type == :timeout
    assert error.operation == :payments_cancel
  end

  test "rejects invalid local inputs before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "tr_123"})
    end)

    assert {:error, %Error{reason: :invalid_payment_params}} =
             Payments.create(client(), "bad")

    assert {:error, %Error{reason: :invalid_payment_id}} = Payments.get(client(), "")

    assert {:error, %Error{reason: :invalid_payment_id}} =
             Payments.update(client(), "", %{description: "Updated"})

    assert {:error, %Error{reason: :invalid_payment_id}} = Payments.cancel(client(), "")

    assert {:error, %Error{reason: :invalid_payment_params}} =
             Payments.update(client(), "tr_123", "bad")

    assert {:error, %Error{reason: :invalid_options}} =
             Payments.update(client(), "tr_123", %{description: "Updated"}, "bad")

    assert {:error, %Error{reason: :invalid_options}} =
             Payments.cancel(client(), "tr_123", "bad")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Payments.get(client(), "tr_123", unknown: true)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Payments.update(client(), "tr_123", %{description: "Updated"}, unknown: true)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Payments.cancel(client(), "tr_123", unknown: true)

    assert {:error, %Error{reason: :invalid_testmode}} =
             Payments.update(
               Client.new!(
                 oauth_token: "access_test_secret",
                 transport: {:req_test, __MODULE__}
               ),
               "tr_123",
               %{description: "Updated"},
               testmode: "true"
             )

    assert {:error, %Error{reason: :invalid_testmode}} =
             Payments.cancel(
               Client.new!(
                 oauth_token: "access_test_secret",
                 transport: {:req_test, __MODULE__}
               ),
               "tr_123",
               testmode: "true"
             )

    assert {:error, %Error{reason: :unsupported_profile_id}} =
             Payments.update(client(), "tr_123", %{"profileId" => "pfl_123"})

    assert {:error, %Error{reason: :invalid_options}} = Payments.list(client(), "bad")
    assert {:error, %Error{reason: :invalid_client}} = Payments.list("bad")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Payments.list(client(), unknown: true)

    assert {:error, %Error{reason: {:invalid_option, :from}}} =
             Payments.list(client(), from: "")

    assert {:error, %Error{reason: {:invalid_option, :limit}}} =
             Payments.list(client(), limit: 0)

    assert {:error, %Error{reason: {:invalid_option, :sort}}} =
             Payments.list(client(), sort: :newest)

    refute_receive :request_sent, 10
  end

  test "returns decode errors for invalid payment response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"status" => "open"})
    end)

    assert {:error, %Error{} = error} = Payments.get(client(), "tr_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_payment_response
    assert error.operation == :payments_get
    assert error.raw == %{"status" => "open"}
  end

  test "returns decode errors for invalid payment update response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"status" => "open"})
    end)

    assert {:error, %Error{} = error} =
             Payments.update(client(), "tr_123", %{description: "Updated"})

    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_payment_response
    assert error.operation == :payments_update
    assert error.raw == %{"status" => "open"}
  end

  test "returns decode errors for invalid payment cancel response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"status" => "open"})
    end)

    assert {:error, %Error{} = error} = Payments.cancel(client(), "tr_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_payment_response
    assert error.operation == :payments_cancel
    assert error.raw == %{"status" => "open"}
  end

  test "returns decode errors for invalid payment list response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"count" => 1, "_embedded" => %{"payments" => %{}}, "_links" => %{}})
    end)

    assert {:error, %Error{} = error} = Payments.list(client())
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_list_response
    assert error.operation == :payments_list
    assert error.raw == %{"count" => 1, "_embedded" => %{"payments" => %{}}, "_links" => %{}}
  end

  test "returns decode errors for invalid embedded payment list items" do
    invalid_payment = %{"status" => "open"}

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"payments" => [invalid_payment]},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{} = error} = Payments.list(client())
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_payment_response
    assert error.operation == :payments_list
    assert error.raw == invalid_payment
  end

  test "emits exception telemetry for invalid hydrated payment response shapes" do
    prefix = [:mollie_payments_test_hydration_decode]

    attach_telemetry(prefix, [
      [:request, :start],
      [:request, :stop],
      [:request, :exception],
      [:decode, :exception]
    ])

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"status" => "open"})
    end)

    assert {:error, %Error{} = error} =
             Payments.get(client(telemetry_prefix: prefix), "tr_123")

    assert error.type == :decode
    assert error.reason == :invalid_payment_response

    start_event = prefix ++ [:request, :start]
    decode_event = prefix ++ [:decode, :exception]
    request_exception_event = prefix ++ [:request, :exception]
    stop_event = prefix ++ [:request, :stop]

    assert_receive {:telemetry, ^start_event, %{system_time: system_time}, start_metadata}
    assert is_integer(system_time)
    assert start_metadata.operation == :payments_get
    assert start_metadata.path_template == "/payments/{paymentId}"

    assert_receive {:telemetry, ^decode_event, %{duration: _duration}, decode_metadata}
    assert decode_metadata.error_type == :decode
    assert decode_metadata.reason == :invalid_payment_response
    assert decode_metadata.status == 200
    assert decode_metadata.operation == :payments_get
    assert decode_metadata.path_template == "/payments/{paymentId}"

    assert_receive {:telemetry, ^request_exception_event, %{duration: _duration},
                    exception_metadata}

    assert exception_metadata.error_type == :decode
    assert exception_metadata.reason == :invalid_payment_response
    assert exception_metadata.status == 200

    refute_receive {:telemetry, ^stop_event, _measurements, _metadata}, 20
  end

  test "emits exception telemetry for invalid hydrated payment update response shapes" do
    prefix = [:mollie_payments_test_update_hydration_decode]

    attach_telemetry(prefix, [
      [:request, :start],
      [:request, :stop],
      [:request, :exception],
      [:decode, :exception]
    ])

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"status" => "open"})
    end)

    assert {:error, %Error{} = error} =
             Payments.update(client(telemetry_prefix: prefix), "tr_123", %{description: "Updated"})

    assert error.type == :decode
    assert error.reason == :invalid_payment_response

    start_event = prefix ++ [:request, :start]
    decode_event = prefix ++ [:decode, :exception]
    request_exception_event = prefix ++ [:request, :exception]
    stop_event = prefix ++ [:request, :stop]

    assert_receive {:telemetry, ^start_event, %{system_time: system_time}, start_metadata}
    assert is_integer(system_time)
    assert start_metadata.operation == :payments_update
    assert start_metadata.method == "PATCH"
    assert start_metadata.path_template == "/payments/{paymentId}"

    assert_receive {:telemetry, ^decode_event, %{duration: _duration}, decode_metadata}
    assert decode_metadata.error_type == :decode
    assert decode_metadata.reason == :invalid_payment_response
    assert decode_metadata.status == 200
    assert decode_metadata.operation == :payments_update
    assert decode_metadata.path_template == "/payments/{paymentId}"

    assert_receive {:telemetry, ^request_exception_event, %{duration: _duration},
                    exception_metadata}

    assert exception_metadata.error_type == :decode
    assert exception_metadata.reason == :invalid_payment_response
    assert exception_metadata.status == 200

    refute_receive {:telemetry, ^stop_event, _measurements, _metadata}, 20
  end

  test "emits exception telemetry for invalid hydrated payment cancel response shapes" do
    prefix = [:mollie_payments_test_cancel_hydration_decode]

    attach_telemetry(prefix, [
      [:request, :start],
      [:request, :stop],
      [:request, :exception],
      [:decode, :exception]
    ])

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"status" => "open"})
    end)

    assert {:error, %Error{} = error} =
             Payments.cancel(client(telemetry_prefix: prefix), "tr_123")

    assert error.type == :decode
    assert error.reason == :invalid_payment_response

    start_event = prefix ++ [:request, :start]
    decode_event = prefix ++ [:decode, :exception]
    request_exception_event = prefix ++ [:request, :exception]
    stop_event = prefix ++ [:request, :stop]

    assert_receive {:telemetry, ^start_event, %{system_time: system_time}, start_metadata}
    assert is_integer(system_time)
    assert start_metadata.operation == :payments_cancel
    assert start_metadata.method == "DELETE"
    assert start_metadata.path_template == "/payments/{paymentId}"

    assert_receive {:telemetry, ^decode_event, %{duration: _duration}, decode_metadata}
    assert decode_metadata.error_type == :decode
    assert decode_metadata.reason == :invalid_payment_response
    assert decode_metadata.status == 200
    assert decode_metadata.operation == :payments_cancel
    assert decode_metadata.path_template == "/payments/{paymentId}"

    assert_receive {:telemetry, ^request_exception_event, %{duration: _duration},
                    exception_metadata}

    assert exception_metadata.error_type == :decode
    assert exception_metadata.reason == :invalid_payment_response
    assert exception_metadata.status == 200

    refute_receive {:telemetry, ^stop_event, _measurements, _metadata}, 20
  end

  test "emits exception telemetry for invalid hydrated payment list response shapes" do
    prefix = [:mollie_payments_test_list_hydration_decode]

    attach_telemetry(prefix, [
      [:request, :start],
      [:request, :stop],
      [:request, :exception],
      [:decode, :exception]
    ])

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"count" => 1, "_embedded" => %{"payments" => %{}}, "_links" => %{}})
    end)

    assert {:error, %Error{} = error} =
             Payments.list(client(telemetry_prefix: prefix))

    assert error.type == :decode
    assert error.reason == :invalid_list_response

    start_event = prefix ++ [:request, :start]
    decode_event = prefix ++ [:decode, :exception]
    request_exception_event = prefix ++ [:request, :exception]
    stop_event = prefix ++ [:request, :stop]

    assert_receive {:telemetry, ^start_event, %{system_time: system_time}, start_metadata}
    assert is_integer(system_time)
    assert start_metadata.operation == :payments_list
    assert start_metadata.path_template == "/payments"

    assert_receive {:telemetry, ^decode_event, %{duration: _duration}, decode_metadata}
    assert decode_metadata.error_type == :decode
    assert decode_metadata.reason == :invalid_list_response
    assert decode_metadata.status == 200
    assert decode_metadata.operation == :payments_list
    assert decode_metadata.path_template == "/payments"

    assert_receive {:telemetry, ^request_exception_event, %{duration: _duration},
                    exception_metadata}

    assert exception_metadata.error_type == :decode
    assert exception_metadata.reason == :invalid_list_response
    assert exception_metadata.status == 200

    refute_receive {:telemetry, ^stop_event, _measurements, _metadata}, 20
  end

  test "emits safe request telemetry for successful payment calls" do
    prefix = [:mollie_payments_test_success]
    attach_telemetry(prefix, [[:request, :start], [:request, :stop]])

    Req.Test.expect(__MODULE__, fn conn ->
      payment_fixture_response(conn, 201)
    end)

    client = client(telemetry_prefix: prefix)

    assert {:ok, %Payment{}} =
             Payments.create(client, %{description: "Order #123"}, idempotency_key: "order-123")

    start_event = prefix ++ [:request, :start]
    stop_event = prefix ++ [:request, :stop]

    assert_receive {:telemetry, ^start_event, %{system_time: system_time}, start_metadata}
    assert is_integer(system_time)
    assert start_metadata.operation == :payments_create
    assert start_metadata.method == "POST"
    assert start_metadata.path_template == "/payments"

    assert_receive {:telemetry, ^stop_event, %{duration: duration}, stop_metadata}
    assert is_integer(duration)
    assert stop_metadata.status == 201
    assert stop_metadata.operation == :payments_create

    telemetry_text = inspect([start_metadata, stop_metadata])
    refute telemetry_text =~ @api_key
    refute telemetry_text =~ "order-123"
    refute telemetry_text =~ "Order #123"
    refute telemetry_text =~ "authorization"
  end

  test "emits safe request telemetry for successful payment update calls" do
    prefix = [:mollie_payments_test_update_success]
    attach_telemetry(prefix, [[:request, :start], [:request, :stop]])

    Req.Test.expect(__MODULE__, fn conn ->
      payment_fixture_response(conn, 200)
    end)

    assert {:ok, %Payment{}} =
             client(telemetry_prefix: prefix)
             |> Payments.update("tr_123", %{description: "Updated order #123"},
               idempotency_key: "update-123"
             )

    start_event = prefix ++ [:request, :start]
    stop_event = prefix ++ [:request, :stop]

    assert_receive {:telemetry, ^start_event, %{system_time: system_time}, start_metadata}
    assert is_integer(system_time)
    assert start_metadata.operation == :payments_update
    assert start_metadata.method == "PATCH"
    assert start_metadata.path_template == "/payments/{paymentId}"

    assert_receive {:telemetry, ^stop_event, %{duration: duration}, stop_metadata}
    assert is_integer(duration)
    assert stop_metadata.status == 200
    assert stop_metadata.operation == :payments_update

    telemetry_text = inspect([start_metadata, stop_metadata])
    refute telemetry_text =~ @api_key
    refute telemetry_text =~ "update-123"
    refute telemetry_text =~ "Updated order #123"
    refute telemetry_text =~ "authorization"
  end

  test "emits safe request telemetry for successful payment cancel calls" do
    prefix = [:mollie_payments_test_cancel_success]
    attach_telemetry(prefix, [[:request, :start], [:request, :stop]])

    Req.Test.expect(__MODULE__, fn conn ->
      payment_fixture_response(conn, 200)
    end)

    assert {:ok, %Payment{}} =
             client(telemetry_prefix: prefix)
             |> Payments.cancel("tr_123", idempotency_key: "cancel-123")

    start_event = prefix ++ [:request, :start]
    stop_event = prefix ++ [:request, :stop]

    assert_receive {:telemetry, ^start_event, %{system_time: system_time}, start_metadata}
    assert is_integer(system_time)
    assert start_metadata.operation == :payments_cancel
    assert start_metadata.method == "DELETE"
    assert start_metadata.path_template == "/payments/{paymentId}"

    assert_receive {:telemetry, ^stop_event, %{duration: duration}, stop_metadata}
    assert is_integer(duration)
    assert stop_metadata.status == 200
    assert stop_metadata.operation == :payments_cancel

    telemetry_text = inspect([start_metadata, stop_metadata])
    refute telemetry_text =~ @api_key
    refute telemetry_text =~ "cancel-123"
    refute telemetry_text =~ "authorization"
  end

  test "emits safe request telemetry for successful payment list calls" do
    prefix = [:mollie_payments_test_list_success]
    attach_telemetry(prefix, [[:request, :start], [:request, :stop]])

    Req.Test.expect(__MODULE__, fn conn ->
      payment_list_fixture_response(conn, 200)
    end)

    assert {:ok, %MollieList{}} =
             client(telemetry_prefix: prefix)
             |> Payments.list(limit: 1, sort: "desc")

    start_event = prefix ++ [:request, :start]
    stop_event = prefix ++ [:request, :stop]

    assert_receive {:telemetry, ^start_event, %{system_time: system_time}, start_metadata}
    assert is_integer(system_time)
    assert start_metadata.operation == :payments_list
    assert start_metadata.method == "GET"
    assert start_metadata.path_template == "/payments"

    assert_receive {:telemetry, ^stop_event, %{duration: duration}, stop_metadata}
    assert is_integer(duration)
    assert stop_metadata.status == 200
    assert stop_metadata.operation == :payments_list

    telemetry_text = inspect([start_metadata, stop_metadata])
    refute telemetry_text =~ @api_key
    refute telemetry_text =~ "authorization"
  end

  test "emits safe decode exception and rate limit telemetry" do
    prefix = [:mollie_payments_test_errors]

    attach_telemetry(prefix, [
      [:request, :start],
      [:request, :stop],
      [:request, :exception],
      [:decode, :exception],
      [:rate_limit]
    ])

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.send_resp(200, "{")
    end)

    assert {:error, %Error{type: :decode}} =
             Payments.get(client(telemetry_prefix: prefix, max_retries: 0), "tr_123")

    decode_event = prefix ++ [:decode, :exception]
    request_exception_event = prefix ++ [:request, :exception]

    assert_receive {:telemetry, ^decode_event, %{duration: _duration}, decode_metadata}
    assert decode_metadata.error_type == :decode
    assert decode_metadata.path_template == "/payments/{paymentId}"

    assert_receive {:telemetry, ^request_exception_event, %{duration: _duration},
                    exception_metadata}

    assert exception_metadata.error_type == :decode

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(429)
      |> Req.Test.json(%{"status" => 429, "title" => "Too Many Requests"})
    end)

    assert {:error, %Error{type: :rate_limited}} =
             Payments.get(client(telemetry_prefix: prefix, max_retries: 0), "tr_123")

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

  defp client(opts \\ []) do
    [api_key: @api_key, transport: {:req_test, __MODULE__}]
    |> Keyword.merge(opts)
    |> Client.new!()
  end

  defp payment_fixture_response(conn, status) do
    conn
    |> Plug.Conn.put_resp_header("content-type", "application/hal+json")
    |> Plug.Conn.send_resp(status, File.read!(@payment_fixture))
  end

  defp payment_list_fixture_response(conn, status) do
    conn
    |> Plug.Conn.put_resp_header("content-type", "application/hal+json")
    |> Plug.Conn.send_resp(status, File.read!(@payment_list_fixture))
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
