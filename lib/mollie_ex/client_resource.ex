defmodule MollieEx.ClientResource do
  @moduledoc """
  Client resource returned by the Mollie Clients API.

  Stable fields are exposed as snake_case struct fields. The original decoded
  Mollie response is preserved in `raw` with upstream JSON casing unchanged.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.Link

  @type links :: %{optional(String.t()) => Link.t() | term()}

  @type t :: %__MODULE__{
          id: String.t(),
          resource: String.t() | nil,
          organization_created_at: String.t() | nil,
          commission: map() | nil,
          embedded: map() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  defstruct [
    :id,
    :resource,
    :organization_created_at,
    :commission,
    :embedded,
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
           organization_created_at: Map.get(body, "organizationCreatedAt"),
           commission: Map.get(body, "commission"),
           embedded: Map.get(body, "_embedded"),
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
       reason: :invalid_client_response,
       operation: operation
     )}
  end
end
