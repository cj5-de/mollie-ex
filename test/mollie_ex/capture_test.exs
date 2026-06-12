defmodule MollieEx.CaptureTest do
  use ExUnit.Case, async: true

  alias MollieEx.Capture
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.{Link, Money}

  @capture_fixture Path.expand("../fixtures/mollie/captures/create_success.json", __DIR__)

  test "decodes stable capture response fields and preserves raw payloads" do
    body = capture_fixture()

    assert {:ok, %Capture{} = capture} =
             body
             |> response()
             |> Capture.from_response(:captures_get)

    assert capture.id == "cpt_123"
    assert capture.resource == "capture"
    assert capture.mode == "test"
    assert capture.created_at == "2026-06-12T11:20:00+00:00"
    assert capture.description == "Capture order #123"
    assert capture.amount == money("EUR", "10.00")
    assert capture.settlement_amount == money("EUR", "9.75")
    assert capture.metadata == %{"order_id" => "123", "nested_meta" => %{"line_id" => "1"}}
    assert capture.payment_id == "tr_123"
    assert capture.shipment_id == "shp_123"
    assert capture.settlement_id == "stl_123"
    assert capture.status == "pending"

    assert %Link{href: "https://api.mollie.com/v2/payments/tr_123/captures/cpt_123"} =
             capture.links["self"]

    assert capture.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "status helpers are nil-safe and match exact capture states" do
    assert Capture.pending?(capture(status: "pending"))
    assert Capture.succeeded?(capture(status: "succeeded"))
    assert Capture.failed?(capture(status: "failed"))

    refute Capture.pending?(capture(status: "succeeded"))
    refute Capture.succeeded?(nil)
    refute Capture.failed?(%{})
  end

  defp capture_fixture do
    @capture_fixture
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

  defp capture(attrs) do
    attrs
    |> Enum.into(%{id: "cpt_123", raw: %{}})
    |> then(&struct!(Capture, &1))
  end

  defp money(currency, value) do
    %Money{
      currency: currency,
      value: value,
      raw: %{"currency" => currency, "value" => value}
    }
  end
end
