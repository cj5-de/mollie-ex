defmodule MollieEx.Resources.Customers.ListPayments do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options

  @allowed_options [
    :from,
    :limit,
    :sort,
    :profile_id,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, customer_id, opts)
      when is_binary(customer_id) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         :ok <- reject_api_key_scoped_fields(client, opts),
         {:ok, customer_id} <- Options.customer_id(customer_id),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- Options.limit(opts),
         {:ok, sort} <- Options.sort(opts),
         {:ok, profile_id} <- effective_profile_id(client, opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      request = %Request{
        method: :get,
        path: "/customers/" <> Options.encode_path_segment(customer_id) <> "/payments",
        path_template: "/customers/{customerId}/payments",
        query: query(from, limit, sort, profile_id, testmode),
        idempotency_policy: :unsupported,
        operation: :customers_list_payments,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _customer_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _customer_id, _opts), do: configuration_error(:invalid_customer_id)

  defp reject_api_key_scoped_fields(%Client{auth: {:api_key, _credential}}, opts) do
    cond do
      Keyword.has_key?(opts, :profile_id) ->
        configuration_error(:unsupported_profile_id)

      Keyword.has_key?(opts, :testmode) ->
        configuration_error(:unsupported_testmode)

      true ->
        :ok
    end
  end

  defp reject_api_key_scoped_fields(%Client{}, _opts), do: :ok

  defp effective_profile_id(%Client{auth: {:api_key, _credential}}, _opts), do: {:ok, nil}

  defp effective_profile_id(%Client{} = client, opts) do
    case Keyword.fetch(opts, :profile_id) do
      {:ok, profile_id} -> profile_id
      :error -> client.profile_id
    end
    |> Options.profile_id()
  end

  defp query(from, limit, sort, profile_id, testmode) do
    []
    |> Options.put_query(:from, from)
    |> Options.put_query(:limit, limit)
    |> Options.put_query(:sort, sort)
    |> Options.put_query(:profileId, profile_id)
    |> Options.put_query(:testmode, testmode)
  end

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
