defmodule MollieEx.Settlements do
  @moduledoc """
  Retrieve Mollie settlements.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Resources.RequestRunner
  alias MollieEx.Resources.Settlements.{Get, List, Next, Open}
  alias MollieEx.Settlement

  @type list_option ::
          {:from, String.t()}
          | {:limit, pos_integer()}
          | {:balance_id, String.t()}
          | {:year, String.t()}
          | {:month, String.t()}
          | {:currencies, String.t()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type open_option :: get_option()
  @type next_option :: get_option()

  @doc """
  Lists settlements for the current organization.
  """
  @doc since: "0.5.0"
  @spec list(Client.t(), [list_option()]) ::
          {:ok, MollieList.t(Settlement.t())} | {:error, Error.t()}
  def list(client, opts \\ [])

  def list(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource_list(
      List.build(client, opts),
      client,
      "settlements",
      Settlement,
      :settlements_list
    )
  end

  def list(%Client{}, _opts), do: configuration_error(:invalid_options)
  def list(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a settlement by ID or bank reference.
  """
  @doc since: "0.5.0"
  @spec get(Client.t(), String.t(), [get_option()]) ::
          {:ok, Settlement.t()} | {:error, Error.t()}
  def get(client, settlement_id, opts \\ [])

  def get(%Client{} = client, settlement_id, opts)
      when is_binary(settlement_id) and is_list(opts) do
    RequestRunner.run_resource(
      Get.build(client, settlement_id, opts),
      client,
      Settlement,
      :settlements_get
    )
  end

  def get(%Client{}, _settlement_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, _settlement_id, _opts),
    do: configuration_error(:invalid_settlement_id)

  def get(_client, _settlement_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves the open settlement representing the current balance.
  """
  @doc since: "0.5.0"
  @spec open(Client.t(), [open_option()]) ::
          {:ok, Settlement.t()} | {:error, Error.t()}
  def open(client, opts \\ [])

  def open(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource(
      Open.build(client, opts),
      client,
      Settlement,
      :settlements_open
    )
  end

  def open(%Client{}, _opts), do: configuration_error(:invalid_options)
  def open(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves the next settlement that has not yet been paid out.
  """
  @doc since: "0.5.0"
  @spec next(Client.t(), [next_option()]) ::
          {:ok, Settlement.t()} | {:error, Error.t()}
  def next(client, opts \\ [])

  def next(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource(
      Next.build(client, opts),
      client,
      Settlement,
      :settlements_next
    )
  end

  def next(%Client{}, _opts), do: configuration_error(:invalid_options)
  def next(_client, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
