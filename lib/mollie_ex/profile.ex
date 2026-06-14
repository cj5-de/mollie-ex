defmodule MollieEx.Profile do
  @moduledoc """
  Profile resource returned by the Mollie API.

  Stable fields are exposed as snake_case struct fields. The original decoded
  Mollie response is preserved in `raw` with upstream JSON casing unchanged.
  """
  @moduledoc since: "0.4.0"

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.Link

  @type links :: %{optional(String.t()) => Link.t() | term()}

  @type t :: %__MODULE__{
          id: String.t(),
          resource: String.t() | nil,
          mode: String.t() | nil,
          name: String.t() | nil,
          website: String.t() | nil,
          email: String.t() | nil,
          phone: String.t() | nil,
          description: String.t() | nil,
          countries_of_activity: [String.t()] | nil,
          business_category: String.t() | nil,
          status: String.t() | nil,
          review: map() | nil,
          created_at: String.t() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  defstruct [
    :id,
    :resource,
    :mode,
    :name,
    :website,
    :email,
    :phone,
    :description,
    :countries_of_activity,
    :business_category,
    :status,
    :review,
    :created_at,
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
           name: Map.get(body, "name"),
           website: Map.get(body, "website"),
           email: Map.get(body, "email"),
           phone: Map.get(body, "phone"),
           description: Map.get(body, "description"),
           countries_of_activity: Map.get(body, "countriesOfActivity"),
           business_category: Map.get(body, "businessCategory"),
           status: Map.get(body, "status"),
           review: Map.get(body, "review"),
           created_at: Map.get(body, "createdAt"),
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
       reason: :invalid_profile_response,
       operation: operation
     )}
  end
end
