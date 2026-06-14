defmodule MollieEx.Refunds do
  @moduledoc """
  Create, retrieve, list, and cancel Mollie refunds.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.

  Refund write operations accept caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.

  ```elixir
  {:ok, refund} =
    MollieEx.Refunds.create(
      client,
      "tr_123",
      %{amount: %{currency: "EUR", value: "10.00"}},
      idempotency_key: "f7f88f02-9a60-4a1f-bab8-8ef9e29cfeaf"
    )
  ```
  """
  @moduledoc since: "0.1.0"

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Refund
  alias MollieEx.Resources.Refunds.{All, Cancel, Create, Get}
  alias MollieEx.Resources.Refunds.List, as: ListRequest
  alias MollieEx.Resources.RequestRunner

  @type all_option ::
          {:from, String.t()}
          | {:limit, pos_integer()}
          | {:sort, :asc | :desc | String.t()}
          | {:embed, String.t()}
          | {:profile_id, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
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
  @type cancel_option ::
          {:idempotency_key, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Lists all Mollie refunds.

  This is the top-level refund list endpoint. Use `list/3` to list refunds for
  a specific payment.
  """
  @doc since: "0.1.0"
  @spec all(Client.t(), [all_option()]) ::
          {:ok, MollieList.t(Refund.t())} | {:error, Error.t()}
  def all(client, opts \\ [])

  def all(%Client{} = client, opts) when is_list(opts) do
    with {:ok, request, transport_opts} <- All.build(client, opts) do
      request_refund_list(client, request, transport_opts, :refunds_all)
    end
  end

  def all(%Client{}, _opts), do: configuration_error(:invalid_options)
  def all(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Creates a refund for a Mollie payment.

  Refund creation supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.1.0"
  @spec create(Client.t(), String.t(), create_params(), [create_option()]) ::
          {:ok, Refund.t()} | {:error, Error.t()}
  def create(client, payment_id, params, opts \\ [])

  def create(%Client{} = client, payment_id, params, opts)
      when is_binary(payment_id) and is_map(params) and is_list(opts) do
    with {:ok, request, transport_opts} <- Create.build(client, payment_id, params, opts) do
      request_refund(client, request, transport_opts, :refunds_create)
    end
  end

  def create(%Client{}, _payment_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def create(%Client{}, _payment_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_refund_params)

  def create(%Client{}, _payment_id, _params, _opts), do: configuration_error(:invalid_payment_id)
  def create(_client, _payment_id, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a Mollie refund by payment ID and refund ID.
  """
  @doc since: "0.1.0"
  @spec get(Client.t(), String.t(), String.t(), [get_option()]) ::
          {:ok, Refund.t()} | {:error, Error.t()}
  def get(client, payment_id, refund_id, opts \\ [])

  def get(%Client{} = client, payment_id, refund_id, opts)
      when is_binary(payment_id) and is_binary(refund_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- Get.build(client, payment_id, refund_id, opts) do
      request_refund(client, request, transport_opts, :refunds_get)
    end
  end

  def get(%Client{}, _payment_id, _refund_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, payment_id, _refund_id, _opts) when not is_binary(payment_id),
    do: configuration_error(:invalid_payment_id)

  def get(%Client{}, _payment_id, _refund_id, _opts),
    do: configuration_error(:invalid_refund_id)

  def get(_client, _payment_id, _refund_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Lists Mollie refunds for a payment.
  """
  @doc since: "0.1.0"
  @spec list(Client.t(), String.t(), [list_option()]) ::
          {:ok, MollieList.t(Refund.t())} | {:error, Error.t()}
  def list(client, payment_id, opts \\ [])

  def list(%Client{} = client, payment_id, opts) when is_binary(payment_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- ListRequest.build(client, payment_id, opts) do
      request_refund_list(client, request, transport_opts, :refunds_list)
    end
  end

  def list(%Client{}, _payment_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def list(%Client{}, _payment_id, _opts), do: configuration_error(:invalid_payment_id)
  def list(_client, _payment_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Cancels a Mollie refund by payment ID and refund ID.

  Refund cancellation supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.1.0"
  @spec cancel(Client.t(), String.t(), String.t(), [cancel_option()]) ::
          {:ok, :no_content} | {:error, Error.t()}
  def cancel(client, payment_id, refund_id, opts \\ [])

  def cancel(%Client{} = client, payment_id, refund_id, opts)
      when is_binary(payment_id) and is_binary(refund_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- Cancel.build(client, payment_id, refund_id, opts) do
      request_no_content(client, request, transport_opts)
    end
  end

  def cancel(%Client{}, _payment_id, _refund_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def cancel(%Client{}, payment_id, _refund_id, _opts) when not is_binary(payment_id),
    do: configuration_error(:invalid_payment_id)

  def cancel(%Client{}, _payment_id, _refund_id, _opts),
    do: configuration_error(:invalid_refund_id)

  def cancel(_client, _payment_id, _refund_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end

  defp request_refund(%Client{} = client, request, transport_opts, operation) do
    RequestRunner.decode(client, request, transport_opts, &Refund.from_response(&1, operation))
  end

  defp request_refund_list(%Client{} = client, request, transport_opts, operation) do
    RequestRunner.decode_list(
      client,
      request,
      transport_opts,
      "refunds",
      operation,
      &Refund.from_response(&1, operation)
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
