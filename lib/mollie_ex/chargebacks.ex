defmodule MollieEx.Chargebacks do
  @moduledoc """
  Retrieve and list Mollie payment chargebacks.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.

  ```elixir
  {:ok, chargeback} = MollieEx.Chargebacks.get(client, "tr_123", "chb_123")
  {:ok, chargebacks} = MollieEx.Chargebacks.list(client, "tr_123", limit: 10)
  ```
  """
  @moduledoc since: "0.1.0"

  alias MollieEx.Chargeback
  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Resources.Chargebacks.Get
  alias MollieEx.Resources.Chargebacks.List, as: ListRequest
  alias MollieEx.Resources.RequestRunner

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
  Retrieves a Mollie chargeback by payment ID and chargeback ID.
  """
  @doc since: "0.1.0"
  @spec get(Client.t(), String.t(), String.t(), [get_option()]) ::
          {:ok, Chargeback.t()} | {:error, Error.t()}
  def get(client, payment_id, chargeback_id, opts \\ [])

  def get(%Client{} = client, payment_id, chargeback_id, opts)
      when is_binary(payment_id) and is_binary(chargeback_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- Get.build(client, payment_id, chargeback_id, opts) do
      request_chargeback(client, request, transport_opts, :chargebacks_get)
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
  @doc since: "0.1.0"
  @spec list(Client.t(), String.t(), [list_option()]) ::
          {:ok, MollieList.t(Chargeback.t())} | {:error, Error.t()}
  def list(client, payment_id, opts \\ [])

  def list(%Client{} = client, payment_id, opts) when is_binary(payment_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- ListRequest.build(client, payment_id, opts) do
      request_chargeback_list(client, request, transport_opts)
    end
  end

  def list(%Client{}, _payment_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def list(%Client{}, _payment_id, _opts), do: configuration_error(:invalid_payment_id)
  def list(_client, _payment_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end

  defp request_chargeback(%Client{} = client, request, transport_opts, operation) do
    RequestRunner.decode(
      client,
      request,
      transport_opts,
      &Chargeback.from_response(&1, operation)
    )
  end

  defp request_chargeback_list(%Client{} = client, request, transport_opts) do
    RequestRunner.decode_list(
      client,
      request,
      transport_opts,
      "chargebacks",
      :chargebacks_list,
      &Chargeback.from_response(&1, :chargebacks_list)
    )
  end
end
