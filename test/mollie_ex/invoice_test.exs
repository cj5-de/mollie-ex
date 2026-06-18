defmodule MollieEx.InvoiceTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Invoice
  alias MollieEx.Types.{Link, Money}

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "invoice",
      "id" => "inv_FrvewDA3Pr",
      "reference" => "2024.10000",
      "vatNumber" => "NL123456789B01",
      "status" => "paid",
      "netAmount" => %{"currency" => "EUR", "value" => "80.00"},
      "vatAmount" => %{"currency" => "EUR", "value" => "16.80"},
      "grossAmount" => %{"currency" => "EUR", "value" => "96.80"},
      "lines" => [
        %{
          "period" => "2024-01",
          "description" => "Payments",
          "count" => 10,
          "vatPercentage" => 21,
          "amount" => %{"currency" => "EUR", "value" => "80.00"}
        }
      ],
      "issuedAt" => "2024-01-31",
      "paidAt" => "2024-02-14",
      "dueAt" => "2024-02-14",
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/invoices/inv_FrvewDA3Pr",
          "type" => "application/hal+json"
        },
        "pdf" => nil
      },
      "futureField" => true
    }

    assert {:ok, %Invoice{} = invoice} =
             Invoice.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :invoices_get
             )

    assert invoice.id == "inv_FrvewDA3Pr"
    assert invoice.resource == "invoice"
    assert invoice.reference == "2024.10000"
    assert invoice.vat_number == "NL123456789B01"
    assert invoice.status == "paid"
    assert invoice.issued_at == "2024-01-31"
    assert invoice.paid_at == "2024-02-14"
    assert invoice.due_at == "2024-02-14"

    assert %Money{value: "80.00", currency: "EUR"} = invoice.net_amount
    assert %Money{value: "16.80", currency: "EUR"} = invoice.vat_amount
    assert %Money{value: "96.80", currency: "EUR"} = invoice.gross_amount

    assert [line] = invoice.lines
    assert line["period"] == "2024-01"
    assert line["amount"]["value"] == "80.00"

    assert %Link{href: "https://api.mollie.com/v2/invoices/inv_FrvewDA3Pr"} =
             invoice.links["self"]

    assert invoice.links["pdf"] == nil
    assert invoice.raw["futureField"] == true
  end

  test "exposes pure status helpers" do
    assert Invoice.open?(%Invoice{id: "inv_open", status: "open", raw: %{}})
    assert Invoice.paid?(%Invoice{id: "inv_paid", status: "paid", raw: %{}})
    assert Invoice.overdue?(%Invoice{id: "inv_overdue", status: "overdue", raw: %{}})

    refute Invoice.open?(%Invoice{id: "inv_paid", status: "paid", raw: %{}})
    refute Invoice.overdue?(:not_an_invoice)
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{
      status: 200,
      headers: %{},
      body: %{"resource" => "invoice"},
      raw: %{}
    }

    assert {:error, %Error{type: :decode, reason: :invalid_invoice_response}} =
             Invoice.from_response(response, :invoices_get)
  end
end
