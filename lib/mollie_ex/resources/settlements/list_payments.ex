defmodule MollieEx.Resources.Settlements.ListPayments do
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
    :profile_id,
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
         {:ok, sort} <- Options.sort(opts),
         {:ok, profile_id} <- Options.effective_profile_id(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: Options.resource_path(["settlements", settlement_id, "payments"]),
        path_template: "/settlements/{settlementId}/payments",
        query: Options.query(from: from, limit: limit, sort: sort, profileId: profile_id),
        idempotency_policy: :unsupported,
        operation: :settlements_list_payments
      )
    end
  end

  def build(%Client{}, _settlement_id, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _settlement_id, _opts),
    do: Options.configuration_error(:invalid_settlement_id)
end
