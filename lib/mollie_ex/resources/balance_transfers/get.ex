defmodule MollieEx.Resources.BalanceTransfers.Get do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]
  @hal_accept "application/hal+json"

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, balance_transfer_id, opts)
      when is_binary(balance_transfer_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client),
         {:ok, balance_transfer_id} <- Options.balance_transfer_id(balance_transfer_id),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: Options.resource_path(["connect", "balance-transfers", balance_transfer_id]),
        path_template: "/connect/balance-transfers/{balanceTransferId}",
        accept: @hal_accept,
        query: Options.query(testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :balance_transfers_get,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _balance_transfer_id, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _balance_transfer_id, _opts),
    do: Options.configuration_error(:invalid_balance_transfer_id)
end
