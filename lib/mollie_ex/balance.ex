defmodule MollieEx.Balance do
  @moduledoc """
  Balance resource returned by the Mollie API.

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
          created_at: String.t() | nil,
          currency: String.t() | nil,
          description: String.t() | nil,
          status: String.t() | nil,
          transfer_frequency: String.t() | nil,
          transfer_threshold: Money.t() | nil,
          transfer_reference: String.t() | nil,
          transfer_destination: map() | nil,
          available_amount: Money.t() | nil,
          pending_amount: Money.t() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  defstruct [
    :id,
    :resource,
    :mode,
    :created_at,
    :currency,
    :description,
    :status,
    :transfer_frequency,
    :transfer_threshold,
    :transfer_reference,
    :transfer_destination,
    :available_amount,
    :pending_amount,
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
           created_at: Map.get(body, "createdAt"),
           currency: Map.get(body, "currency"),
           description: Map.get(body, "description"),
           status: Map.get(body, "status"),
           transfer_frequency: Map.get(body, "transferFrequency"),
           transfer_threshold: Money.from(Map.get(body, "transferThreshold")),
           transfer_reference: Map.get(body, "transferReference"),
           transfer_destination: Map.get(body, "transferDestination"),
           available_amount: Money.from(Map.get(body, "availableAmount")),
           pending_amount: Money.from(Map.get(body, "pendingAmount")),
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
       reason: :invalid_balance_response,
       operation: operation
     )}
  end
end
