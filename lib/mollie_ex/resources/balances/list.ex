defmodule MollieEx.Resources.Balances.List do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :currency,
    :from,
    :limit,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, opts) when is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client),
         {:ok, currency} <- Options.string_query_option(opts, :currency),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- Options.limit(opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: "/balances",
        path_template: "/balances",
        query: Options.query(currency: currency, from: from, limit: limit, testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :balances_list,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _opts), do: Options.configuration_error(:invalid_options)
end
