defmodule MollieEx.BalanceTest do
  use ExUnit.Case, async: true

  alias MollieEx.Balance
  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.{Link, Money}

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "balance",
      "id" => "bal_gVMhHKqSSRYJyPsuoPNFH",
      "mode" => "live",
      "createdAt" => "2024-01-10T12:06:28+00:00",
      "currency" => "EUR",
      "description" => "Primary EUR balance",
      "status" => "active",
      "transferFrequency" => "daily",
      "transferThreshold" => %{"value" => "40.00", "currency" => "EUR"},
      "transferReference" => "Mollie payout",
      "transferDestination" => %{
        "type" => "bank-account",
        "beneficiaryName" => "Jane Merchant",
        "bankAccount" => "NL53INGB0654422370"
      },
      "availableAmount" => %{"value" => "100.00", "currency" => "EUR"},
      "pendingAmount" => %{"value" => "15.00", "currency" => "EUR"},
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/balances/bal_gVMhHKqSSRYJyPsuoPNFH",
          "type" => "application/hal+json"
        }
      },
      "futureField" => true
    }

    assert {:ok, %Balance{} = balance} =
             Balance.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :balances_get
             )

    assert balance.id == "bal_gVMhHKqSSRYJyPsuoPNFH"
    assert balance.resource == "balance"
    assert balance.mode == "live"
    assert balance.created_at == "2024-01-10T12:06:28+00:00"
    assert balance.currency == "EUR"
    assert balance.description == "Primary EUR balance"
    assert balance.status == "active"
    assert balance.transfer_frequency == "daily"
    assert balance.transfer_reference == "Mollie payout"
    assert balance.transfer_destination["beneficiaryName"] == "Jane Merchant"

    assert %Money{value: "40.00", currency: "EUR"} = balance.transfer_threshold
    assert %Money{value: "100.00", currency: "EUR"} = balance.available_amount
    assert %Money{value: "15.00", currency: "EUR"} = balance.pending_amount

    assert %Link{href: "https://api.mollie.com/v2/balances/bal_gVMhHKqSSRYJyPsuoPNFH"} =
             balance.links["self"]

    assert balance.raw["futureField"] == true
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{
      status: 200,
      headers: %{},
      body: %{"resource" => "balance"},
      raw: %{}
    }

    assert {:error, %Error{type: :decode, reason: :invalid_balance_response}} =
             Balance.from_response(response, :balances_get)
  end
end
