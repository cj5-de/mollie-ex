defmodule MollieEx.BalanceReport do
  @moduledoc """
  Balance report resource returned by the Mollie API.

  Stable top-level fields are exposed as snake_case struct fields. The nested
  report totals and original decoded Mollie response are preserved with upstream
  JSON casing unchanged.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.Link

  @type links :: %{optional(String.t()) => Link.t() | term()}

  @type t :: %__MODULE__{
          resource: String.t() | nil,
          balance_id: String.t(),
          time_zone: String.t() | nil,
          from: String.t() | nil,
          until: String.t() | nil,
          grouping: String.t() | nil,
          totals: map() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:balance_id, :raw]
  defstruct [
    :resource,
    :balance_id,
    :time_zone,
    :from,
    :until,
    :grouping,
    :totals,
    links: %{},
    raw: %{}
  ]

  @doc false
  @spec from_response(Response.t(), atom()) :: {:ok, t()} | {:error, Error.t()}
  def from_response(%Response{body: %{} = body} = response, operation) do
    case Map.get(body, "balanceId") do
      balance_id when is_binary(balance_id) and balance_id != "" ->
        {:ok,
         %__MODULE__{
           resource: Map.get(body, "resource"),
           balance_id: balance_id,
           time_zone: Map.get(body, "timeZone"),
           from: Map.get(body, "from"),
           until: Map.get(body, "until"),
           grouping: Map.get(body, "grouping"),
           totals: Map.get(body, "totals"),
           links: links(Map.get(body, "_links")),
           raw: body
         }}

      _balance_id ->
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
       reason: :invalid_balance_report_response,
       operation: operation
     )}
  end
end
