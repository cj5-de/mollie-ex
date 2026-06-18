defmodule MollieEx.BalanceTransactionTest do
  use ExUnit.Case, async: true

  alias MollieEx.BalanceTransaction
  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.Money

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "balance_transaction",
      "id" => "baltr_QM24QwzUWR4ev4Xfgyt29d",
      "type" => "refund",
      "createdAt" => "2024-03-01T12:15:30+00:00",
      "resultAmount" => %{"currency" => "EUR", "value" => "-10.25"},
      "initialAmount" => %{"currency" => "EUR", "value" => "-10.00"},
      "deductions" => %{"currency" => "EUR", "value" => "-0.25"},
      "deductionDetails" => %{
        "fees" => %{"currency" => "EUR", "value" => "-0.25"}
      },
      "context" => %{
        "refund" => %{
          "paymentId" => "tr_7UhSN1zuXS",
          "refundId" => "re_4qqhO89gsT"
        }
      },
      "futureField" => true
    }

    assert {:ok, %BalanceTransaction{} = transaction} =
             BalanceTransaction.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :balances_list_transactions
             )

    assert transaction.id == "baltr_QM24QwzUWR4ev4Xfgyt29d"
    assert transaction.resource == "balance_transaction"
    assert transaction.type == "refund"
    assert transaction.created_at == "2024-03-01T12:15:30+00:00"

    assert %Money{currency: "EUR", value: "-10.25"} = transaction.result_amount
    assert %Money{currency: "EUR", value: "-10.00"} = transaction.initial_amount
    assert %Money{currency: "EUR", value: "-0.25"} = transaction.deductions

    assert transaction.deduction_details["fees"]["value"] == "-0.25"
    assert transaction.context["refund"]["paymentId"] == "tr_7UhSN1zuXS"
    assert transaction.raw["futureField"] == true
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{
      status: 200,
      headers: %{},
      body: %{"resource" => "balance_transaction"},
      raw: %{}
    }

    assert {:error, %Error{type: :decode, reason: :invalid_balance_transaction_response}} =
             BalanceTransaction.from_response(response, :balances_list_transactions)
  end
end
