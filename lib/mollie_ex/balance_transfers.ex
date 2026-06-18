defmodule MollieEx.BalanceTransfers do
  @moduledoc """
  Create and retrieve Mollie Connect balance transfers.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.BalanceTransfer
  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Resources.BalanceTransfers.{Create, Get, List}
  alias MollieEx.Resources.RequestRunner

  @type list_option ::
          {:from, String.t()}
          | {:limit, pos_integer()}
          | {:sort, :asc | :desc | String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type create_option ::
          {:idempotency_key, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Lists Connect balance transfers associated with the authenticated account.
  """
  @doc since: "0.5.0"
  @spec list(Client.t(), [list_option()]) ::
          {:ok, MollieList.t(BalanceTransfer.t())} | {:error, Error.t()}
  def list(client, opts \\ [])

  def list(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource_list(
      List.build(client, opts),
      client,
      "connect_balance_transfers",
      BalanceTransfer,
      :balance_transfers_list
    )
  end

  def list(%Client{}, _opts), do: configuration_error(:invalid_options)
  def list(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a Connect balance transfer by ID.
  """
  @doc since: "0.5.0"
  @spec get(Client.t(), String.t(), [get_option()]) ::
          {:ok, BalanceTransfer.t()} | {:error, Error.t()}
  def get(client, balance_transfer_id, opts \\ [])

  def get(%Client{} = client, balance_transfer_id, opts)
      when is_binary(balance_transfer_id) and is_list(opts) do
    RequestRunner.run_resource(
      Get.build(client, balance_transfer_id, opts),
      client,
      BalanceTransfer,
      :balance_transfers_get
    )
  end

  def get(%Client{}, _balance_transfer_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, _balance_transfer_id, _opts),
    do: configuration_error(:invalid_balance_transfer_id)

  def get(_client, _balance_transfer_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Creates a Connect balance transfer.
  """
  @doc since: "0.5.0"
  @spec create(Client.t(), map(), [create_option()]) ::
          {:ok, BalanceTransfer.t()} | {:error, Error.t()}
  def create(client, params, opts \\ [])

  def create(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    RequestRunner.run_resource(
      Create.build(client, params, opts),
      client,
      BalanceTransfer,
      :balance_transfers_create
    )
  end

  def create(%Client{}, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def create(%Client{}, _params, _opts),
    do: configuration_error(:invalid_balance_transfer_params)

  def create(_client, _params, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
