defmodule MollieEx.Resources.BalanceTransfers.Create do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :idempotency_key,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]
  @structured_body_keys ~w(amount source destination)
  @hal_accept "application/hal+json"

  @spec build(Client.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client),
         :ok <- Options.require_param(params, [:amount, "amount"], :missing_amount),
         :ok <- Options.require_param(params, [:source, "source"], :missing_source),
         :ok <-
           Options.require_param(params, [:destination, "destination"], :missing_destination),
         :ok <-
           Options.require_param(params, [:description, "description"], :missing_description),
         {:ok, body, testmode} <-
           Options.body_with_testmode(client, params, opts, @structured_body_keys) do
      RequestBuilder.build(opts,
        method: :post,
        path: "/connect/balance-transfers",
        path_template: "/connect/balance-transfers",
        accept: @hal_accept,
        body: body,
        idempotency_policy: :optional,
        operation: :balance_transfers_create,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _params, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _params, _opts),
    do: Options.configuration_error(:invalid_balance_transfer_params)
end
