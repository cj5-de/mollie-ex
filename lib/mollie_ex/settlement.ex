defmodule MollieEx.Settlement do
  @moduledoc """
  Settlement resource returned by the Mollie API.

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
          created_at: String.t() | nil,
          settled_at: String.t() | nil,
          status: String.t() | nil,
          amount: Money.t() | nil,
          balance_id: String.t() | nil,
          invoice_id: String.t() | nil,
          periods: term(),
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  defstruct [
    :id,
    :resource,
    :reference,
    :created_at,
    :settled_at,
    :status,
    :amount,
    :balance_id,
    :invoice_id,
    :periods,
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
           created_at: Map.get(body, "createdAt"),
           settled_at: Map.get(body, "settledAt"),
           status: Map.get(body, "status"),
           amount: Money.from(Map.get(body, "amount")),
           balance_id: Map.get(body, "balanceId"),
           invoice_id: Map.get(body, "invoiceId"),
           periods: Map.get(body, "periods"),
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
  Returns true when the settlement status is `open`.
  """
  @doc since: "0.5.0"
  @spec open?(t() | term()) :: boolean()
  def open?(settlement), do: status?(settlement, "open")

  @doc """
  Returns true when the settlement status is `pending`.
  """
  @doc since: "0.5.0"
  @spec pending?(t() | term()) :: boolean()
  def pending?(settlement), do: status?(settlement, "pending")

  @doc """
  Returns true when the settlement status is `processing-at-bank`.
  """
  @doc since: "0.5.0"
  @spec processing_at_bank?(t() | term()) :: boolean()
  def processing_at_bank?(settlement), do: status?(settlement, "processing-at-bank")

  @doc """
  Returns true when the settlement status is `paidout`.
  """
  @doc since: "0.5.0"
  @spec paid_out?(t() | term()) :: boolean()
  def paid_out?(settlement), do: status?(settlement, "paidout")

  @doc """
  Returns true when the settlement status is `failed`.
  """
  @doc since: "0.5.0"
  @spec failed?(t() | term()) :: boolean()
  def failed?(settlement), do: status?(settlement, "failed")

  defp status?(%__MODULE__{status: status}, expected), do: status == expected
  defp status?(_settlement, _expected), do: false

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
       reason: :invalid_settlement_response,
       operation: operation
     )}
  end
end
