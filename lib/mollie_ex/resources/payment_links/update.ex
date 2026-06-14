defmodule MollieEx.Resources.PaymentLinks.Update do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Casing
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :idempotency_key,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]
  @structured_body_keys ~w(minimumAmount lines billingAddress shippingAddress)

  @spec build(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, payment_link_id, params, opts)
      when is_binary(payment_link_id) and is_map(params) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         {:ok, payment_link_id} <- Options.payment_link_id(payment_link_id),
         :ok <- Options.reject_profile_id(params),
         :ok <- Options.reject_api_key_testmode(client, params, opts),
         {:ok, body, testmode} <- body(client, params, opts) do
      RequestBuilder.build(opts,
        method: :patch,
        path: "/payment-links/" <> Options.encode_path_segment(payment_link_id),
        path_template: "/payment-links/{paymentLinkId}",
        body: body,
        idempotency_policy: :optional,
        operation: :payment_links_update,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _payment_link_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _payment_link_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_payment_link_params)

  def build(%Client{}, _payment_link_id, _params, _opts),
    do: configuration_error(:invalid_payment_link_id)

  defp body(%Client{} = client, params, opts) do
    with {:ok, testmode} <- Options.effective_testmode(client, params, opts) do
      body =
        params
        |> Casing.to_mollie_body(@structured_body_keys)
        |> Options.drop_testmode()
        |> Options.put_body("testmode", testmode)

      {:ok, body, testmode}
    end
  end

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
