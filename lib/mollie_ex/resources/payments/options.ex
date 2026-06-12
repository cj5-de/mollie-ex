defmodule MollieEx.Resources.Payments.Options do
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

  @spec string_option(keyword(), atom()) :: {:ok, String.t() | nil} | {:error, Error.t()}
  def string_option(opts, key) do
    case Keyword.get(opts, key) do
      nil -> {:ok, nil}
      value when is_binary(value) -> {:ok, value}
      _value -> configuration_error({:invalid_option, key})
    end
  end

  @spec timeout_options(keyword()) :: keyword()
  def timeout_options(opts), do: Keyword.take(opts, @timeout_options)

  def configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
