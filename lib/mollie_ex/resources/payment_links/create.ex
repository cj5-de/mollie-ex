defmodule MollieEx.Resources.PaymentLinks.Create do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :idempotency_key,
    :profile_id,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]
  @structured_body_keys ~w(amount minimumAmount applicationFee lines billingAddress shippingAddress)

  @spec build(Client.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         :ok <- Options.reject_api_key_scoped_fields(client, params, opts),
         :ok <-
           Options.require_param(
             params,
             [:description, "description"],
             :missing_description
           ),
         {:ok, body, testmode} <- body(client, params, opts) do
      RequestBuilder.build(opts,
        method: :post,
        path: "/payment-links",
        path_template: "/payment-links",
        body: body,
        idempotency_policy: :optional,
        operation: :payment_links_create,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _params, _opts), do: configuration_error(:invalid_payment_link_params)

  defp body(%Client{} = client, params, opts),
    do: Options.body_with_profile(client, params, opts, @structured_body_keys, [])

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
