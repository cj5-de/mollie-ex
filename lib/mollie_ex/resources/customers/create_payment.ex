defmodule MollieEx.Resources.Customers.CreatePayment do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :idempotency_key,
    :include,
    :profile_id,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]
  @customer_id_keys ["customerId", "customer_id", :customer_id]
  @structured_body_keys ~w(amount billingAddress shippingAddress applicationFee lines routing company)

  @spec build(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, customer_id, params, opts)
      when is_binary(customer_id) and is_map(params) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         :ok <- Options.reject_api_key_scoped_fields(client, params, opts),
         {:ok, customer_id} <- Options.customer_id(customer_id),
         {:ok, include} <- Options.string_option(opts, :include),
         {:ok, body, testmode} <- body(client, params, opts) do
      RequestBuilder.build(opts,
        method: :post,
        path: "/customers/" <> Options.encode_path_segment(customer_id) <> "/payments",
        path_template: "/customers/{customerId}/payments",
        query: Options.query(include: include),
        body: body,
        idempotency_policy: :optional,
        operation: :customers_create_payment,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _customer_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _customer_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_payment_params)

  def build(%Client{}, _customer_id, _params, _opts),
    do: configuration_error(:invalid_customer_id)

  defp body(%Client{} = client, params, opts),
    do: Options.body_with_profile(client, params, opts, @structured_body_keys, @customer_id_keys)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
