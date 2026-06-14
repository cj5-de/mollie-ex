defmodule MollieEx.Subscriptions do
  @moduledoc """
  Create, retrieve, list, update, cancel, and inspect payments for Mollie subscriptions.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.
  """
  @moduledoc since: "0.4.0"

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Payment
  alias MollieEx.Resources.RequestRunner
  alias MollieEx.Resources.Subscriptions.{All, Cancel, Create, Get, ListPayments, Update}
  alias MollieEx.Resources.Subscriptions.List, as: ListRequest
  alias MollieEx.Subscription

  @type create_params :: map()
  @type create_option ::
          {:idempotency_key, String.t()}
          | {:profile_id, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type list_option ::
          {:from, String.t()}
          | {:limit, pos_integer()}
          | {:sort, :asc | :desc | String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type all_option ::
          {:from, String.t()}
          | {:limit, pos_integer()}
          | {:profile_id, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type update_params :: map()
  @type update_option ::
          {:idempotency_key, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type cancel_option ::
          {:idempotency_key, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type list_payments_option ::
          {:from, String.t()}
          | {:limit, pos_integer()}
          | {:sort, :asc | :desc | String.t()}
          | {:profile_id, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Creates a subscription for a customer.

  Subscription creation supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.4.0"
  @spec create(Client.t(), String.t(), create_params(), [create_option()]) ::
          {:ok, Subscription.t()} | {:error, Error.t()}
  def create(client, customer_id, params, opts \\ [])

  def create(%Client{} = client, customer_id, params, opts)
      when is_binary(customer_id) and is_map(params) and is_list(opts) do
    RequestRunner.run_resource(
      Create.build(client, customer_id, params, opts),
      client,
      Subscription,
      :subscriptions_create
    )
  end

  def create(%Client{}, _customer_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def create(%Client{}, _customer_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_subscription_params)

  def create(%Client{}, _customer_id, _params, _opts),
    do: configuration_error(:invalid_customer_id)

  def create(_client, _customer_id, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a customer subscription by ID.
  """
  @doc since: "0.4.0"
  @spec get(Client.t(), String.t(), String.t(), [get_option()]) ::
          {:ok, Subscription.t()} | {:error, Error.t()}
  def get(client, customer_id, subscription_id, opts \\ [])

  def get(%Client{} = client, customer_id, subscription_id, opts)
      when is_binary(customer_id) and is_binary(subscription_id) and is_list(opts) do
    RequestRunner.run_resource(
      Get.build(client, customer_id, subscription_id, opts),
      client,
      Subscription,
      :subscriptions_get
    )
  end

  def get(%Client{}, _customer_id, _subscription_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, customer_id, _subscription_id, _opts) when not is_binary(customer_id),
    do: configuration_error(:invalid_customer_id)

  def get(%Client{}, _customer_id, _subscription_id, _opts),
    do: configuration_error(:invalid_subscription_id)

  def get(_client, _customer_id, _subscription_id, _opts),
    do: configuration_error(:invalid_client)

  @doc """
  Lists subscriptions for a customer.
  """
  @doc since: "0.4.0"
  @spec list(Client.t(), String.t(), [list_option()]) ::
          {:ok, MollieList.t(Subscription.t())} | {:error, Error.t()}
  def list(client, customer_id, opts \\ [])

  def list(%Client{} = client, customer_id, opts)
      when is_binary(customer_id) and is_list(opts) do
    RequestRunner.run_resource_list(
      ListRequest.build(client, customer_id, opts),
      client,
      "subscriptions",
      Subscription,
      :subscriptions_list
    )
  end

  def list(%Client{}, _customer_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def list(%Client{}, _customer_id, _opts), do: configuration_error(:invalid_customer_id)
  def list(_client, _customer_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Lists subscriptions across customers.
  """
  @doc since: "0.4.0"
  @spec all(Client.t(), [all_option()]) ::
          {:ok, MollieList.t(Subscription.t())} | {:error, Error.t()}
  def all(client, opts \\ [])

  def all(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource_list(
      All.build(client, opts),
      client,
      "subscriptions",
      Subscription,
      :subscriptions_all
    )
  end

  def all(%Client{}, _opts), do: configuration_error(:invalid_options)
  def all(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Updates a customer subscription by ID.

  Subscription updates support caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.4.0"
  @spec update(Client.t(), String.t(), String.t(), update_params(), [update_option()]) ::
          {:ok, Subscription.t()} | {:error, Error.t()}
  def update(client, customer_id, subscription_id, params, opts \\ [])

  def update(%Client{} = client, customer_id, subscription_id, params, opts)
      when is_binary(customer_id) and is_binary(subscription_id) and is_map(params) and
             is_list(opts) do
    RequestRunner.run_resource(
      Update.build(client, customer_id, subscription_id, params, opts),
      client,
      Subscription,
      :subscriptions_update
    )
  end

  def update(%Client{}, _customer_id, _subscription_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def update(%Client{}, _customer_id, _subscription_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_subscription_params)

  def update(%Client{}, customer_id, _subscription_id, _params, _opts)
      when not is_binary(customer_id),
      do: configuration_error(:invalid_customer_id)

  def update(%Client{}, _customer_id, _subscription_id, _params, _opts),
    do: configuration_error(:invalid_subscription_id)

  def update(_client, _customer_id, _subscription_id, _params, _opts),
    do: configuration_error(:invalid_client)

  @doc """
  Cancels a customer subscription by ID.

  Subscription cancellation supports caller-owned idempotency keys. The SDK
  never generates idempotency keys implicitly.
  """
  @doc since: "0.4.0"
  @spec cancel(Client.t(), String.t(), String.t(), [cancel_option()]) ::
          {:ok, Subscription.t()} | {:error, Error.t()}
  def cancel(client, customer_id, subscription_id, opts \\ [])

  def cancel(%Client{} = client, customer_id, subscription_id, opts)
      when is_binary(customer_id) and is_binary(subscription_id) and is_list(opts) do
    RequestRunner.run_resource(
      Cancel.build(client, customer_id, subscription_id, opts),
      client,
      Subscription,
      :subscriptions_cancel
    )
  end

  def cancel(%Client{}, _customer_id, _subscription_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def cancel(%Client{}, customer_id, _subscription_id, _opts) when not is_binary(customer_id),
    do: configuration_error(:invalid_customer_id)

  def cancel(%Client{}, _customer_id, _subscription_id, _opts),
    do: configuration_error(:invalid_subscription_id)

  def cancel(_client, _customer_id, _subscription_id, _opts),
    do: configuration_error(:invalid_client)

  @doc """
  Lists payments generated for a subscription.
  """
  @doc since: "0.4.0"
  @spec list_payments(Client.t(), String.t(), String.t(), [list_payments_option()]) ::
          {:ok, MollieList.t(Payment.t())} | {:error, Error.t()}
  def list_payments(client, customer_id, subscription_id, opts \\ [])

  def list_payments(%Client{} = client, customer_id, subscription_id, opts)
      when is_binary(customer_id) and is_binary(subscription_id) and is_list(opts) do
    RequestRunner.run_resource_list(
      ListPayments.build(client, customer_id, subscription_id, opts),
      client,
      "payments",
      Payment,
      :subscriptions_list_payments
    )
  end

  def list_payments(%Client{}, _customer_id, _subscription_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def list_payments(%Client{}, customer_id, _subscription_id, _opts)
      when not is_binary(customer_id),
      do: configuration_error(:invalid_customer_id)

  def list_payments(%Client{}, _customer_id, _subscription_id, _opts),
    do: configuration_error(:invalid_subscription_id)

  def list_payments(_client, _customer_id, _subscription_id, _opts),
    do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
