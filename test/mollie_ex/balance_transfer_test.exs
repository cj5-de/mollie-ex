defmodule MollieEx.BalanceTransferTest do
  use ExUnit.Case, async: true

  alias MollieEx.BalanceTransfer
  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.{Link, Money}

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "connect-balance-transfer",
      "id" => "cbt_4KgGJJSZpH",
      "amount" => %{"currency" => "EUR", "value" => "100.00"},
      "source" => %{
        "type" => "organization",
        "id" => "org_12345678",
        "description" => "Transfer from Organization A"
      },
      "destination" => %{
        "type" => "organization",
        "id" => "org_87654321",
        "description" => "Transfer to Organization B"
      },
      "description" => "Transfer from balance A to balance B",
      "status" => "created",
      "statusReason" => %{
        "code" => "request_created",
        "message" => "The transfer request has been created."
      },
      "category" => "manual_correction",
      "metadata" => %{"reference" => "transfer-123"},
      "executedAt" => nil,
      "createdAt" => "2023-12-25T10:30:54+00:00",
      "mode" => "test",
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/connect/balance-transfers/cbt_4KgGJJSZpH",
          "type" => "application/hal+json"
        }
      },
      "futureField" => true
    }

    assert {:ok, %BalanceTransfer{} = transfer} =
             BalanceTransfer.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :balance_transfers_get
             )

    assert transfer.id == "cbt_4KgGJJSZpH"
    assert transfer.resource == "connect-balance-transfer"
    assert %Money{currency: "EUR", value: "100.00"} = transfer.amount
    assert transfer.source["id"] == "org_12345678"
    assert transfer.destination["id"] == "org_87654321"
    assert transfer.description == "Transfer from balance A to balance B"
    assert transfer.status == "created"
    assert transfer.status_reason["code"] == "request_created"
    assert transfer.category == "manual_correction"
    assert transfer.metadata["reference"] == "transfer-123"
    assert transfer.executed_at == nil
    assert transfer.created_at == "2023-12-25T10:30:54+00:00"
    assert transfer.mode == "test"

    assert %Link{
             href: "https://api.mollie.com/v2/connect/balance-transfers/cbt_4KgGJJSZpH"
           } = transfer.links["self"]

    assert transfer.raw["futureField"] == true
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{
      status: 200,
      headers: %{},
      body: %{"resource" => "connect-balance-transfer"},
      raw: %{}
    }

    assert {:error, %Error{type: :decode, reason: :invalid_balance_transfer_response}} =
             BalanceTransfer.from_response(response, :balance_transfers_get)
  end
end
