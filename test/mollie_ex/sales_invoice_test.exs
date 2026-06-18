defmodule MollieEx.SalesInvoiceTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.SalesInvoice
  alias MollieEx.Types.{Link, Money}

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "sales-invoice",
      "id" => "invoice_4Y0eZitmBnQ6IDoMqZQKh",
      "mode" => "test",
      "profileId" => "pfl_QkEhN94Ba",
      "invoiceNumber" => nil,
      "currency" => "EUR",
      "status" => "draft",
      "vatScheme" => "standard",
      "vatMode" => "exclusive",
      "memo" => "Order #123",
      "paymentTerm" => "30 days",
      "paymentDetails" => [%{"method" => "banktransfer"}],
      "emailDetails" => %{"subject" => "Invoice"},
      "metadata" => %{"order_id" => "123", "nested_meta" => %{"line_id" => "1"}},
      "customerId" => "cst_8wmqcHMN4U",
      "mandateId" => "mdt_h3gAaD5zP",
      "recipientIdentifier" => "recipient-123",
      "recipient" => %{"type" => "consumer", "givenName" => "Given"},
      "lines" => [
        %{
          "description" => "LEGO 4440 Forest Police Station",
          "quantity" => 1,
          "vatRate" => "21",
          "unitPrice" => %{"value" => "89.00", "currency" => "EUR"}
        }
      ],
      "discount" => %{"type" => "percentage", "percentage" => "10"},
      "isEInvoice" => false,
      "amountDue" => %{"value" => "107.69", "currency" => "EUR"},
      "subtotalAmount" => %{"value" => "89.00", "currency" => "EUR"},
      "totalAmount" => %{"value" => "107.69", "currency" => "EUR"},
      "totalVatAmount" => %{"value" => "18.69", "currency" => "EUR"},
      "discountedSubtotalAmount" => %{"value" => "89.00", "currency" => "EUR"},
      "createdAt" => "2024-10-03T10:47:38.457381+00:00",
      "issuedAt" => nil,
      "paidAt" => nil,
      "dueAt" => nil,
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/sales-invoices/invoice_123",
          "type" => "application/hal+json"
        },
        "pdfLink" => nil
      },
      "futureField" => true
    }

    assert {:ok, %SalesInvoice{} = sales_invoice} =
             SalesInvoice.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :sales_invoices_get
             )

    assert sales_invoice.id == "invoice_4Y0eZitmBnQ6IDoMqZQKh"
    assert sales_invoice.resource == "sales-invoice"
    assert sales_invoice.mode == "test"
    assert sales_invoice.profile_id == "pfl_QkEhN94Ba"
    assert sales_invoice.invoice_number == nil
    assert sales_invoice.currency == "EUR"
    assert sales_invoice.status == "draft"
    assert sales_invoice.vat_scheme == "standard"
    assert sales_invoice.vat_mode == "exclusive"
    assert sales_invoice.memo == "Order #123"
    assert sales_invoice.payment_term == "30 days"
    assert sales_invoice.payment_details == [%{"method" => "banktransfer"}]
    assert sales_invoice.email_details == %{"subject" => "Invoice"}
    assert sales_invoice.metadata == %{"order_id" => "123", "nested_meta" => %{"line_id" => "1"}}
    assert sales_invoice.customer_id == "cst_8wmqcHMN4U"
    assert sales_invoice.mandate_id == "mdt_h3gAaD5zP"
    assert sales_invoice.recipient_identifier == "recipient-123"
    assert sales_invoice.recipient["givenName"] == "Given"
    assert sales_invoice.lines |> hd() |> Map.get("vatRate") == "21"
    assert sales_invoice.discount["percentage"] == "10"
    assert sales_invoice.is_e_invoice == false

    assert %Money{value: "107.69", currency: "EUR"} = sales_invoice.amount_due
    assert %Money{value: "89.00", currency: "EUR"} = sales_invoice.subtotal_amount
    assert %Money{value: "107.69", currency: "EUR"} = sales_invoice.total_amount
    assert %Money{value: "18.69", currency: "EUR"} = sales_invoice.total_vat_amount
    assert %Money{value: "89.00", currency: "EUR"} = sales_invoice.discounted_subtotal_amount

    assert sales_invoice.created_at == "2024-10-03T10:47:38.457381+00:00"
    assert sales_invoice.issued_at == nil
    assert sales_invoice.paid_at == nil
    assert sales_invoice.due_at == nil

    assert %Link{href: "https://api.mollie.com/v2/sales-invoices/invoice_123"} =
             sales_invoice.links["self"]

    assert sales_invoice.links["pdfLink"] == nil
    assert sales_invoice.raw["futureField"] == true
  end

  test "exposes pure status helpers" do
    assert SalesInvoice.draft?(%SalesInvoice{id: "invoice_draft", status: "draft", raw: %{}})
    assert SalesInvoice.issued?(%SalesInvoice{id: "invoice_issued", status: "issued", raw: %{}})
    assert SalesInvoice.paid?(%SalesInvoice{id: "invoice_paid", status: "paid", raw: %{}})

    refute SalesInvoice.draft?(%SalesInvoice{id: "invoice_paid", status: "paid", raw: %{}})
    refute SalesInvoice.paid?(:not_a_sales_invoice)
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{
      status: 200,
      headers: %{},
      body: %{"resource" => "sales-invoice"},
      raw: %{}
    }

    assert {:error, %Error{type: :decode, reason: :invalid_sales_invoice_response}} =
             SalesInvoice.from_response(response, :sales_invoices_get)
  end
end
