defmodule MollieEx.Resources.Invoices.List do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :reference,
    :year,
    :from,
    :limit,
    :sort,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, opts) when is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client),
         {:ok, reference} <- Options.string_query_option(opts, :reference),
         {:ok, year} <- Options.string_query_option(opts, :year),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- Options.limit(opts),
         {:ok, sort} <- Options.sort(opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: "/invoices",
        path_template: "/invoices",
        query:
          Options.query(
            reference: reference,
            year: year,
            from: from,
            limit: limit,
            sort: sort
          ),
        idempotency_policy: :unsupported,
        operation: :invoices_list
      )
    end
  end

  def build(%Client{}, _opts), do: Options.configuration_error(:invalid_options)
end
