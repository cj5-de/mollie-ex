defmodule MollieEx.Mandate do
  @moduledoc """
  Mandate resource returned by the Mollie API.

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
          status: String.t() | nil,
          method: String.t() | nil,
          details: map() | nil,
          mandate_reference: String.t() | nil,
          signature_date: String.t() | nil,
          scopes: [String.t()] | nil,
          customer_id: String.t() | nil,
          created_at: String.t() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  defstruct [
    :id,
    :resource,
    :mode,
    :status,
    :method,
    :details,
    :mandate_reference,
    :signature_date,
    :scopes,
    :customer_id,
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
           status: Map.get(body, "status"),
           method: Map.get(body, "method"),
           details: Map.get(body, "details"),
           mandate_reference: Map.get(body, "mandateReference"),
           signature_date: Map.get(body, "signatureDate"),
           scopes: Map.get(body, "scopes"),
           customer_id: Map.get(body, "customerId"),
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
       reason: :invalid_mandate_response,
       operation: operation
     )}
  end
end
