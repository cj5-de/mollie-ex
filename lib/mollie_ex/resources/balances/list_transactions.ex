defmodule MollieEx.Resources.Balances.ListTransactions do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :from,
    :limit,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, balance_id, opts)
      when is_binary(balance_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client),
         {:ok, balance_id} <- Options.balance_id(balance_id),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- Options.limit(opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: Options.resource_path(["balances", balance_id, "transactions"]),
        path_template: "/balances/{balanceId}/transactions",
        query: Options.query(from: from, limit: limit, testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :balances_list_transactions,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _balance_id, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _balance_id, _opts),
    do: Options.configuration_error(:invalid_balance_id)
end
