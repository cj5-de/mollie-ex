defmodule MollieEx.Resources.PaymentLinks.List do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.PaymentLinks.Options

  @allowed_options [
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
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- Options.limit(opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      request = %Request{
        method: :get,
        path: "/payment-links",
        path_template: "/payment-links",
        query: query(from, limit, testmode),
        idempotency_policy: :unsupported,
        operation: :payment_links_list,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _opts), do: configuration_error(:invalid_options)

  defp query(from, limit, testmode) do
    []
    |> maybe_put(:from, from)
    |> maybe_put(:limit, limit)
    |> maybe_put(:testmode, testmode)
  end

  defp maybe_put(query, _key, nil), do: query
  defp maybe_put(query, key, value), do: Keyword.put(query, key, value)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
