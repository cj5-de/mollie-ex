defmodule MollieEx.Capability do
  @moduledoc """
  Capability resource returned by the Mollie API.

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
          name: String.t(),
          status: String.t() | nil,
          status_reason: String.t() | nil,
          requirements: [map()] | nil,
          organization_id: String.t() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:resource, :name, :raw]
  defstruct [
    :resource,
    :name,
    :status,
    :status_reason,
    :requirements,
    :organization_id,
    links: %{},
    raw: %{}
  ]

  @doc false
  @spec from_response(Response.t(), atom()) :: {:ok, t()} | {:error, Error.t()}
  def from_response(
        %Response{body: %{"resource" => "capability", "name" => name} = body},
        _operation
      )
      when is_binary(name) and name != "" do
    {:ok,
     %__MODULE__{
       resource: "capability",
       name: name,
       status: Map.get(body, "status"),
       status_reason: Map.get(body, "statusReason"),
       requirements: Map.get(body, "requirements"),
       organization_id: Map.get(body, "organizationId"),
       links: links(Map.get(body, "_links")),
       raw: body
     }}
  end

  def from_response(%Response{} = response, operation),
    do: invalid_response_error(operation, response)

  @doc """
  Returns true when the capability status is `enabled`.
  """
  @doc since: "0.5.0"
  @spec enabled?(t() | term()) :: boolean()
  def enabled?(capability), do: status?(capability, "enabled")

  @doc """
  Returns true when the capability status is `pending`.
  """
  @doc since: "0.5.0"
  @spec pending?(t() | term()) :: boolean()
  def pending?(capability), do: status?(capability, "pending")

  @doc """
  Returns true when the capability status is `disabled`.
  """
  @doc since: "0.5.0"
  @spec disabled?(t() | term()) :: boolean()
  def disabled?(capability), do: status?(capability, "disabled")

  defp status?(%__MODULE__{status: status}, expected), do: status == expected
  defp status?(_capability, _expected), do: false

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
       reason: :invalid_capability_response,
       operation: operation
     )}
  end
end
