defmodule MollieEx.Payments do
  @moduledoc """
  Create, retrieve, list, update, and cancel Mollie payments.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.
  """

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.{Telemetry, Transport}
  alias MollieEx.List, as: MollieList
  alias MollieEx.Payment
  alias MollieEx.Resources.ListDecoder
  alias MollieEx.Resources.Payments.{Cancel, Create, Get, Update}
  alias MollieEx.Resources.Payments.List, as: ListRequest

  @type create_params :: map()
  @type create_option ::
          {:idempotency_key, String.t()}
          | {:include, String.t()}
          | {:profile_id, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:include, String.t()}
          | {:embed, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type list_option ::
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
  @type cancel_option ::
          {:idempotency_key, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Creates a Mollie payment.

  Payment creation supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @spec create(Client.t(), create_params(), [create_option()]) ::
          {:ok, Payment.t()} | {:error, Error.t()}
  def create(client, params, opts \\ [])

  def create(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    with {:ok, request, transport_opts} <- Create.build(client, params, opts) do
      request_payment(client, request, transport_opts, :payments_create)
    end
  end

  def create(%Client{}, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def create(%Client{}, _params, _opts), do: configuration_error(:invalid_payment_params)
  def create(_client, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a Mollie payment by payment ID.
  """
  @spec get(Client.t(), String.t(), [get_option()]) :: {:ok, Payment.t()} | {:error, Error.t()}
  def get(client, payment_id, opts \\ [])

  def get(%Client{} = client, payment_id, opts) when is_binary(payment_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- Get.build(client, payment_id, opts) do
      request_payment(client, request, transport_opts, :payments_get)
    end
  end

  def get(%Client{}, _payment_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, _payment_id, _opts), do: configuration_error(:invalid_payment_id)
  def get(_client, _payment_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Lists Mollie payments.
  """
  @spec list(Client.t(), [list_option()]) ::
          {:ok, MollieList.t(Payment.t())} | {:error, Error.t()}
  def list(client, opts \\ [])

  def list(%Client{} = client, opts) when is_list(opts) do
    with {:ok, request, transport_opts} <- ListRequest.build(client, opts) do
      request_payment_list(client, request, transport_opts)
    end
  end

  def list(%Client{}, _opts), do: configuration_error(:invalid_options)
  def list(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Updates a Mollie payment by payment ID.

  Payment updates support caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @spec update(Client.t(), String.t(), update_params(), [update_option()]) ::
          {:ok, Payment.t()} | {:error, Error.t()}
  def update(client, payment_id, params, opts \\ [])

  def update(%Client{} = client, payment_id, params, opts)
      when is_binary(payment_id) and is_map(params) and is_list(opts) do
    with {:ok, request, transport_opts} <- Update.build(client, payment_id, params, opts) do
      request_payment(client, request, transport_opts, :payments_update)
    end
  end

  def update(%Client{}, _payment_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def update(%Client{}, _payment_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_payment_params)

  def update(%Client{}, _payment_id, _params, _opts), do: configuration_error(:invalid_payment_id)
  def update(_client, _payment_id, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Cancels a Mollie payment by payment ID.

  Payment cancellation supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @spec cancel(Client.t(), String.t(), [cancel_option()]) ::
          {:ok, Payment.t()} | {:error, Error.t()}
  def cancel(client, payment_id, opts \\ [])

  def cancel(%Client{} = client, payment_id, opts) when is_binary(payment_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- Cancel.build(client, payment_id, opts) do
      request_payment(client, request, transport_opts, :payments_cancel)
    end
  end

  def cancel(%Client{}, _payment_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def cancel(%Client{}, _payment_id, _opts), do: configuration_error(:invalid_payment_id)
  def cancel(_client, _payment_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end

  defp request_payment(%Client{} = client, request, transport_opts, operation) do
    start_time = Telemetry.start(client, request)
    transport_opts = Keyword.put(transport_opts, :telemetry, false)

    case Transport.request(client, request, transport_opts) do
      {:ok, response} ->
        result = Payment.from_response(response, operation)
        emit_payment_result(client, request, response, result, start_time)
        result

      {:error, %Error{} = error} = result ->
        Telemetry.emit_result(client, request, result, start_time)
        {:error, error}
    end
  end

  defp request_payment_list(%Client{} = client, request, transport_opts) do
    start_time = Telemetry.start(client, request)
    transport_opts = Keyword.put(transport_opts, :telemetry, false)

    case Transport.request(client, request, transport_opts) do
      {:ok, response} ->
        result =
          ListDecoder.from_response(
            response,
            "payments",
            :payments_list,
            &Payment.from_response(&1, :payments_list)
          )

        emit_payment_result(client, request, response, result, start_time)
        result

      {:error, %Error{} = error} = result ->
        Telemetry.emit_result(client, request, result, start_time)
        {:error, error}
    end
  end

  defp emit_payment_result(client, request, response, {:ok, %Payment{}}, start_time) do
    Telemetry.emit_result(client, request, {:ok, response}, start_time)
  end

  defp emit_payment_result(client, request, response, {:ok, %MollieList{}}, start_time) do
    Telemetry.emit_result(client, request, {:ok, response}, start_time)
  end

  defp emit_payment_result(client, request, _response, {:error, %Error{} = error}, start_time) do
    Telemetry.emit_result(client, request, {:error, error}, start_time)
  end
end
