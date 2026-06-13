defmodule MollieEx.Resources.PaymentLinks.Options do
  @moduledoc false

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

  @spec timeout_options(keyword()) :: keyword()
  def timeout_options(opts), do: Keyword.take(opts, @timeout_options)

  @spec payment_link_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def payment_link_id(payment_link_id), do: resource_id(payment_link_id, :invalid_payment_link_id)

  @spec effective_testmode(MollieEx.Client.t(), keyword()) ::
          {:ok, boolean() | nil} | {:error, Error.t()}
  def effective_testmode(%MollieEx.Client{auth: {:api_key, _credential}}, opts) do
    if Keyword.has_key?(opts, :testmode) do
      configuration_error(:unsupported_testmode)
    else
      {:ok, nil}
    end
  end

  def effective_testmode(%MollieEx.Client{} = client, opts) do
    opts
    |> Keyword.get(:testmode, client.testmode)
    |> testmode()
  end

  @spec profile_id(String.t() | nil | term()) :: {:ok, String.t() | nil} | {:error, Error.t()}
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

  @spec testmode(boolean() | nil | term()) :: {:ok, boolean() | nil} | {:error, Error.t()}
  def testmode(testmode) when is_boolean(testmode), do: {:ok, testmode}
  def testmode(nil), do: {:ok, nil}
  def testmode(_testmode), do: configuration_error(:invalid_testmode)

  @spec encode_path_segment(String.t()) :: String.t()
  def encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)

  def configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end

  defp resource_id(id, reason) do
    id = String.trim(id)

    if id == "" do
      configuration_error(reason)
    else
      {:ok, id}
    end
  end

  defp non_empty_string_option("", key), do: configuration_error({:invalid_option, key})
  defp non_empty_string_option(value, _key), do: {:ok, value}
end
