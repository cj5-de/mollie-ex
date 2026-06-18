defmodule MollieEx.Resources.Settlements.ListCaptures do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :from,
    :limit,
    :embed,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, settlement_id, opts)
      when is_binary(settlement_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client),
         {:ok, settlement_id} <- Options.settlement_id(settlement_id),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- Options.limit(opts),
         {:ok, embed} <- Options.string_query_option(opts, :embed) do
      RequestBuilder.build(opts,
        method: :get,
        path: Options.resource_path(["settlements", settlement_id, "captures"]),
        path_template: "/settlements/{settlementId}/captures",
        query: Options.query(from: from, limit: limit, embed: embed),
        idempotency_policy: :unsupported,
        operation: :settlements_list_captures
      )
    end
  end

  def build(%Client{}, _settlement_id, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _settlement_id, _opts),
    do: Options.configuration_error(:invalid_settlement_id)
end
