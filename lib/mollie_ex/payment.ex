defmodule MollieEx.Payment do
  @moduledoc """
  Payment resource returned by the Mollie API.

  Stable fields are exposed as snake_case struct fields. The original decoded
  Mollie response is preserved in `raw` with upstream JSON casing unchanged.
  """

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.{Link, Money}

  @type t :: %__MODULE__{
          id: String.t(),
          resource: String.t() | nil,
          mode: String.t() | nil,
          created_at: String.t() | nil,
          status: String.t() | nil,
          is_cancelable: boolean() | nil,
          amount: Money.t() | nil,
          description: String.t() | nil,
          method: String.t() | nil,
          metadata: term(),
          profile_id: String.t() | nil,
          sequence_type: String.t() | nil,
          links: %{optional(String.t()) => Link.t() | term()},
          raw: map()
        }

  @enforce_keys [:id, :raw]
  defstruct [
    :id,
    :resource,
    :mode,
    :created_at,
    :status,
    :is_cancelable,
    :amount,
    :description,
    :method,
    :metadata,
    :profile_id,
    :sequence_type,
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
           status: Map.get(body, "status"),
           is_cancelable: Map.get(body, "isCancelable"),
           amount: Money.from(Map.get(body, "amount")),
           description: Map.get(body, "description"),
           method: Map.get(body, "method"),
           metadata: Map.get(body, "metadata"),
           profile_id: Map.get(body, "profileId"),
           sequence_type: Map.get(body, "sequenceType"),
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
       reason: :invalid_payment_response,
       operation: operation
     )}
  end
end
