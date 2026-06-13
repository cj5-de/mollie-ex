defmodule MollieEx.Customers do
  @moduledoc """
  Create, retrieve, list, update, delete, and inspect payments for Mollie customers.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.

  Customer creation accepts a caller-owned idempotency key. The SDK never
  generates idempotency keys implicitly.

  ```elixir
  {:ok, customer} =
    MollieEx.Customers.create(
      client,
      %{
        name: "Jane Doe",
        email: "jane@example.org"
      },
      idempotency_key: "0e4f812e-5d50-4fcb-8c42-153f17e52147"
    )
  ```
  """
  @moduledoc since: "0.1.0"

  alias MollieEx.Client
  alias MollieEx.Customer
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Payment
  alias MollieEx.Resources.Customers.{Create, CreatePayment, Delete, Get, ListPayments, Update}
  alias MollieEx.Resources.Customers.List, as: ListRequest
  alias MollieEx.Resources.RequestRunner

  @type create_params :: map()
  @type create_option ::
          {:idempotency_key, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type create_payment_params :: map()
  @type create_payment_option ::
          {:idempotency_key, String.t()}
          | {:include, String.t()}
          | {:profile_id, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:include, String.t()}
          | {:testmode, boolean()}
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
  @type list_payments_option ::
          {:from, String.t()}
          | {:limit, pos_integer()}
          | {:sort, :asc | :desc | String.t()}
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
  @type delete_option ::
          {:idempotency_key, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Creates a Mollie customer.

  Customer creation supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.1.0"
  @spec create(Client.t(), create_params(), [create_option()]) ::
          {:ok, Customer.t()} | {:error, Error.t()}
  def create(client, params, opts \\ [])

  def create(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    with {:ok, request, transport_opts} <- Create.build(client, params, opts) do
      request_customer(client, request, transport_opts, :customers_create)
    end
  end

  def create(%Client{}, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def create(%Client{}, _params, _opts), do: configuration_error(:invalid_customer_params)
  def create(_client, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Creates a Mollie payment for a customer.

  Customer payment creation supports caller-owned idempotency keys. The SDK
  never generates idempotency keys implicitly.
  """
  @doc since: "0.1.0"
  @spec create_payment(Client.t(), String.t(), create_payment_params(), [create_payment_option()]) ::
          {:ok, Payment.t()} | {:error, Error.t()}
  def create_payment(client, customer_id, params, opts \\ [])

  def create_payment(%Client{} = client, customer_id, params, opts)
      when is_binary(customer_id) and is_map(params) and is_list(opts) do
    with {:ok, request, transport_opts} <-
           CreatePayment.build(client, customer_id, params, opts) do
      request_payment(client, request, transport_opts, :customers_create_payment)
    end
  end

  def create_payment(%Client{}, _customer_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def create_payment(%Client{}, _customer_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_payment_params)

  def create_payment(%Client{}, _customer_id, _params, _opts),
    do: configuration_error(:invalid_customer_id)

  def create_payment(_client, _customer_id, _params, _opts),
    do: configuration_error(:invalid_client)

  @doc """
  Retrieves a Mollie customer by ID.
  """
  @doc since: "0.1.0"
  @spec get(Client.t(), String.t(), [get_option()]) ::
          {:ok, Customer.t()} | {:error, Error.t()}
  def get(client, customer_id, opts \\ [])

  def get(%Client{} = client, customer_id, opts)
      when is_binary(customer_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- Get.build(client, customer_id, opts) do
      request_customer(client, request, transport_opts, :customers_get)
    end
  end

  def get(%Client{}, _customer_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, _customer_id, _opts), do: configuration_error(:invalid_customer_id)
  def get(_client, _customer_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Lists Mollie customers.
  """
  @doc since: "0.1.0"
  @spec list(Client.t(), [list_option()]) ::
          {:ok, MollieList.t(Customer.t())} | {:error, Error.t()}
  def list(client, opts \\ [])

  def list(%Client{} = client, opts) when is_list(opts) do
    with {:ok, request, transport_opts} <- ListRequest.build(client, opts) do
      request_customer_list(client, request, transport_opts)
    end
  end

  def list(%Client{}, _opts), do: configuration_error(:invalid_options)
  def list(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Lists payments linked to a Mollie customer.
  """
  @doc since: "0.1.0"
  @spec list_payments(Client.t(), String.t(), [list_payments_option()]) ::
          {:ok, MollieList.t(Payment.t())} | {:error, Error.t()}
  def list_payments(client, customer_id, opts \\ [])

  def list_payments(%Client{} = client, customer_id, opts)
      when is_binary(customer_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- ListPayments.build(client, customer_id, opts) do
      request_payment_list(client, request, transport_opts)
    end
  end

  def list_payments(%Client{}, _customer_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def list_payments(%Client{}, _customer_id, _opts), do: configuration_error(:invalid_customer_id)
  def list_payments(_client, _customer_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Updates a Mollie customer by ID.

  Customer updates support caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.1.0"
  @spec update(Client.t(), String.t(), update_params(), [update_option()]) ::
          {:ok, Customer.t()} | {:error, Error.t()}
  def update(client, customer_id, params, opts \\ [])

  def update(%Client{} = client, customer_id, params, opts)
      when is_binary(customer_id) and is_map(params) and is_list(opts) do
    with {:ok, request, transport_opts} <- Update.build(client, customer_id, params, opts) do
      request_customer(client, request, transport_opts, :customers_update)
    end
  end

  def update(%Client{}, _customer_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def update(%Client{}, _customer_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_customer_params)

  def update(%Client{}, _customer_id, _params, _opts),
    do: configuration_error(:invalid_customer_id)

  def update(_client, _customer_id, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Deletes a Mollie customer by ID.

  Customer deletion supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.1.0"
  @spec delete(Client.t(), String.t(), [delete_option()]) ::
          {:ok, :no_content} | {:error, Error.t()}
  def delete(client, customer_id, opts \\ [])

  def delete(%Client{} = client, customer_id, opts)
      when is_binary(customer_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- Delete.build(client, customer_id, opts) do
      request_no_content(client, request, transport_opts)
    end
  end

  def delete(%Client{}, _customer_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def delete(%Client{}, _customer_id, _opts), do: configuration_error(:invalid_customer_id)
  def delete(_client, _customer_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end

  defp request_customer(%Client{} = client, request, transport_opts, operation) do
    RequestRunner.decode(client, request, transport_opts, &Customer.from_response(&1, operation))
  end

  defp request_customer_list(%Client{} = client, request, transport_opts) do
    RequestRunner.decode_list(
      client,
      request,
      transport_opts,
      "customers",
      :customers_list,
      &Customer.from_response(&1, :customers_list)
    )
  end

  defp request_payment(%Client{} = client, request, transport_opts, operation) do
    RequestRunner.decode(client, request, transport_opts, &Payment.from_response(&1, operation))
  end

  defp request_payment_list(%Client{} = client, request, transport_opts) do
    RequestRunner.decode_list(
      client,
      request,
      transport_opts,
      "payments",
      :customers_list_payments,
      &Payment.from_response(&1, :customers_list_payments)
    )
  end

  defp request_no_content(%Client{} = client, request, transport_opts) do
    RequestRunner.expect_empty(
      client,
      request,
      transport_opts,
      204,
      :no_content,
      :invalid_no_content_response
    )
  end
end
