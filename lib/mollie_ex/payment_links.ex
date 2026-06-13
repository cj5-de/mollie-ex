defmodule MollieEx.PaymentLinks do
  @moduledoc """
  Create, retrieve, list, update, delete, and inspect payments for Mollie payment links.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.

  Payment link creation accepts a caller-owned idempotency key. The SDK never
  generates idempotency keys implicitly.

  ```elixir
  {:ok, payment_link} =
    MollieEx.PaymentLinks.create(
      client,
      %{
        description: "Order #123",
        amount: %{currency: "EUR", value: "10.00"}
      },
      idempotency_key: "fc1693c0-b788-46f5-9d08-61eac31d5ab8"
    )
  ```
  """
  @moduledoc since: "0.1.0"

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Payment
  alias MollieEx.PaymentLink
  alias MollieEx.Resources.PaymentLinks.{Create, Delete, Get, ListPayments, Update}
  alias MollieEx.Resources.PaymentLinks.List, as: ListRequest
  alias MollieEx.Resources.RequestRunner

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
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type list_payments_option ::
          {:from, String.t()}
          | {:limit, pos_integer()}
          | {:sort, :asc | :desc | String.t()}
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
  Creates a Mollie payment link.

  Payment link creation supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.1.0"
  @spec create(Client.t(), create_params(), [create_option()]) ::
          {:ok, PaymentLink.t()} | {:error, Error.t()}
  def create(client, params, opts \\ [])

  def create(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    with {:ok, request, transport_opts} <- Create.build(client, params, opts) do
      request_payment_link(client, request, transport_opts, :payment_links_create)
    end
  end

  def create(%Client{}, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def create(%Client{}, _params, _opts), do: configuration_error(:invalid_payment_link_params)
  def create(_client, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a Mollie payment link by ID.
  """
  @doc since: "0.1.0"
  @spec get(Client.t(), String.t(), [get_option()]) ::
          {:ok, PaymentLink.t()} | {:error, Error.t()}
  def get(client, payment_link_id, opts \\ [])

  def get(%Client{} = client, payment_link_id, opts)
      when is_binary(payment_link_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- Get.build(client, payment_link_id, opts) do
      request_payment_link(client, request, transport_opts, :payment_links_get)
    end
  end

  def get(%Client{}, _payment_link_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, _payment_link_id, _opts),
    do: configuration_error(:invalid_payment_link_id)

  def get(_client, _payment_link_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Lists Mollie payment links.
  """
  @doc since: "0.1.0"
  @spec list(Client.t(), [list_option()]) ::
          {:ok, MollieList.t(PaymentLink.t())} | {:error, Error.t()}
  def list(client, opts \\ [])

  def list(%Client{} = client, opts) when is_list(opts) do
    with {:ok, request, transport_opts} <- ListRequest.build(client, opts) do
      request_payment_link_list(client, request, transport_opts)
    end
  end

  def list(%Client{}, _opts), do: configuration_error(:invalid_options)
  def list(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Lists payments created for a Mollie payment link.
  """
  @doc since: "0.1.0"
  @spec list_payments(Client.t(), String.t(), [list_payments_option()]) ::
          {:ok, MollieList.t(Payment.t())} | {:error, Error.t()}
  def list_payments(client, payment_link_id, opts \\ [])

  def list_payments(%Client{} = client, payment_link_id, opts)
      when is_binary(payment_link_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- ListPayments.build(client, payment_link_id, opts) do
      request_payment_list(client, request, transport_opts)
    end
  end

  def list_payments(%Client{}, _payment_link_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def list_payments(%Client{}, _payment_link_id, _opts),
    do: configuration_error(:invalid_payment_link_id)

  def list_payments(_client, _payment_link_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Updates a Mollie payment link by ID.

  Payment link updates support caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.1.0"
  @spec update(Client.t(), String.t(), update_params(), [update_option()]) ::
          {:ok, PaymentLink.t()} | {:error, Error.t()}
  def update(client, payment_link_id, params, opts \\ [])

  def update(%Client{} = client, payment_link_id, params, opts)
      when is_binary(payment_link_id) and is_map(params) and is_list(opts) do
    with {:ok, request, transport_opts} <-
           Update.build(client, payment_link_id, params, opts) do
      request_payment_link(client, request, transport_opts, :payment_links_update)
    end
  end

  def update(%Client{}, _payment_link_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def update(%Client{}, _payment_link_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_payment_link_params)

  def update(%Client{}, _payment_link_id, _params, _opts),
    do: configuration_error(:invalid_payment_link_id)

  def update(_client, _payment_link_id, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Deletes a Mollie payment link by ID.

  Payment link deletion supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.1.0"
  @spec delete(Client.t(), String.t(), [delete_option()]) ::
          {:ok, :no_content} | {:error, Error.t()}
  def delete(client, payment_link_id, opts \\ [])

  def delete(%Client{} = client, payment_link_id, opts)
      when is_binary(payment_link_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- Delete.build(client, payment_link_id, opts) do
      request_no_content(client, request, transport_opts)
    end
  end

  def delete(%Client{}, _payment_link_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def delete(%Client{}, _payment_link_id, _opts),
    do: configuration_error(:invalid_payment_link_id)

  def delete(_client, _payment_link_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end

  defp request_payment_link(%Client{} = client, request, transport_opts, operation) do
    RequestRunner.decode(
      client,
      request,
      transport_opts,
      &PaymentLink.from_response(&1, operation)
    )
  end

  defp request_payment_link_list(%Client{} = client, request, transport_opts) do
    RequestRunner.decode_list(
      client,
      request,
      transport_opts,
      "payment_links",
      :payment_links_list,
      &PaymentLink.from_response(&1, :payment_links_list)
    )
  end

  defp request_payment_list(%Client{} = client, request, transport_opts) do
    RequestRunner.decode_list(
      client,
      request,
      transport_opts,
      "payments",
      :payment_links_list_payments,
      &Payment.from_response(&1, :payment_links_list_payments)
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
