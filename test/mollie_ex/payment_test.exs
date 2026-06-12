defmodule MollieEx.PaymentTest do
  use ExUnit.Case, async: true

  alias MollieEx.HTTP.Response
  alias MollieEx.Payment
  alias MollieEx.Types.{Link, Money}

  @rich_payment_fixture Path.expand("../fixtures/mollie/payments/rich_response.json", __DIR__)

  test "decodes stable payment response fields and preserves raw payloads" do
    body = rich_payment_fixture()

    assert {:ok, %Payment{} = payment} =
             body
             |> response()
             |> Payment.from_response(:payments_get)

    assert payment.id == "tr_rich_123"
    assert payment.resource == "payment"
    assert payment.mode == "test"
    assert payment.created_at == "2026-06-12T10:00:00+00:00"
    assert payment.authorized_at == "2026-06-12T10:01:00+00:00"
    assert payment.paid_at == "2026-06-12T10:02:00+00:00"
    assert payment.canceled_at == "2026-06-12T10:03:00+00:00"
    assert payment.expires_at == "2026-06-13T10:00:00+00:00"
    assert payment.expired_at == "2026-06-13T10:01:00+00:00"
    assert payment.failed_at == "2026-06-13T10:02:00+00:00"
    assert payment.status == "paid"

    assert payment.status_reason == %{
             "code" => "approved",
             "description" => "The payment was approved."
           }

    assert payment.is_cancelable == false

    assert payment.amount == money("EUR", "75.00")
    assert payment.amount_refunded == money("EUR", "10.00")
    assert payment.amount_remaining == money("EUR", "65.00")
    assert payment.amount_captured == money("EUR", "70.00")
    assert payment.amount_charged_back == money("EUR", "5.00")
    assert payment.settlement_amount == money("EUR", "72.50")

    assert payment.description == "Order #12345"
    assert payment.method == "creditcard"
    assert payment.metadata == %{"order_id" => "12345", "nested_meta" => %{"line_id" => "1"}}
    assert payment.details == %{"consumerName" => "Jane Doe", "cardLabel" => "Visa"}
    assert payment.profile_id == "pfl_123"
    assert payment.sequence_type == "first"
    assert payment.redirect_url == "https://webshop.example.org/order/12345/return"
    assert payment.cancel_url == "https://webshop.example.org/order/12345/cancel"
    assert payment.webhook_url == "https://webshop.example.org/webhooks/mollie"
    assert payment.locale == "nl_NL"
    assert payment.country_code == "NL"
    assert payment.customer_id == "cst_123"
    assert payment.mandate_id == "mdt_123"
    assert payment.subscription_id == "sub_123"
    assert payment.order_id == "ord_123"
    assert payment.settlement_id == "stl_123"
    assert payment.capture_mode == "manual"
    assert payment.capture_delay == "8 hours"
    assert payment.capture_before == "2026-06-19T10:00:00+00:00"
    assert payment.application_fee == body["applicationFee"]
    assert payment.routing == body["routing"]
    assert payment.lines == body["lines"]
    assert payment.billing_address == body["billingAddress"]
    assert payment.shipping_address == body["shippingAddress"]
    assert payment.restrict_payment_methods_to_country == "NL"

    assert %Link{href: "https://www.mollie.com/checkout/select-method/tr_rich_123"} =
             payment.links["checkout"]

    assert payment.raw["unexpectedFutureField"] == %{"visible" => true}

    assert payment.raw["metadata"] == %{
             "order_id" => "12345",
             "nested_meta" => %{"line_id" => "1"}
           }
  end

  test "status helpers are nil-safe and match exact payment states" do
    assert Payment.open?(payment(status: "open"))
    assert Payment.pending?(payment(status: "pending"))
    assert Payment.authorized?(payment(status: "authorized"))
    assert Payment.canceled?(payment(status: "canceled"))
    assert Payment.expired?(payment(status: "expired"))
    assert Payment.failed?(payment(status: "failed"))

    refute Payment.open?(payment(status: "paid"))
    refute Payment.pending?(nil)
    refute Payment.authorized?(%{})
  end

  test "paid helper follows paid_at rather than status alone" do
    assert Payment.paid?(payment(status: "open", paid_at: "2026-06-12T10:02:00+00:00"))

    refute Payment.paid?(payment(status: "paid", paid_at: nil))
    refute Payment.paid?(payment(status: "paid", paid_at: ""))
    refute Payment.paid?(nil)
  end

  test "refundability and sequence helpers use decoded fields" do
    refundable = payment(amount_remaining: money("EUR", "10.00"), sequence_type: "first")
    recurring = payment(sequence_type: "recurring")

    assert Payment.refundable?(refundable)
    assert Payment.partially_refundable?(refundable)
    assert Payment.sequence_type_first?(refundable)
    assert Payment.sequence_type_recurring?(recurring)

    refute Payment.refundable?(payment(amount_remaining: nil))
    refute Payment.partially_refundable?(nil)
    refute Payment.sequence_type_first?(recurring)
    refute Payment.sequence_type_recurring?(refundable)
  end

  test "link helpers return hrefs when present" do
    payment =
      payment(
        links: %{
          "checkout" => %Link{href: "https://checkout.example.org", type: "text/html"},
          "mobileAppCheckout" => %Link{href: "mollie://checkout/tr_123", type: "text/html"},
          "refunds" => %Link{href: "https://api.example.org/refunds"},
          "chargebacks" => %{"href" => "https://api.example.org/chargebacks"}
        }
      )

    assert Payment.checkout_url(payment) == "https://checkout.example.org"
    assert Payment.mobile_app_checkout_url(payment) == "mollie://checkout/tr_123"
    assert Payment.has_refunds?(payment)
    assert Payment.has_chargebacks?(payment)

    assert Payment.checkout_url(payment(links: %{})) == nil
    assert Payment.mobile_app_checkout_url(nil) == nil
    refute Payment.has_refunds?(payment(links: %{"refunds" => %Link{href: nil}}))
    refute Payment.has_chargebacks?(%{})
  end

  defp rich_payment_fixture do
    @rich_payment_fixture
    |> File.read!()
    |> Jason.decode!()
  end

  defp response(body) do
    %Response{
      status: 200,
      headers: %{},
      body: body,
      raw: body
    }
  end

  defp payment(attrs) do
    attrs
    |> Enum.into(%{id: "tr_123", raw: %{}})
    |> then(&struct!(Payment, &1))
  end

  defp money(currency, value) do
    %Money{
      currency: currency,
      value: value,
      raw: %{"currency" => currency, "value" => value}
    }
  end
end
