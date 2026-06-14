defmodule MollieEx.Chargebacks do
  @moduledoc """
  Retrieve and list Mollie chargebacks.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.

  ```elixir
  {:ok, chargeback} = MollieEx.Chargebacks.get(client, "tr_123", "chb_123")
  {:ok, chargebacks} = MollieEx.Chargebacks.list(client, "tr_123", limit: 10)
  ```
  """
  @moduledoc since: "0.2.0"

  alias MollieEx.Chargeback
  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Resources.Chargebacks.{All, Get}
  alias MollieEx.Resources.Chargebacks.List, as: ListRequest
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
  Lists all Mollie chargebacks.

  This is the top-level chargeback list endpoint. Use `list/3` to list
  chargebacks for a specific payment.
  """
  @doc since: "0.3.0"
  @spec all(Client.t(), [all_option()]) ::
          {:ok, MollieList.t(Chargeback.t())} | {:error, Error.t()}
  def all(client, opts \\ [])

  def all(%Client{} = client, opts) when is_list(opts) do
    with {:ok, request, transport_opts} <- All.build(client, opts) do
      RequestRunner.decode_resource_list(
        client,
        request,
        transport_opts,
        "chargebacks",
        Chargeback,
        :chargebacks_all
      )
    end
  end

  def all(%Client{}, _opts), do: configuration_error(:invalid_options)
  def all(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a Mollie chargeback by payment ID and chargeback ID.
  """
  @doc since: "0.2.0"
  @spec get(Client.t(), String.t(), String.t(), [get_option()]) ::
          {:ok, Chargeback.t()} | {:error, Error.t()}
  def get(client, payment_id, chargeback_id, opts \\ [])

  def get(%Client{} = client, payment_id, chargeback_id, opts)
      when is_binary(payment_id) and is_binary(chargeback_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- Get.build(client, payment_id, chargeback_id, opts) do
      RequestRunner.decode_resource(client, request, transport_opts, Chargeback, :chargebacks_get)
    end
  end

  def get(%Client{}, _payment_id, _chargeback_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, payment_id, _chargeback_id, _opts) when not is_binary(payment_id),
    do: configuration_error(:invalid_payment_id)

  def get(%Client{}, _payment_id, _chargeback_id, _opts),
    do: configuration_error(:invalid_chargeback_id)

  def get(_client, _payment_id, _chargeback_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Lists Mollie chargebacks for a payment.
  """
  @doc since: "0.2.0"
  @spec list(Client.t(), String.t(), [list_option()]) ::
          {:ok, MollieList.t(Chargeback.t())} | {:error, Error.t()}
  def list(client, payment_id, opts \\ [])

  def list(%Client{} = client, payment_id, opts) when is_binary(payment_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- ListRequest.build(client, payment_id, opts) do
      RequestRunner.decode_resource_list(
        client,
        request,
        transport_opts,
        "chargebacks",
        Chargeback,
        :chargebacks_list
      )
    end
  end

  def list(%Client{}, _payment_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def list(%Client{}, _payment_id, _opts), do: configuration_error(:invalid_payment_id)
  def list(_client, _payment_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
