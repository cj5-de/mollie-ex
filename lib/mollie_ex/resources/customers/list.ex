defmodule MollieEx.Resources.Customers.List do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Customers.Options

  @allowed_options [
    :from,
    :limit,
    :sort,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, opts) when is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- Options.limit(opts),
         {:ok, sort} <- Options.sort(opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      request = %Request{
        method: :get,
        path: "/customers",
        path_template: "/customers",
        query: query(from, limit, sort, testmode),
        idempotency_policy: :unsupported,
        operation: :customers_list,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _opts), do: configuration_error(:invalid_options)

  defp query(from, limit, sort, testmode) do
    []
    |> Options.put_query(:from, from)
    |> Options.put_query(:limit, limit)
    |> Options.put_query(:sort, sort)
    |> Options.put_query(:testmode, testmode)
  end

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
