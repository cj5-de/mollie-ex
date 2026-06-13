defmodule MollieEx.Customers do
  @moduledoc """
  Create and retrieve Mollie customers.

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
  alias MollieEx.HTTP.{Telemetry, Transport}
  alias MollieEx.Resources.Customers.{Create, Get}

  @type create_params :: map()
  @type create_option ::
          {:idempotency_key, String.t()}
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

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end

  defp request_customer(%Client{} = client, request, transport_opts, operation) do
    start_time = Telemetry.start(client, request)
    transport_opts = Keyword.put(transport_opts, :telemetry, false)

    case Transport.request(client, request, transport_opts) do
      {:ok, response} ->
        result = Customer.from_response(response, operation)
        emit_customer_result(client, request, response, result, start_time)
        result

      {:error, %Error{} = error} = result ->
        Telemetry.emit_result(client, request, result, start_time)
        {:error, error}
    end
  end

  defp emit_customer_result(client, request, response, {:ok, %Customer{}}, start_time) do
    Telemetry.emit_result(client, request, {:ok, response}, start_time)
  end

  defp emit_customer_result(
         client,
         request,
         _response,
         {:error, %Error{} = error},
         start_time
       ) do
    Telemetry.emit_result(client, request, {:error, error}, start_time)
  end
end
