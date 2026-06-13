defmodule MollieEx.Chargeback do
  @moduledoc """
  Chargeback resource returned by the Mollie API.

  Stable fields are exposed as snake_case struct fields. The original decoded
  Mollie response is preserved in `raw` with upstream JSON casing unchanged.
  """
  @moduledoc since: "0.1.0"

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.{Link, Money}

  @type links :: %{optional(String.t()) => Link.t() | term()}
  @type reason :: %{optional(String.t()) => term()} | nil

  @type t :: %__MODULE__{
          id: String.t(),
          resource: String.t() | nil,
          amount: Money.t() | nil,
          settlement_amount: Money.t() | nil,
          reason: reason(),
          payment_id: String.t() | nil,
          settlement_id: String.t() | nil,
          created_at: String.t() | nil,
          reversed_at: String.t() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  defstruct [
    :id,
    :resource,
    :amount,
    :settlement_amount,
    :reason,
    :payment_id,
    :settlement_id,
    :created_at,
    :reversed_at,
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
           amount: Money.from(Map.get(body, "amount")),
           settlement_amount: Money.from(Map.get(body, "settlementAmount")),
           reason: Map.get(body, "reason"),
           payment_id: Map.get(body, "paymentId"),
           settlement_id: Map.get(body, "settlementId"),
           created_at: Map.get(body, "createdAt"),
           reversed_at: Map.get(body, "reversedAt"),
           links: links(Map.get(body, "_links")),
           raw: body
         }}

      _id ->
        invalid_response_error(operation, response)
    end
  end

  def from_response(%Response{} = response, operation),
    do: invalid_response_error(operation, response)

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
       reason: :invalid_chargeback_response,
       operation: operation
     )}
  end
end
