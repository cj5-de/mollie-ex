defmodule MollieEx.OnboardingStatus do
  @moduledoc """
  Onboarding status returned by the Mollie Onboarding API.

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
          name: String.t() | nil,
          status: String.t() | nil,
          can_receive_payments: boolean() | nil,
          can_receive_settlements: boolean() | nil,
          signed_up_at: String.t() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:resource, :raw]
  defstruct [
    :resource,
    :name,
    :status,
    :can_receive_payments,
    :can_receive_settlements,
    :signed_up_at,
    links: %{},
    raw: %{}
  ]

  @doc false
  @spec from_response(Response.t(), atom()) :: {:ok, t()} | {:error, Error.t()}
  def from_response(%Response{body: %{"resource" => "onboarding"} = body}, _operation) do
    {:ok,
     %__MODULE__{
       resource: "onboarding",
       name: Map.get(body, "name"),
       status: Map.get(body, "status"),
       can_receive_payments: Map.get(body, "canReceivePayments"),
       can_receive_settlements: Map.get(body, "canReceiveSettlements"),
       signed_up_at: Map.get(body, "signedUpAt"),
       links: links(Map.get(body, "_links")),
       raw: body
     }}
  end

  def from_response(%Response{} = response, operation),
    do: invalid_response_error(operation, response)

  @doc """
  Returns true when the onboarding status is `needs-data`.
  """
  @doc since: "0.5.0"
  @spec needs_data?(t() | term()) :: boolean()
  def needs_data?(status), do: status?(status, "needs-data")

  @doc """
  Returns true when the onboarding status is `in-review`.
  """
  @doc since: "0.5.0"
  @spec in_review?(t() | term()) :: boolean()
  def in_review?(status), do: status?(status, "in-review")

  @doc """
  Returns true when the onboarding status is `completed`.
  """
  @doc since: "0.5.0"
  @spec completed?(t() | term()) :: boolean()
  def completed?(status), do: status?(status, "completed")

  defp status?(%__MODULE__{status: status}, expected), do: status == expected
  defp status?(_status, _expected), do: false

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
       reason: :invalid_onboarding_status_response,
       operation: operation
     )}
  end
end
