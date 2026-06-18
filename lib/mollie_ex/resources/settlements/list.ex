defmodule MollieEx.Resources.Settlements.List do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :from,
    :limit,
    :balance_id,
    :year,
    :month,
    :currencies,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, opts) when is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- Options.limit(opts),
         {:ok, balance_id} <- Options.string_query_option(opts, :balance_id),
         {:ok, year} <- Options.string_query_option(opts, :year),
         {:ok, month} <- Options.string_query_option(opts, :month),
         {:ok, currencies} <- Options.string_query_option(opts, :currencies) do
      RequestBuilder.build(opts,
        method: :get,
        path: "/settlements",
        path_template: "/settlements",
        query:
          Options.query(
            from: from,
            limit: limit,
            balanceId: balance_id,
            year: year,
            month: month,
            currencies: currencies
          ),
        idempotency_policy: :unsupported,
        operation: :settlements_list
      )
    end
  end

  def build(%Client{}, _opts), do: Options.configuration_error(:invalid_options)
end
