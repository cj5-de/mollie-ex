defmodule MollieEx.SettlementTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Settlement
  alias MollieEx.Types.{Link, Money}

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "settlement",
      "id" => "stl_jDk30akdN",
      "createdAt" => "2024-04-05T08:30:00.0Z",
      "reference" => "1234567.2404.03",
      "settledAt" => "2024-04-06T09:41:44.0Z",
      "status" => "paidout",
      "amount" => %{"currency" => "EUR", "value" => "39.75"},
      "balanceId" => "bal_3kUf4yU2nT",
      "invoiceId" => "inv_FrvewDA3Pr",
      "periods" => %{
        "2024" => %{
          "04" => %{
            "revenue" => [
              %{
                "description" => "iDEAL",
                "method" => "ideal",
                "count" => 6,
                "amountNet" => %{"currency" => "EUR", "value" => "86.1000"}
              }
            ],
            "invoiceId" => "inv_FrvewDA3Pr"
          }
        }
      },
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/settlements/stl_jDk30akdN",
          "type" => "application/hal+json"
        },
        "invoice" => nil
      },
      "futureField" => true
    }

    assert {:ok, %Settlement{} = settlement} =
             Settlement.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :settlements_get
             )

    assert settlement.id == "stl_jDk30akdN"
    assert settlement.resource == "settlement"
    assert settlement.created_at == "2024-04-05T08:30:00.0Z"
    assert settlement.reference == "1234567.2404.03"
    assert settlement.settled_at == "2024-04-06T09:41:44.0Z"
    assert settlement.status == "paidout"
    assert settlement.balance_id == "bal_3kUf4yU2nT"
    assert settlement.invoice_id == "inv_FrvewDA3Pr"
    assert settlement.periods["2024"]["04"]["invoiceId"] == "inv_FrvewDA3Pr"

    assert %Money{value: "39.75", currency: "EUR"} = settlement.amount

    assert %Link{href: "https://api.mollie.com/v2/settlements/stl_jDk30akdN"} =
             settlement.links["self"]

    assert settlement.links["invoice"] == nil
    assert settlement.raw["futureField"] == true
  end

  test "exposes pure status helpers" do
    assert Settlement.open?(%Settlement{id: "stl_open", status: "open", raw: %{}})
    assert Settlement.pending?(%Settlement{id: "stl_pending", status: "pending", raw: %{}})

    assert Settlement.processing_at_bank?(%Settlement{
             id: "stl_processing",
             status: "processing-at-bank",
             raw: %{}
           })

    assert Settlement.paid_out?(%Settlement{id: "stl_paid", status: "paidout", raw: %{}})
    assert Settlement.failed?(%Settlement{id: "stl_failed", status: "failed", raw: %{}})

    refute Settlement.open?(%Settlement{id: "stl_paid", status: "paidout", raw: %{}})
    refute Settlement.failed?(:not_a_settlement)
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{
      status: 200,
      headers: %{},
      body: %{"resource" => "settlement"},
      raw: %{}
    }

    assert {:error, %Error{type: :decode, reason: :invalid_settlement_response}} =
             Settlement.from_response(response, :settlements_get)
  end
end
