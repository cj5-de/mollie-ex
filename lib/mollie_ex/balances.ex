defmodule MollieEx.Balances do
  @moduledoc """
  Retrieve Mollie balances.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Balance
  alias MollieEx.BalanceTransaction
  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Resources.Balances.{Get, List, ListTransactions, Primary}
  alias MollieEx.Resources.RequestRunner

  @type list_option ::
          {:currency, String.t()}
          | {:from, String.t()}
          | {:limit, pos_integer()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type primary_option :: get_option()
  @type transaction_list_option ::
          {:from, String.t()}
          | {:limit, pos_integer()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Lists balances for the current organization.
  """
  @doc since: "0.5.0"
  @spec list(Client.t(), [list_option()]) ::
          {:ok, MollieList.t(Balance.t())} | {:error, Error.t()}
  def list(client, opts \\ [])

  def list(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource_list(
      List.build(client, opts),
      client,
      "balances",
      Balance,
      :balances_list
    )
  end

  def list(%Client{}, _opts), do: configuration_error(:invalid_options)
  def list(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a balance by ID.
  """
  @doc since: "0.5.0"
  @spec get(Client.t(), String.t(), [get_option()]) ::
          {:ok, Balance.t()} | {:error, Error.t()}
  def get(client, balance_id, opts \\ [])

  def get(%Client{} = client, balance_id, opts) when is_binary(balance_id) and is_list(opts) do
    RequestRunner.run_resource(
      Get.build(client, balance_id, opts),
      client,
      Balance,
      :balances_get
    )
  end

  def get(%Client{}, _balance_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, _balance_id, _opts),
    do: configuration_error(:invalid_balance_id)

  def get(_client, _balance_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves the primary balance for the current organization.
  """
  @doc since: "0.5.0"
  @spec primary(Client.t(), [primary_option()]) ::
          {:ok, Balance.t()} | {:error, Error.t()}
  def primary(client, opts \\ [])

  def primary(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource(
      Primary.build(client, opts),
      client,
      Balance,
      :balances_primary
    )
  end

  def primary(%Client{}, _opts), do: configuration_error(:invalid_options)
  def primary(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Lists transactions for a balance.

  Pass `"primary"` as the balance ID to list transactions for the primary
  balance.
  """
  @doc since: "0.5.0"
  @spec list_transactions(Client.t(), String.t(), [transaction_list_option()]) ::
          {:ok, MollieList.t(BalanceTransaction.t())} | {:error, Error.t()}
  def list_transactions(client, balance_id, opts \\ [])

  def list_transactions(%Client{} = client, balance_id, opts)
      when is_binary(balance_id) and is_list(opts) do
    RequestRunner.run_resource_list(
      ListTransactions.build(client, balance_id, opts),
      client,
      "balance_transactions",
      BalanceTransaction,
      :balances_list_transactions
    )
  end

  def list_transactions(%Client{}, _balance_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def list_transactions(%Client{}, _balance_id, _opts),
    do: configuration_error(:invalid_balance_id)

  def list_transactions(_client, _balance_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
