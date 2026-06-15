defmodule MollieEx.Organization do
  @moduledoc """
  Organization resource returned by the Mollie API.

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
          name: String.t() | nil,
          email: String.t() | nil,
          locale: String.t() | nil,
          address: map() | nil,
          registration_number: String.t() | nil,
          vat_number: String.t() | nil,
          vat_regulation: String.t() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  defstruct [
    :id,
    :resource,
    :name,
    :email,
    :locale,
    :address,
    :registration_number,
    :vat_number,
    :vat_regulation,
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
           name: Map.get(body, "name"),
           email: Map.get(body, "email"),
           locale: Map.get(body, "locale"),
           address: Map.get(body, "address"),
           registration_number: Map.get(body, "registrationNumber"),
           vat_number: Map.get(body, "vatNumber"),
           vat_regulation: Map.get(body, "vatRegulation"),
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
       reason: :invalid_organization_response,
       operation: operation
     )}
  end
end
