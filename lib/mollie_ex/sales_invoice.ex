defmodule MollieEx.SalesInvoice do
  @moduledoc """
  Sales invoice resource returned by the Mollie API.

  Stable fields are exposed as snake_case struct fields. The original decoded
  Mollie response is preserved in `raw` with upstream JSON casing unchanged.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.{Link, Money}

  @type links :: %{optional(String.t()) => Link.t() | term()}

  @type t :: %__MODULE__{
          id: String.t(),
          resource: String.t() | nil,
          mode: String.t() | nil,
          profile_id: String.t() | nil,
          invoice_number: String.t() | nil,
          currency: String.t() | nil,
          status: String.t() | nil,
          vat_scheme: String.t() | nil,
          vat_mode: String.t() | nil,
          memo: String.t() | nil,
          payment_term: String.t() | nil,
          payment_details: term(),
          email_details: term(),
          metadata: term(),
          customer_id: String.t() | nil,
          mandate_id: String.t() | nil,
          recipient_identifier: String.t() | nil,
          recipient: term(),
          lines: list(term()),
          discount: term(),
          is_e_invoice: boolean() | nil,
          amount_due: Money.t() | nil,
          subtotal_amount: Money.t() | nil,
          total_amount: Money.t() | nil,
          total_vat_amount: Money.t() | nil,
          discounted_subtotal_amount: Money.t() | nil,
          created_at: String.t() | nil,
          issued_at: String.t() | nil,
          paid_at: String.t() | nil,
          due_at: String.t() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  # The Mollie sales-invoice response exposes a wide documented resource shape.
  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :resource,
    :mode,
    :profile_id,
    :invoice_number,
    :currency,
    :status,
    :vat_scheme,
    :vat_mode,
    :memo,
    :payment_term,
    :payment_details,
    :email_details,
    :metadata,
    :customer_id,
    :mandate_id,
    :recipient_identifier,
    :recipient,
    :discount,
    :is_e_invoice,
    :amount_due,
    :subtotal_amount,
    :total_amount,
    :total_vat_amount,
    :discounted_subtotal_amount,
    :created_at,
    :issued_at,
    :paid_at,
    :due_at,
    lines: [],
    links: %{},
    raw: %{}
  ]

  @doc false
  @spec from_response(Response.t(), atom()) :: {:ok, t()} | {:error, Error.t()}
  def from_response(%Response{body: %{} = body} = response, operation) do
    case Map.get(body, "id") do
      id when is_binary(id) and id != "" ->
        {:ok,
         %__MODULE__{
           id: id,
           resource: Map.get(body, "resource"),
           mode: Map.get(body, "mode"),
           profile_id: Map.get(body, "profileId"),
           invoice_number: Map.get(body, "invoiceNumber"),
           currency: Map.get(body, "currency"),
           status: Map.get(body, "status"),
           vat_scheme: Map.get(body, "vatScheme"),
           vat_mode: Map.get(body, "vatMode"),
           memo: Map.get(body, "memo"),
           payment_term: Map.get(body, "paymentTerm"),
           payment_details: Map.get(body, "paymentDetails"),
           email_details: Map.get(body, "emailDetails"),
           metadata: Map.get(body, "metadata"),
           customer_id: Map.get(body, "customerId"),
           mandate_id: Map.get(body, "mandateId"),
           recipient_identifier: Map.get(body, "recipientIdentifier"),
           recipient: Map.get(body, "recipient"),
           lines: Map.get(body, "lines", []),
           discount: Map.get(body, "discount"),
           is_e_invoice: Map.get(body, "isEInvoice"),
           amount_due: Money.from(Map.get(body, "amountDue")),
           subtotal_amount: Money.from(Map.get(body, "subtotalAmount")),
           total_amount: Money.from(Map.get(body, "totalAmount")),
           total_vat_amount: Money.from(Map.get(body, "totalVatAmount")),
           discounted_subtotal_amount: Money.from(Map.get(body, "discountedSubtotalAmount")),
           created_at: Map.get(body, "createdAt"),
           issued_at: Map.get(body, "issuedAt"),
           paid_at: Map.get(body, "paidAt"),
           due_at: Map.get(body, "dueAt"),
           links: links(Map.get(body, "_links")),
           raw: body
         }}

      _id ->
        invalid_response_error(operation, response)
    end
  end

  def from_response(%Response{} = response, operation),
    do: invalid_response_error(operation, response)

  @doc """
  Returns true when the sales invoice status is `draft`.
  """
  @doc since: "0.5.0"
  @spec draft?(t() | term()) :: boolean()
  def draft?(sales_invoice), do: status?(sales_invoice, "draft")

  @doc """
  Returns true when the sales invoice status is `issued`.
  """
  @doc since: "0.5.0"
  @spec issued?(t() | term()) :: boolean()
  def issued?(sales_invoice), do: status?(sales_invoice, "issued")

  @doc """
  Returns true when the sales invoice status is `paid`.
  """
  @doc since: "0.5.0"
  @spec paid?(t() | term()) :: boolean()
  def paid?(sales_invoice), do: status?(sales_invoice, "paid")

  defp status?(%__MODULE__{status: status}, expected), do: status == expected
  defp status?(_sales_invoice, _expected), do: false

  defp links(%{} = links) do
    Map.new(links, fn {rel, link} -> {rel, Link.from(link)} end)
  end

  defp links(_links), do: %{}

  defp invalid_response_error(operation, %Response{} = response) do
    {:error,
     Error.exception(
       type: :decode,
       status: response.status,
       headers: response.headers,
       raw: response.raw,
       reason: :invalid_sales_invoice_response,
       operation: operation
     )}
  end
end
