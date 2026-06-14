defmodule MollieEx.Subscription do
  @moduledoc """
  Subscription resource returned by the Mollie API.

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
          mode: String.t() | nil,
          status: String.t() | nil,
          amount: Money.t() | nil,
          times: integer() | nil,
          times_remaining: integer() | nil,
          interval: String.t() | nil,
          start_date: String.t() | nil,
          next_payment_date: String.t() | nil,
          description: String.t() | nil,
          method: String.t() | nil,
          application_fee: term(),
          metadata: term(),
          webhook_url: String.t() | nil,
          customer_id: String.t() | nil,
          mandate_id: String.t() | nil,
          created_at: String.t() | nil,
          canceled_at: String.t() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :resource,
    :mode,
    :status,
    :amount,
    :times,
    :times_remaining,
    :interval,
    :start_date,
    :next_payment_date,
    :description,
    :method,
    :application_fee,
    :metadata,
    :webhook_url,
    :customer_id,
    :mandate_id,
    :created_at,
    :canceled_at,
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
           amount: Money.from(Map.get(body, "amount")),
           times: Map.get(body, "times"),
           times_remaining: Map.get(body, "timesRemaining"),
           interval: Map.get(body, "interval"),
           start_date: Map.get(body, "startDate"),
           next_payment_date: Map.get(body, "nextPaymentDate"),
           description: Map.get(body, "description"),
           method: Map.get(body, "method"),
           application_fee: Map.get(body, "applicationFee"),
           metadata: Map.get(body, "metadata"),
           webhook_url: Map.get(body, "webhookUrl"),
           customer_id: Map.get(body, "customerId"),
           mandate_id: Map.get(body, "mandateId"),
           created_at: Map.get(body, "createdAt"),
           canceled_at: Map.get(body, "canceledAt"),
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
  Returns true when the subscription status is `active`.
  """
  @spec active?(t() | term()) :: boolean()
  def active?(%__MODULE__{status: "active"}), do: true
  def active?(_subscription), do: false

  @doc """
  Returns true when the subscription status is `canceled`.
  """
  @spec canceled?(t() | term()) :: boolean()
  def canceled?(%__MODULE__{status: "canceled"}), do: true
  def canceled?(_subscription), do: false

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
       reason: :invalid_subscription_response,
       operation: operation
     )}
  end
end
