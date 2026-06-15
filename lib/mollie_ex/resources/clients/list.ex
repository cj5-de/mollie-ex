defmodule MollieEx.Resources.Clients.List do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :embed,
    :from,
    :limit,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, opts) when is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client),
         {:ok, embed} <- Options.string_query_option(opts, :embed),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- Options.limit(opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: "/clients",
        path_template: "/clients",
        query: Options.query(embed: embed, from: from, limit: limit),
        idempotency_policy: :unsupported,
        operation: :clients_list
      )
    end
  end

  def build(%Client{}, _opts), do: Options.configuration_error(:invalid_options)
end
