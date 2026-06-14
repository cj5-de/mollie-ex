defmodule MollieEx.SubscriptionTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Subscription
  alias MollieEx.Types.{Link, Money}

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "subscription",
      "id" => "sub_123",
      "mode" => "test",
      "status" => "active",
      "amount" => %{"currency" => "EUR", "value" => "25.00"},
      "times" => 4,
      "timesRemaining" => 3,
      "interval" => "3 months",
      "startDate" => "2026-06-14",
      "nextPaymentDate" => "2026-09-14",
      "description" => "Quarterly payment",
      "method" => "directdebit",
      "applicationFee" => %{"description" => "Platform fee"},
      "metadata" => %{"order_id" => "order-123"},
      "webhookUrl" => "https://example.test/webhooks/mollie",
      "customerId" => "cst_123",
      "mandateId" => "mdt_123",
      "createdAt" => "2026-06-14T10:49:08.0Z",
      "_links" => %{
        "payments" => %{
          "href" => "https://api.mollie.com/v2/customers/cst_123/subscriptions/sub_123/payments"
        }
      },
      "futureField" => true
    }

    assert {:ok, %Subscription{} = subscription} =
             Subscription.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :test
             )

    assert subscription.id == "sub_123"
    assert Subscription.active?(subscription)
    refute Subscription.canceled?(subscription)
    assert subscription.amount == %Money{currency: "EUR", value: "25.00", raw: body["amount"]}
    assert subscription.times_remaining == 3
    assert subscription.next_payment_date == "2026-09-14"
    assert subscription.application_fee == %{"description" => "Platform fee"}
    assert subscription.metadata == %{"order_id" => "order-123"}
    assert subscription.webhook_url == "https://example.test/webhooks/mollie"
    assert %Link{} = subscription.links["payments"]
    assert subscription.raw["futureField"] == true
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{
      status: 200,
      headers: %{},
      body: %{"resource" => "subscription"},
      raw: %{}
    }

    assert {:error, %Error{type: :decode, reason: :invalid_subscription_response}} =
             Subscription.from_response(response, :subscriptions_get)
  end
end
