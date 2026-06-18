defmodule MollieEx.BalanceTransfer do
  @moduledoc """
  Connect balance transfer resource returned by the Mollie API.

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
          amount: Money.t() | nil,
          source: map() | nil,
          destination: map() | nil,
          description: String.t() | nil,
          status: String.t() | nil,
          status_reason: map() | nil,
          category: String.t() | nil,
          metadata: term(),
          executed_at: String.t() | nil,
          created_at: String.t() | nil,
          mode: String.t() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  defstruct [
    :id,
    :resource,
    :amount,
    :source,
    :destination,
    :description,
    :status,
    :status_reason,
    :category,
    :metadata,
    :executed_at,
    :created_at,
    :mode,
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
           source: Map.get(body, "source"),
           destination: Map.get(body, "destination"),
           description: Map.get(body, "description"),
           status: Map.get(body, "status"),
           status_reason: Map.get(body, "statusReason"),
           category: Map.get(body, "category"),
           metadata: Map.get(body, "metadata"),
           executed_at: Map.get(body, "executedAt"),
           created_at: Map.get(body, "createdAt"),
           mode: Map.get(body, "mode"),
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
       reason: :invalid_balance_transfer_response,
       operation: operation
     )}
  end
end
