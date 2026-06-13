defmodule MollieEx.Resources.Options do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error

  @timeout_options [:pool_timeout, :receive_timeout, :request_timeout]

  @spec ensure_keyword(keyword() | term()) :: :ok | {:error, Error.t()}
  def ensure_keyword(opts) when is_list(opts) do
    if Keyword.keyword?(opts), do: :ok, else: configuration_error(:invalid_options)
  end

  def ensure_keyword(_opts), do: configuration_error(:invalid_options)

  @spec reject_unknown(keyword(), [atom()]) :: :ok | {:error, Error.t()}
  def reject_unknown(opts, allowed) do
    case opts |> Keyword.keys() |> Enum.reject(&(&1 in allowed)) do
      [] -> :ok
      [key | _keys] -> configuration_error({:unsupported_option, key})
    end
  end

  @spec string_option(keyword(), atom()) :: {:ok, String.t() | nil} | {:error, Error.t()}
  def string_option(opts, key) do
    case Keyword.get(opts, key) do
      nil -> {:ok, nil}
      value when is_binary(value) -> {:ok, value}
      _value -> configuration_error({:invalid_option, key})
    end
  end

  @spec string_query_option(keyword(), atom()) :: {:ok, String.t() | nil} | {:error, Error.t()}
  def string_query_option(opts, key) do
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

  @spec limit(keyword()) :: {:ok, pos_integer() | nil} | {:error, Error.t()}
  def limit(opts) do
    case Keyword.get(opts, :limit) do
      nil -> {:ok, nil}
      limit when is_integer(limit) and limit in 1..250 -> {:ok, limit}
      _limit -> configuration_error({:invalid_option, :limit})
    end
  end

  @spec sort(keyword()) :: {:ok, String.t() | nil} | {:error, Error.t()}
  def sort(opts) do
    case Keyword.get(opts, :sort) do
      nil -> {:ok, nil}
      :asc -> {:ok, "asc"}
      :desc -> {:ok, "desc"}
      "asc" -> {:ok, "asc"}
      "desc" -> {:ok, "desc"}
      _sort -> configuration_error({:invalid_option, :sort})
    end
  end

  @spec timeout_options(keyword()) :: keyword()
  def timeout_options(opts), do: Keyword.take(opts, @timeout_options)

  @spec put_query(keyword(), atom(), term()) :: keyword()
  def put_query(query, _key, nil), do: query
  def put_query(query, key, value), do: Keyword.put(query, key, value)

  @spec put_body(map(), String.t(), term()) :: map()
  def put_body(body, _key, nil), do: body
  def put_body(body, key, value), do: Map.put(body, key, value)

  @spec body_testmode(boolean() | nil) :: map() | nil
  def body_testmode(nil), do: nil
  def body_testmode(testmode) when is_boolean(testmode), do: %{"testmode" => testmode}

  @spec drop_testmode(map()) :: map()
  def drop_testmode(body), do: Map.drop(body, ["testmode", :testmode])

  @spec resource_id(String.t(), atom()) :: {:ok, String.t()} | {:error, Error.t()}
  def resource_id(id, reason) do
    id = String.trim(id)

    if id == "" do
      configuration_error(reason)
    else
      {:ok, id}
    end
  end

  @spec profile_id(term()) :: {:ok, String.t()} | {:error, Error.t()}
  def profile_id(profile_id) when is_binary(profile_id) do
    profile_id = String.trim(profile_id)

    if profile_id == "" do
      configuration_error(:invalid_profile_id)
    else
      {:ok, profile_id}
    end
  end

  def profile_id(nil), do: configuration_error(:missing_profile_id)
  def profile_id(_profile_id), do: configuration_error(:invalid_profile_id)

  @spec effective_testmode(Client.t(), keyword()) ::
          {:ok, boolean() | nil} | {:error, Error.t()}
  def effective_testmode(%Client{auth: {:api_key, _credential}}, opts) do
    if Keyword.has_key?(opts, :testmode) do
      configuration_error(:unsupported_testmode)
    else
      {:ok, nil}
    end
  end

  def effective_testmode(%Client{} = client, opts) do
    opts
    |> Keyword.get(:testmode, client.testmode)
    |> testmode()
  end

  @spec testmode(boolean() | nil | term()) :: {:ok, boolean() | nil} | {:error, Error.t()}
  def testmode(testmode) when is_boolean(testmode), do: {:ok, testmode}
  def testmode(nil), do: {:ok, nil}
  def testmode(_testmode), do: configuration_error(:invalid_testmode)

  @spec encode_path_segment(String.t()) :: String.t()
  def encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)

  @spec configuration_error(term()) :: {:error, Error.t()}
  def configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end

  defp non_empty_string_option("", key), do: configuration_error({:invalid_option, key})
  defp non_empty_string_option(value, _key), do: {:ok, value}
end
