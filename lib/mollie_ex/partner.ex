defmodule MollieEx.Partner do
  @moduledoc """
  Partner status returned by the Mollie Organizations API.

  Stable fields are exposed as snake_case struct fields. The original decoded
  Mollie response is preserved in `raw` with upstream JSON casing unchanged.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.Link

  @type links :: %{optional(String.t()) => Link.t() | term()}

  @type t :: %__MODULE__{
          resource: String.t(),
          partner_type: String.t() | nil,
          is_commission_partner: boolean() | nil,
          user_agent_tokens: [map()] | nil,
          partner_contract_signed_at: String.t() | nil,
          partner_contract_update_available: boolean() | nil,
          partner_contract_expires_at: String.t() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:resource, :raw]
  defstruct [
    :resource,
    :partner_type,
    :is_commission_partner,
    :user_agent_tokens,
    :partner_contract_signed_at,
    :partner_contract_update_available,
    :partner_contract_expires_at,
    links: %{},
    raw: %{}
  ]

  @doc false
  @spec from_response(Response.t(), atom()) :: {:ok, t()} | {:error, Error.t()}
  def from_response(%Response{body: %{"resource" => "partner"} = body}, _operation) do
    {:ok,
     %__MODULE__{
       resource: "partner",
       partner_type: Map.get(body, "partnerType"),
       is_commission_partner: Map.get(body, "isCommissionPartner"),
       user_agent_tokens: Map.get(body, "userAgentTokens"),
       partner_contract_signed_at: Map.get(body, "partnerContractSignedAt"),
       partner_contract_update_available: Map.get(body, "partnerContractUpdateAvailable"),
       partner_contract_expires_at: Map.get(body, "partnerContractExpiresAt"),
       links: links(Map.get(body, "_links")),
       raw: body
     }}
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
       reason: :invalid_partner_response,
       operation: operation
     )}
  end
end
