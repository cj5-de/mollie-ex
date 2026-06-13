defmodule MollieEx.PaymentLink do
  @moduledoc """
  Payment link resource returned by the Mollie API.

  Stable fields are exposed as snake_case struct fields. The original decoded
  Mollie response is preserved in `raw` with upstream JSON casing unchanged.
  """
  @moduledoc since: "0.1.0"

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
          minimum_amount: Money.t() | nil,
          archived: boolean() | nil,
          redirect_url: String.t() | nil,
          webhook_url: String.t() | nil,
          profile_id: String.t() | nil,
          reusable: boolean() | nil,
          created_at: String.t() | nil,
          paid_at: String.t() | nil,
          updated_at: String.t() | nil,
          expires_at: String.t() | nil,
          allowed_methods: [String.t()] | nil,
          application_fee: term(),
          sequence_type: String.t() | nil,
          customer_id: String.t() | nil,
          lines: term(),
          billing_address: term(),
          shipping_address: term(),
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  # Payment link responses expose many stable top-level fields; keeping them
  # explicit lets callers avoid digging through `raw` for common data.
  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :resource,
    :mode,
    :description,
    :amount,
    :minimum_amount,
    :archived,
    :redirect_url,
    :webhook_url,
    :profile_id,
    :reusable,
    :created_at,
    :paid_at,
    :updated_at,
    :expires_at,
    :allowed_methods,
    :application_fee,
    :sequence_type,
    :customer_id,
    :lines,
    :billing_address,
    :shipping_address,
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
           minimum_amount: Money.from(Map.get(body, "minimumAmount")),
           archived: Map.get(body, "archived"),
           redirect_url: Map.get(body, "redirectUrl"),
           webhook_url: Map.get(body, "webhookUrl"),
           profile_id: Map.get(body, "profileId"),
           reusable: Map.get(body, "reusable"),
           created_at: Map.get(body, "createdAt"),
           paid_at: Map.get(body, "paidAt"),
           updated_at: Map.get(body, "updatedAt"),
           expires_at: Map.get(body, "expiresAt"),
           allowed_methods: Map.get(body, "allowedMethods"),
           application_fee: Map.get(body, "applicationFee"),
           sequence_type: Map.get(body, "sequenceType"),
           customer_id: Map.get(body, "customerId"),
           lines: Map.get(body, "lines"),
           billing_address: Map.get(body, "billingAddress"),
           shipping_address: Map.get(body, "shippingAddress"),
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
  Returns true when the payment link has a `paid_at` timestamp.
  """
  @spec paid?(t() | term()) :: boolean()
  def paid?(%__MODULE__{paid_at: paid_at}), do: present?(paid_at)
  def paid?(_payment_link), do: false

  @doc """
  Returns the hosted payment-link checkout URL when available.
  """
  @spec checkout_url(t() | term()) :: String.t() | nil
  def checkout_url(%__MODULE__{links: %{"paymentLink" => %Link{href: href}}})
      when is_binary(href),
      do: href

  def checkout_url(_payment_link), do: nil

  defp links(%{} = links) do
    Map.new(links, fn {rel, link} -> {rel, Link.from(link)} end)
  end

  defp links(_links), do: %{}

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)

  defp invalid_response_error(operation, %Response{} = response) do
    {:error,
     Error.exception(
       type: :decode,
       status: response.status,
       headers: response.headers,
       raw: response.raw,
       reason: :invalid_payment_link_response,
       operation: operation
     )}
  end
end
