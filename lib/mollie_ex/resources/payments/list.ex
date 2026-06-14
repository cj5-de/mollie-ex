defmodule MollieEx.Resources.Payments.List do
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

  @spec build(Client.t(), keyword()) :: {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, opts) when is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         :ok <- reject_api_key_scoped_fields(client, opts),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- limit(opts),
         {:ok, sort} <- Options.sort(opts),
         {:ok, profile_id} <- effective_profile_id(client, opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      request = %Request{
        method: :get,
        path: "/payments",
        path_template: "/payments",
        query:
          Options.query(
            from: from,
            limit: limit,
            sort: sort,
            profileId: profile_id,
            testmode: testmode
          ),
        idempotency_policy: :unsupported,
        operation: :payments_list,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _opts), do: configuration_error(:invalid_options)

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

  defp limit(opts) do
    case Keyword.get(opts, :limit) do
      nil -> {:ok, nil}
      limit when is_integer(limit) and limit > 0 -> {:ok, limit}
      _limit -> configuration_error({:invalid_option, :limit})
    end
  end

  defp effective_profile_id(%Client{auth: {:api_key, _credential}}, _opts), do: {:ok, nil}

  defp effective_profile_id(%Client{} = client, opts) do
    case Keyword.fetch(opts, :profile_id) do
      {:ok, profile_id} -> profile_id
      :error -> client.profile_id
    end
    |> Options.profile_id()
  end

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
