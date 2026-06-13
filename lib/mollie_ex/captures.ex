defmodule MollieEx.Captures do
  @moduledoc """
  Create, retrieve, and list Mollie payment captures.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.

  Capture creation accepts a caller-owned idempotency key. The SDK never
  generates idempotency keys implicitly.

  ```elixir
  {:ok, capture} =
    MollieEx.Captures.create(
      client,
      "tr_123",
      %{amount: %{currency: "EUR", value: "10.00"}},
      idempotency_key: "7da9444e-4360-4ab4-b411-73b33ac52b1f"
    )
  ```
  """
  @moduledoc since: "0.1.0"

  alias MollieEx.Capture
  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.{Telemetry, Transport}
  alias MollieEx.List, as: MollieList
  alias MollieEx.Resources.Captures.{Create, Get}
  alias MollieEx.Resources.Captures.List, as: ListRequest
  alias MollieEx.Resources.ListDecoder

  @type create_params :: map()
  @type create_option ::
          {:idempotency_key, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:embed, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type list_option ::
          {:from, String.t()}
          | {:limit, pos_integer()}
          | {:embed, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Creates a capture for an authorized Mollie payment.

  Capture creation supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.1.0"
  @spec create(Client.t(), String.t(), create_params(), [create_option()]) ::
          {:ok, Capture.t()} | {:error, Error.t()}
  def create(client, payment_id, params, opts \\ [])

  def create(%Client{} = client, payment_id, params, opts)
      when is_binary(payment_id) and is_map(params) and is_list(opts) do
    with {:ok, request, transport_opts} <- Create.build(client, payment_id, params, opts) do
      request_capture(client, request, transport_opts, :captures_create)
    end
  end

  def create(%Client{}, _payment_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def create(%Client{}, _payment_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_capture_params)

  def create(%Client{}, _payment_id, _params, _opts), do: configuration_error(:invalid_payment_id)
  def create(_client, _payment_id, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a Mollie capture by payment ID and capture ID.
  """
  @doc since: "0.1.0"
  @spec get(Client.t(), String.t(), String.t(), [get_option()]) ::
          {:ok, Capture.t()} | {:error, Error.t()}
  def get(client, payment_id, capture_id, opts \\ [])

  def get(%Client{} = client, payment_id, capture_id, opts)
      when is_binary(payment_id) and is_binary(capture_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- Get.build(client, payment_id, capture_id, opts) do
      request_capture(client, request, transport_opts, :captures_get)
    end
  end

  def get(%Client{}, _payment_id, _capture_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, payment_id, _capture_id, _opts) when not is_binary(payment_id),
    do: configuration_error(:invalid_payment_id)

  def get(%Client{}, _payment_id, _capture_id, _opts),
    do: configuration_error(:invalid_capture_id)

  def get(_client, _payment_id, _capture_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Lists Mollie captures for a payment.
  """
  @doc since: "0.1.0"
  @spec list(Client.t(), String.t(), [list_option()]) ::
          {:ok, MollieList.t(Capture.t())} | {:error, Error.t()}
  def list(client, payment_id, opts \\ [])

  def list(%Client{} = client, payment_id, opts) when is_binary(payment_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- ListRequest.build(client, payment_id, opts) do
      request_capture_list(client, request, transport_opts)
    end
  end

  def list(%Client{}, _payment_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def list(%Client{}, _payment_id, _opts), do: configuration_error(:invalid_payment_id)
  def list(_client, _payment_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end

  defp request_capture(%Client{} = client, request, transport_opts, operation) do
    start_time = Telemetry.start(client, request)
    transport_opts = Keyword.put(transport_opts, :telemetry, false)

    case Transport.request(client, request, transport_opts) do
      {:ok, response} ->
        result = Capture.from_response(response, operation)
        emit_capture_result(client, request, response, result, start_time)
        result

      {:error, %Error{} = error} = result ->
        Telemetry.emit_result(client, request, result, start_time)
        {:error, error}
    end
  end

  defp request_capture_list(%Client{} = client, request, transport_opts) do
    start_time = Telemetry.start(client, request)
    transport_opts = Keyword.put(transport_opts, :telemetry, false)

    case Transport.request(client, request, transport_opts) do
      {:ok, response} ->
        result =
          ListDecoder.from_response(
            response,
            "captures",
            :captures_list,
            &Capture.from_response(&1, :captures_list)
          )

        emit_capture_result(client, request, response, result, start_time)
        result

      {:error, %Error{} = error} = result ->
        Telemetry.emit_result(client, request, result, start_time)
        {:error, error}
    end
  end

  defp emit_capture_result(client, request, response, {:ok, %Capture{}}, start_time) do
    Telemetry.emit_result(client, request, {:ok, response}, start_time)
  end

  defp emit_capture_result(client, request, response, {:ok, %MollieList{}}, start_time) do
    Telemetry.emit_result(client, request, {:ok, response}, start_time)
  end

  defp emit_capture_result(client, request, _response, {:error, %Error{} = error}, start_time) do
    Telemetry.emit_result(client, request, {:error, error}, start_time)
  end
end
