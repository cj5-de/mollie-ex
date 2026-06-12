defmodule MollieEx.Capture do
  @moduledoc """
  Capture resource returned by the Mollie API.

  Stable fields are exposed as snake_case struct fields. The original decoded
  Mollie response is preserved in `raw` with upstream JSON casing unchanged.
  """

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.{Link, Money}

  @type links :: %{optional(String.t()) => Link.t() | term()}

  @type t :: %__MODULE__{
          id: String.t(),
          resource: String.t() | nil,
          mode: String.t() | nil,
          description: String.t() | nil,
          amount: Money.t() | nil,
          settlement_amount: Money.t() | nil,
          metadata: term(),
          payment_id: String.t() | nil,
          shipment_id: String.t() | nil,
          settlement_id: String.t() | nil,
          status: String.t() | nil,
          created_at: String.t() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  defstruct [
    :id,
    :resource,
    :mode,
    :description,
    :amount,
    :settlement_amount,
    :metadata,
    :payment_id,
    :shipment_id,
    :settlement_id,
    :status,
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
           description: Map.get(body, "description"),
           amount: Money.from(Map.get(body, "amount")),
           settlement_amount: Money.from(Map.get(body, "settlementAmount")),
           metadata: Map.get(body, "metadata"),
           payment_id: Map.get(body, "paymentId"),
           shipment_id: Map.get(body, "shipmentId"),
           settlement_id: Map.get(body, "settlementId"),
           status: Map.get(body, "status"),
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

  @doc """
  Returns true when the capture status is `pending`.
  """
  @spec pending?(t() | term()) :: boolean()
  def pending?(capture), do: status?(capture, "pending")

  @doc """
  Returns true when the capture status is `succeeded`.
  """
  @spec succeeded?(t() | term()) :: boolean()
  def succeeded?(capture), do: status?(capture, "succeeded")

  @doc """
  Returns true when the capture status is `failed`.
  """
  @spec failed?(t() | term()) :: boolean()
  def failed?(capture), do: status?(capture, "failed")

  defp links(%{} = links) do
    Map.new(links, fn {rel, link} -> {rel, Link.from(link)} end)
  end

  defp links(_links), do: %{}

  defp status?(%__MODULE__{status: status}, status), do: true
  defp status?(_capture, _status), do: false

  defp invalid_response_error(operation, %Response{} = response) do
    {:error,
     Error.exception(
       type: :decode,
       status: response.status,
       headers: response.headers,
       raw: response.raw,
       reason: :invalid_capture_response,
       operation: operation
     )}
  end
end
