defmodule MollieEx.Resources.Subscriptions.Create do
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
  @customer_id_keys ["customerId", "customer_id", :customer_id]
  @structured_body_keys ~w(amount applicationFee)

  @spec build(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, customer_id, params, opts)
      when is_binary(customer_id) and is_map(params) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_scoped_fields(client, params, opts),
         {:ok, customer_id} <- Options.customer_id(customer_id),
         {:ok, body, testmode} <-
           Options.body_with_profile(
             client,
             params,
             opts,
             @structured_body_keys,
             @customer_id_keys
           ) do
      RequestBuilder.build(opts,
        method: :post,
        path: Options.resource_path(["customers", customer_id, "subscriptions"]),
        path_template: "/customers/{customerId}/subscriptions",
        body: body,
        idempotency_policy: :optional,
        operation: :subscriptions_create,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _customer_id, _params, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _customer_id, params, _opts) when not is_map(params),
    do: Options.configuration_error(:invalid_subscription_params)

  def build(%Client{}, _customer_id, _params, _opts),
    do: Options.configuration_error(:invalid_customer_id)
end
