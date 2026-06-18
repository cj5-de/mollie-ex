defmodule MollieEx.Invoice do
  @moduledoc """
  Invoice resource returned by the Mollie API.

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
          reference: String.t() | nil,
          vat_number: String.t() | nil,
          status: String.t() | nil,
          issued_at: String.t() | nil,
          paid_at: String.t() | nil,
          due_at: String.t() | nil,
          net_amount: Money.t() | nil,
          vat_amount: Money.t() | nil,
          gross_amount: Money.t() | nil,
          lines: list(term()),
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  defstruct [
    :id,
    :resource,
    :reference,
    :vat_number,
    :status,
    :issued_at,
    :paid_at,
    :due_at,
    :net_amount,
    :vat_amount,
    :gross_amount,
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
           reference: Map.get(body, "reference"),
           vat_number: Map.get(body, "vatNumber"),
           status: Map.get(body, "status"),
           issued_at: Map.get(body, "issuedAt"),
           paid_at: Map.get(body, "paidAt"),
           due_at: Map.get(body, "dueAt"),
           net_amount: Money.from(Map.get(body, "netAmount")),
           vat_amount: Money.from(Map.get(body, "vatAmount")),
           gross_amount: Money.from(Map.get(body, "grossAmount")),
           lines: Map.get(body, "lines", []),
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
  Returns true when the invoice status is `open`.
  """
  @doc since: "0.5.0"
  @spec open?(t() | term()) :: boolean()
  def open?(invoice), do: status?(invoice, "open")

  @doc """
  Returns true when the invoice status is `paid`.
  """
  @doc since: "0.5.0"
  @spec paid?(t() | term()) :: boolean()
  def paid?(invoice), do: status?(invoice, "paid")

  @doc """
  Returns true when the invoice status is `overdue`.
  """
  @doc since: "0.5.0"
  @spec overdue?(t() | term()) :: boolean()
  def overdue?(invoice), do: status?(invoice, "overdue")

  defp status?(%__MODULE__{status: status}, expected), do: status == expected
  defp status?(_invoice, _expected), do: false

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
       reason: :invalid_invoice_response,
       operation: operation
     )}
  end
end
