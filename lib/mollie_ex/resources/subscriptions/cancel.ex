defmodule MollieEx.Resources.Subscriptions.Cancel do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :idempotency_key,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, customer_id, subscription_id, opts)
      when is_binary(customer_id) and is_binary(subscription_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         {:ok, customer_id} <- Options.customer_id(customer_id),
         {:ok, subscription_id} <- Options.subscription_id(subscription_id),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :delete,
        path: Options.resource_path(["customers", customer_id, "subscriptions", subscription_id]),
        path_template: "/customers/{customerId}/subscriptions/{subscriptionId}",
        body: Options.body_testmode(testmode),
        idempotency_policy: :optional,
        operation: :subscriptions_cancel,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _customer_id, _subscription_id, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, customer_id, _subscription_id, _opts) when not is_binary(customer_id),
    do: Options.configuration_error(:invalid_customer_id)

  def build(%Client{}, _customer_id, _subscription_id, _opts),
    do: Options.configuration_error(:invalid_subscription_id)
end
