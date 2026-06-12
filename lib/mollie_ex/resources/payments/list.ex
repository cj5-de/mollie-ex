defmodule MollieEx.Resources.Payments.List do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Payments.Options

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
         {:ok, from} <- string_query_option(opts, :from),
         {:ok, limit} <- limit(opts),
         {:ok, sort} <- sort(opts),
         {:ok, profile_id} <- effective_profile_id(client, opts),
         {:ok, testmode} <- effective_testmode(client, opts) do
      request = %Request{
        method: :get,
        path: "/payments",
        path_template: "/payments",
        query: query(from, limit, sort, profile_id, testmode),
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

  defp string_query_option(opts, key) do
    case Keyword.get(opts, key) do
      nil ->
        {:ok, nil}

      value when is_binary(value) ->
        value
        |> String.trim()
        |> non_empty_string_option(key)

      _value ->
        configuration_error({:invalid_option, key})
    end
  end

  defp non_empty_string_option("", key), do: configuration_error({:invalid_option, key})
  defp non_empty_string_option(value, _key), do: {:ok, value}

  defp limit(opts) do
    case Keyword.get(opts, :limit) do
      nil -> {:ok, nil}
      limit when is_integer(limit) and limit > 0 -> {:ok, limit}
      _limit -> configuration_error({:invalid_option, :limit})
    end
  end

  defp sort(opts) do
    case Keyword.get(opts, :sort) do
      nil -> {:ok, nil}
      :asc -> {:ok, "asc"}
      :desc -> {:ok, "desc"}
      "asc" -> {:ok, "asc"}
      "desc" -> {:ok, "desc"}
      _sort -> configuration_error({:invalid_option, :sort})
    end
  end

  defp effective_profile_id(%Client{auth: {:api_key, _credential}}, _opts), do: {:ok, nil}

  defp effective_profile_id(%Client{} = client, opts) do
    case Keyword.fetch(opts, :profile_id) do
      {:ok, profile_id} -> profile_id
      :error -> client.profile_id
    end
    |> profile_id()
  end

  defp profile_id(profile_id) when is_binary(profile_id) do
    profile_id = String.trim(profile_id)

    if profile_id == "" do
      configuration_error(:invalid_profile_id)
    else
      {:ok, profile_id}
    end
  end

  defp profile_id(nil), do: configuration_error(:missing_profile_id)
  defp profile_id(_profile_id), do: configuration_error(:invalid_profile_id)

  defp effective_testmode(%Client{auth: {:api_key, _credential}}, _opts), do: {:ok, nil}

  defp effective_testmode(%Client{} = client, opts) do
    opts
    |> Keyword.get(:testmode, client.testmode)
    |> testmode()
  end

  defp testmode(testmode) when is_boolean(testmode), do: {:ok, testmode}
  defp testmode(nil), do: {:ok, nil}
  defp testmode(_testmode), do: configuration_error(:invalid_testmode)

  defp query(from, limit, sort, profile_id, testmode) do
    []
    |> maybe_put(:from, from)
    |> maybe_put(:limit, limit)
    |> maybe_put(:sort, sort)
    |> maybe_put(:profileId, profile_id)
    |> maybe_put(:testmode, testmode)
  end

  defp maybe_put(query, _key, nil), do: query
  defp maybe_put(query, key, value), do: Keyword.put(query, key, value)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
