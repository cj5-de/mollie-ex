defmodule MollieEx.BalanceReportTest do
  use ExUnit.Case, async: true

  alias MollieEx.BalanceReport
  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.Link

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "balance-report",
      "balanceId" => "bal_gVMhHKqSSRYJyPsuoPNFH",
      "timeZone" => "Europe/Amsterdam",
      "from" => "2024-01-01",
      "until" => "2024-02-01",
      "grouping" => "transaction-categories",
      "totals" => %{
        "payments" => %{
          "pending" => %{
            "amount" => %{"currency" => "EUR", "value" => "4.98"}
          }
        }
      },
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/balances/bal_123/report",
          "type" => "application/hal+json"
        }
      },
      "futureField" => true
    }

    assert {:ok, %BalanceReport{} = report} =
             BalanceReport.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :balances_get_report
             )

    assert report.resource == "balance-report"
    assert report.balance_id == "bal_gVMhHKqSSRYJyPsuoPNFH"
    assert report.time_zone == "Europe/Amsterdam"
    assert report.from == "2024-01-01"
    assert report.until == "2024-02-01"
    assert report.grouping == "transaction-categories"
    assert report.totals["payments"]["pending"]["amount"]["value"] == "4.98"

    assert %Link{href: "https://api.mollie.com/v2/balances/bal_123/report"} =
             report.links["self"]

    assert report.raw["futureField"] == true
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{
      status: 200,
      headers: %{},
      body: %{"resource" => "balance-report"},
      raw: %{}
    }

    assert {:error, %Error{type: :decode, reason: :invalid_balance_report_response}} =
             BalanceReport.from_response(response, :balances_get_report)
  end
end
