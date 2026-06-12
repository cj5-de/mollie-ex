defmodule MollieEx.RefundTest do
  use ExUnit.Case, async: true

  alias MollieEx.HTTP.Response
  alias MollieEx.Refund
  alias MollieEx.Types.{Link, Money}

  @refund_fixture Path.expand("../fixtures/mollie/refunds/create_success.json", __DIR__)

  test "decodes stable refund response fields and preserves raw payloads" do
    body = refund_fixture()

    assert {:ok, %Refund{} = refund} =
             body
             |> response()
             |> Refund.from_response(:refunds_get)

    assert refund.id == "re_123"
    assert refund.resource == "refund"
    assert refund.mode == "test"
    assert refund.created_at == "2026-06-12T10:20:00+00:00"
    assert refund.description == "Refund order #123"
    assert refund.amount == money("EUR", "10.00")
    assert refund.settlement_amount == money("EUR", "-10.00")
    assert refund.metadata == %{"order_id" => "123", "nested_meta" => %{"line_id" => "1"}}
    assert refund.payment_id == "tr_123"
    assert refund.order_id == "ord_123"
    assert refund.settlement_id == "stl_123"
    assert refund.status == "pending"
    assert refund.external_reference == body["externalReference"]
    assert refund.routing_reversals == body["routingReversals"]

    assert %Link{href: "https://api.mollie.com/v2/payments/tr_123/refunds/re_123"} =
             refund.links["self"]

    assert refund.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "status helpers are nil-safe and match exact refund states" do
    assert Refund.queued?(refund(status: "queued"))
    assert Refund.pending?(refund(status: "pending"))
    assert Refund.processing?(refund(status: "processing"))
    assert Refund.refunded?(refund(status: "refunded"))
    assert Refund.failed?(refund(status: "failed"))
    assert Refund.canceled?(refund(status: "canceled"))

    refute Refund.queued?(refund(status: "pending"))
    refute Refund.pending?(nil)
    refute Refund.processing?(%{})
  end

  test "cancelable helper follows queued and pending statuses" do
    assert Refund.cancelable?(refund(status: "queued"))
    assert Refund.cancelable?(refund(status: "pending"))

    refute Refund.cancelable?(refund(status: "processing"))
    refute Refund.cancelable?(refund(status: "refunded"))
    refute Refund.cancelable?(nil)
  end

  defp refund_fixture do
    @refund_fixture
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

  defp refund(attrs) do
    attrs
    |> Enum.into(%{id: "re_123", raw: %{}})
    |> then(&struct!(Refund, &1))
  end

  defp money(currency, value) do
    %Money{
      currency: currency,
      value: value,
      raw: %{"currency" => currency, "value" => value}
    }
  end
end
