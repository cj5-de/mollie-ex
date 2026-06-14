defmodule MollieEx.SubscriptionsTest do
  use ExUnit.Case, async: false

  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Payment
  alias MollieEx.Subscription
  alias MollieEx.Subscriptions
  alias MollieEx.TestSupport
  alias MollieEx.Types.{Link, Money}

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_subscriptions_secret"

  test "creates a subscription with camelCased body and caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/customers/cst_123/subscriptions"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert header(conn, "idempotency-key") == "subscription-123"

      assert_json_body(conn, %{
        "amount" => %{"currency" => "EUR", "value" => "25.00"},
        "description" => "Quarterly payment",
        "interval" => "3 months",
        "metadata" => %{"order_id" => "order-123"},
        "startDate" => "2026-06-14",
        "webhookUrl" => "https://example.test/webhooks/mollie"
      })

      fixture_response(conn, "subscriptions/get_success.json", 201)
    end)

    assert {:ok, %Subscription{} = subscription} =
             Subscriptions.create(client(), "cst_123", subscription_params(),
               idempotency_key: "subscription-123"
             )

    assert subscription.id == "sub_123"

    assert subscription.amount == %Money{
             currency: "EUR",
             value: "25.00",
             raw: %{"currency" => "EUR", "value" => "25.00"}
           }

    assert subscription.metadata == %{"order_id" => "order-123"}
  end

  test "adds profileId and testmode for OAuth create requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "amount" => %{"currency" => "EUR", "value" => "25.00"},
        "description" => "Quarterly payment",
        "interval" => "3 months",
        "metadata" => %{"order_id" => "order-123"},
        "profileId" => "pfl_123",
        "startDate" => "2026-06-14",
        "testmode" => false,
        "webhookUrl" => "https://example.test/webhooks/mollie"
      })

      fixture_response(conn, "subscriptions/get_success.json", 201)
    end)

    client =
      TestSupport.client(__MODULE__,
        oauth_token: "access_test_secret",
        profile_id: "pfl_123",
        testmode: true
      )

    assert {:ok, %Subscription{id: "sub_123"}} =
             Subscriptions.create(client, "cst_123", subscription_params(), testmode: false)
  end

  test "gets and lists customer subscriptions" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/customers/cst_123/subscriptions/sub_123"
      assert conn.query_string == ""
      fixture_response(conn, "subscriptions/get_success.json", 200)
    end)

    assert {:ok, %Subscription{id: "sub_123"}} =
             Subscriptions.get(client(), "cst_123", "sub_123")

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/customers/cst_123/subscriptions"

      assert URI.decode_query(conn.query_string) == %{
               "from" => "sub_001",
               "limit" => "5",
               "sort" => "desc"
             }

      fixture_response(conn, "subscriptions/list_success.json", 200)
    end)

    assert {:ok, %MollieList{} = subscription_list} =
             Subscriptions.list(client(), "cst_123", from: "sub_001", limit: 5, sort: :desc)

    assert subscription_list.count == 1
    assert [%Subscription{id: "sub_list_123"}] = subscription_list.data

    assert %Link{href: "https://api.mollie.com/v2/customers/cst_123/subscriptions"} =
             subscription_list.links["self"]
  end

  test "lists all subscriptions with optional OAuth profileId omitted" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/subscriptions"
      assert URI.decode_query(conn.query_string) == %{"testmode" => "true"}
      fixture_response(conn, "subscriptions/list_success.json", 200)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %MollieList{data: [%Subscription{id: "sub_list_123"}]}} =
             Subscriptions.all(client)
  end

  test "lists all subscriptions with client profile unless explicitly omitted" do
    client =
      TestSupport.client(__MODULE__,
        organization_token: "org_test_secret",
        profile_id: "pfl_default",
        testmode: true
      )

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/subscriptions"

      assert URI.decode_query(conn.query_string) == %{
               "profileId" => "pfl_default",
               "testmode" => "true"
             }

      fixture_response(conn, "subscriptions/list_success.json", 200)
    end)

    assert {:ok, %MollieList{data: [%Subscription{id: "sub_list_123"}]}} =
             Subscriptions.all(client)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/subscriptions"
      assert URI.decode_query(conn.query_string) == %{"testmode" => "true"}
      fixture_response(conn, "subscriptions/list_success.json", 200)
    end)

    assert {:ok, %MollieList{data: [%Subscription{id: "sub_list_123"}]}} =
             Subscriptions.all(client, profile_id: nil)
  end

  test "updates a subscription with caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v2/customers/cst_123/subscriptions/sub_123"
      assert header(conn, "idempotency-key") == "subscription-update-123"

      assert_json_body(conn, %{
        "amount" => %{"currency" => "EUR", "value" => "30.00"},
        "description" => "Updated quarterly payment",
        "metadata" => %{"order_id" => "order-456"}
      })

      fixture_response(conn, "subscriptions/get_success.json", 200)
    end)

    assert {:ok, %Subscription{id: "sub_123"}} =
             Subscriptions.update(
               client(),
               "cst_123",
               "sub_123",
               %{
                 amount: %{currency: "EUR", value: "30.00"},
                 description: "Updated quarterly payment",
                 metadata: %{"order_id" => "order-456"}
               },
               idempotency_key: "subscription-update-123"
             )
  end

  test "cancels a subscription and returns the canceled subscription" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v2/customers/cst_123/subscriptions/sub_123"
      assert header(conn, "idempotency-key") == "subscription-cancel-123"
      assert_empty_body(conn)

      fixture_response(conn, "subscriptions/canceled_success.json", 200)
    end)

    assert {:ok, %Subscription{} = subscription} =
             Subscriptions.cancel(client(), "cst_123", "sub_123",
               idempotency_key: "subscription-cancel-123"
             )

    assert Subscription.canceled?(subscription)
    assert subscription.canceled_at == "2026-06-14T11:00:00.0Z"
  end

  test "sends testmode in OAuth cancel body" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{"testmode" => false})
      fixture_response(conn, "subscriptions/canceled_success.json", 200)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %Subscription{status: "canceled"}} =
             Subscriptions.cancel(client, "cst_123", "sub_123", testmode: false)
  end

  test "lists subscription payments with OAuth profile and testmode query params" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/customers/cst_123/subscriptions/sub_123/payments"

      assert URI.decode_query(conn.query_string) == %{
               "limit" => "5",
               "profileId" => "pfl_123",
               "sort" => "asc",
               "testmode" => "false"
             }

      fixture_response(conn, "payments/list_success.json", 200)
    end)

    client =
      TestSupport.client(__MODULE__,
        oauth_token: "access_test_secret",
        profile_id: "pfl_123",
        testmode: true
      )

    assert {:ok, %MollieList{} = payment_list} =
             Subscriptions.list_payments(client, "cst_123", "sub_123",
               limit: 5,
               sort: :asc,
               testmode: false
             )

    assert [%Payment{} | _payments] = payment_list.data
  end

  test "rejects invalid subscription options and input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "sub_123"})
    end)

    assert {:error, %Error{reason: :unsupported_profile_id}} =
             Subscriptions.create(
               client(),
               "cst_123",
               Map.put(subscription_params(), :profile_id, "pfl_123")
             )

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Subscriptions.get(client(), "cst_123", "sub_123", testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Subscriptions.list(client(), "cst_123", testmode: true)

    assert {:error, %Error{reason: :unsupported_profile_id}} =
             Subscriptions.all(client(), profile_id: "pfl_123")

    assert {:error, %Error{reason: :unsupported_profile_id}} =
             Subscriptions.update(client(), "cst_123", "sub_123", %{profile_id: "pfl_123"})

    assert {:error, %Error{reason: :invalid_subscription_id}} =
             Subscriptions.cancel(client(), "cst_123", "")

    assert {:error, %Error{reason: :missing_profile_id}} =
             Subscriptions.list_payments(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               "cst_123",
               "sub_123"
             )

    refute_receive :request_sent, 10
  end

  defp client do
    TestSupport.client(__MODULE__, api_key: @api_key)
  end

  defp subscription_params do
    %{
      amount: %{currency: "EUR", value: "25.00"},
      interval: "3 months",
      start_date: "2026-06-14",
      description: "Quarterly payment",
      metadata: %{"order_id" => "order-123"},
      webhook_url: "https://example.test/webhooks/mollie"
    }
  end
end
