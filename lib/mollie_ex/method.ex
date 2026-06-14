defmodule MollieEx.Method do
  @moduledoc """
  Payment method resource returned by the Mollie API.

  Stable fields are exposed as snake_case struct fields. The original decoded
  Mollie response is preserved in `raw` with upstream JSON casing unchanged.
  """
  @moduledoc since: "0.4.0"

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.{Link, Money}

  @type links :: %{optional(String.t()) => Link.t() | term()}

  @type t :: %__MODULE__{
          id: String.t(),
          resource: String.t() | nil,
          description: String.t() | nil,
          minimum_amount: Money.t() | nil,
          maximum_amount: Money.t() | nil,
          image: map() | nil,
          status: String.t() | nil,
          issuers: [map()] | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  defstruct [
    :id,
    :resource,
    :description,
    :minimum_amount,
    :maximum_amount,
    :image,
    :status,
    :issuers,
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
           description: Map.get(body, "description"),
           minimum_amount: Money.from(Map.get(body, "minimumAmount")),
           maximum_amount: Money.from(Map.get(body, "maximumAmount")),
           image: Map.get(body, "image"),
           status: Map.get(body, "status"),
           issuers: Map.get(body, "issuers"),
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
       reason: :invalid_method_response,
       operation: operation
     )}
  end
end
