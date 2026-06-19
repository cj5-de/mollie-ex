defmodule MollieEx.Resources.BalanceTransfers.List do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :from,
    :limit,
    :sort,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]
  @hal_accept "application/hal+json"

  @spec build(Client.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, opts) when is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- Options.limit(opts),
         {:ok, sort} <- Options.sort(opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: "/connect/balance-transfers",
        path_template: "/connect/balance-transfers",
        accept: @hal_accept,
        query: Options.query(from: from, limit: limit, sort: sort, testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :balance_transfers_list,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _opts), do: Options.configuration_error(:invalid_options)
end
