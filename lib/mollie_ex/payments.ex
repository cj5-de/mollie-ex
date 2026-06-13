defmodule MollieEx.Payments do
  @moduledoc """
  Create, retrieve, list, update, cancel, and release authorizations for Mollie payments.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.

  Write operations accept caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.

  ```elixir
  {:ok, payment} =
    MollieEx.Payments.create(
      client,
      %{
        description: "Order #123",
        amount: %{currency: "EUR", value: "10.00"},
        redirect_url: "https://example.com/checkout/return"
      },
      idempotency_key: "9f0f9a78-9d56-4d2b-a7b6-7fdb8cc7d5f3"
    )
  ```
  """
  @moduledoc since: "0.1.0"

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Payment
  alias MollieEx.Resources.Payments.{Cancel, Create, Get, ReleaseAuthorization, Update}
  alias MollieEx.Resources.Payments.List, as: ListRequest
  alias MollieEx.Resources.RequestRunner

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
  @type release_authorization_option ::
          {:idempotency_key, String.t()}
          | {:profile_id, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Creates a Mollie payment.

  Payment creation supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.1.0"
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
  @doc since: "0.1.0"
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
  @doc since: "0.1.0"
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
  @doc since: "0.1.0"
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
  @doc since: "0.1.0"
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

  @doc """
  Releases the remaining authorization for a Mollie payment.

  Authorization release supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.1.0"
  @spec release_authorization(Client.t(), String.t(), [release_authorization_option()]) ::
          {:ok, :accepted} | {:error, Error.t()}
  def release_authorization(client, payment_id, opts \\ [])

  def release_authorization(%Client{} = client, payment_id, opts)
      when is_binary(payment_id) and is_list(opts) do
    with {:ok, request, transport_opts} <-
           ReleaseAuthorization.build(client, payment_id, opts) do
      request_accepted(client, request, transport_opts)
    end
  end

  def release_authorization(%Client{}, _payment_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def release_authorization(%Client{}, _payment_id, _opts),
    do: configuration_error(:invalid_payment_id)

  def release_authorization(_client, _payment_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
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
      :payments_list,
      &Payment.from_response(&1, :payments_list)
    )
  end

  defp request_accepted(%Client{} = client, request, transport_opts) do
    RequestRunner.expect_empty(
      client,
      request,
      transport_opts,
      202,
      :accepted,
      :invalid_accepted_response
    )
  end
end
