defmodule MollieEx.Payment do
  @moduledoc """
  Payment resource returned by the Mollie API.

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
          created_at: String.t() | nil,
          paid_at: String.t() | nil,
          authorized_at: String.t() | nil,
          canceled_at: String.t() | nil,
          expires_at: String.t() | nil,
          expired_at: String.t() | nil,
          failed_at: String.t() | nil,
          status: String.t() | nil,
          status_reason: term(),
          is_cancelable: boolean() | nil,
          amount: Money.t() | nil,
          amount_refunded: Money.t() | nil,
          amount_remaining: Money.t() | nil,
          amount_captured: Money.t() | nil,
          amount_charged_back: Money.t() | nil,
          settlement_amount: Money.t() | nil,
          description: String.t() | nil,
          method: String.t() | nil,
          metadata: term(),
          details: term(),
          profile_id: String.t() | nil,
          sequence_type: String.t() | nil,
          redirect_url: String.t() | nil,
          cancel_url: String.t() | nil,
          webhook_url: String.t() | nil,
          locale: String.t() | nil,
          country_code: String.t() | nil,
          customer_id: String.t() | nil,
          mandate_id: String.t() | nil,
          subscription_id: String.t() | nil,
          order_id: String.t() | nil,
          settlement_id: String.t() | nil,
          capture_mode: String.t() | nil,
          capture_delay: String.t() | nil,
          capture_before: String.t() | nil,
          application_fee: term(),
          routing: term(),
          lines: term(),
          billing_address: term(),
          shipping_address: term(),
          restrict_payment_methods_to_country: String.t() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  # Mollie payment responses expose many stable top-level fields; keeping them
  # explicit lets callers avoid digging through `raw` for common data.
  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :resource,
    :mode,
    :created_at,
    :paid_at,
    :authorized_at,
    :canceled_at,
    :expires_at,
    :expired_at,
    :failed_at,
    :status,
    :status_reason,
    :is_cancelable,
    :amount,
    :amount_refunded,
    :amount_remaining,
    :amount_captured,
    :amount_charged_back,
    :settlement_amount,
    :description,
    :method,
    :metadata,
    :details,
    :profile_id,
    :sequence_type,
    :redirect_url,
    :cancel_url,
    :webhook_url,
    :locale,
    :country_code,
    :customer_id,
    :mandate_id,
    :subscription_id,
    :order_id,
    :settlement_id,
    :capture_mode,
    :capture_delay,
    :capture_before,
    :application_fee,
    :routing,
    :lines,
    :billing_address,
    :shipping_address,
    :restrict_payment_methods_to_country,
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
           created_at: Map.get(body, "createdAt"),
           paid_at: Map.get(body, "paidAt"),
           authorized_at: Map.get(body, "authorizedAt"),
           canceled_at: Map.get(body, "canceledAt"),
           expires_at: Map.get(body, "expiresAt"),
           expired_at: Map.get(body, "expiredAt"),
           failed_at: Map.get(body, "failedAt"),
           status: Map.get(body, "status"),
           status_reason: Map.get(body, "statusReason"),
           is_cancelable: Map.get(body, "isCancelable"),
           amount: Money.from(Map.get(body, "amount")),
           amount_refunded: Money.from(Map.get(body, "amountRefunded")),
           amount_remaining: Money.from(Map.get(body, "amountRemaining")),
           amount_captured: Money.from(Map.get(body, "amountCaptured")),
           amount_charged_back: Money.from(Map.get(body, "amountChargedBack")),
           settlement_amount: Money.from(Map.get(body, "settlementAmount")),
           description: Map.get(body, "description"),
           method: Map.get(body, "method"),
           metadata: Map.get(body, "metadata"),
           details: Map.get(body, "details"),
           profile_id: Map.get(body, "profileId"),
           sequence_type: Map.get(body, "sequenceType"),
           redirect_url: Map.get(body, "redirectUrl"),
           cancel_url: Map.get(body, "cancelUrl"),
           webhook_url: Map.get(body, "webhookUrl"),
           locale: Map.get(body, "locale"),
           country_code: Map.get(body, "countryCode"),
           customer_id: Map.get(body, "customerId"),
           mandate_id: Map.get(body, "mandateId"),
           subscription_id: Map.get(body, "subscriptionId"),
           order_id: Map.get(body, "orderId"),
           settlement_id: Map.get(body, "settlementId"),
           capture_mode: Map.get(body, "captureMode"),
           capture_delay: Map.get(body, "captureDelay"),
           capture_before: Map.get(body, "captureBefore"),
           application_fee: Map.get(body, "applicationFee"),
           routing: Map.get(body, "routing"),
           lines: Map.get(body, "lines"),
           billing_address: Map.get(body, "billingAddress"),
           shipping_address: Map.get(body, "shippingAddress"),
           restrict_payment_methods_to_country: Map.get(body, "restrictPaymentMethodsToCountry"),
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
  Returns true when the payment has a `paid_at` timestamp.
  """
  @spec paid?(t() | term()) :: boolean()
  def paid?(%__MODULE__{paid_at: paid_at}), do: present?(paid_at)
  def paid?(_payment), do: false

  @doc """
  Returns true when the payment status is `open`.
  """
  @spec open?(t() | term()) :: boolean()
  def open?(payment), do: status?(payment, "open")

  @doc """
  Returns true when the payment status is `pending`.
  """
  @spec pending?(t() | term()) :: boolean()
  def pending?(payment), do: status?(payment, "pending")

  @doc """
  Returns true when the payment status is `authorized`.
  """
  @spec authorized?(t() | term()) :: boolean()
  def authorized?(payment), do: status?(payment, "authorized")

  @doc """
  Returns true when the payment status is `canceled`.
  """
  @spec canceled?(t() | term()) :: boolean()
  def canceled?(payment), do: status?(payment, "canceled")

  @doc """
  Returns true when the payment status is `expired`.
  """
  @spec expired?(t() | term()) :: boolean()
  def expired?(payment), do: status?(payment, "expired")

  @doc """
  Returns true when the payment status is `failed`.
  """
  @spec failed?(t() | term()) :: boolean()
  def failed?(payment), do: status?(payment, "failed")

  @doc """
  Returns true when Mollie reports a remaining refundable amount.
  """
  @spec refundable?(t() | term()) :: boolean()
  def refundable?(%__MODULE__{amount_remaining: nil}), do: false
  def refundable?(%__MODULE__{}), do: true
  def refundable?(_payment), do: false

  @doc """
  Returns true when Mollie reports a remaining refundable amount.
  """
  @spec partially_refundable?(t() | term()) :: boolean()
  def partially_refundable?(payment), do: refundable?(payment)

  @doc """
  Returns true when the payment has a refunds link.
  """
  @spec has_refunds?(t() | term()) :: boolean()
  def has_refunds?(payment), do: not is_nil(link_href(payment, "refunds"))

  @doc """
  Returns true when the payment has a chargebacks link.
  """
  @spec has_chargebacks?(t() | term()) :: boolean()
  def has_chargebacks?(payment), do: not is_nil(link_href(payment, "chargebacks"))

  @doc """
  Returns true when the payment sequence type is `first`.
  """
  @spec sequence_type_first?(t() | term()) :: boolean()
  def sequence_type_first?(%__MODULE__{sequence_type: "first"}), do: true
  def sequence_type_first?(_payment), do: false

  @doc """
  Returns true when the payment sequence type is `recurring`.
  """
  @spec sequence_type_recurring?(t() | term()) :: boolean()
  def sequence_type_recurring?(%__MODULE__{sequence_type: "recurring"}), do: true
  def sequence_type_recurring?(_payment), do: false

  @doc """
  Returns the checkout URL when the payment has one.
  """
  @spec checkout_url(t() | term()) :: String.t() | nil
  def checkout_url(payment), do: link_href(payment, "checkout")

  @doc """
  Returns the mobile app checkout URL when the payment has one.
  """
  @spec mobile_app_checkout_url(t() | term()) :: String.t() | nil
  def mobile_app_checkout_url(payment), do: link_href(payment, "mobileAppCheckout")

  defp links(%{} = links) do
    Map.new(links, fn {rel, link} -> {rel, Link.from(link)} end)
  end

  defp links(_links), do: %{}

  defp status?(%__MODULE__{status: status}, status), do: true
  defp status?(_payment, _status), do: false

  defp present?(value) when is_binary(value), do: value != ""
  defp present?(nil), do: false
  defp present?(_value), do: true

  defp link_href(%__MODULE__{links: links}, rel) when is_map(links) do
    case Map.get(links, rel) do
      %Link{href: href} when is_binary(href) and href != "" -> href
      %{"href" => href} when is_binary(href) and href != "" -> href
      _link -> nil
    end
  end

  defp link_href(_payment, _rel), do: nil

  defp invalid_response_error(operation, %Response{} = response) do
    {:error,
     Error.exception(
       type: :decode,
       status: response.status,
       headers: response.headers,
       raw: response.raw,
       reason: :invalid_payment_response,
       operation: operation
     )}
  end
end
