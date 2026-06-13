defmodule MollieEx.Resources.Payments.Options do
  @moduledoc false

  alias MollieEx.Error
  alias MollieEx.Resources.Options, as: SharedOptions

  @spec ensure_keyword(keyword() | term()) :: :ok | {:error, Error.t()}
  defdelegate ensure_keyword(opts), to: SharedOptions

  @spec reject_unknown(keyword(), [atom()]) :: :ok | {:error, Error.t()}
  defdelegate reject_unknown(opts, allowed), to: SharedOptions

  @spec string_option(keyword(), atom()) :: {:ok, String.t() | nil} | {:error, Error.t()}
  defdelegate string_option(opts, key), to: SharedOptions

  @spec string_query_option(keyword(), atom()) :: {:ok, String.t() | nil} | {:error, Error.t()}
  defdelegate string_query_option(opts, key), to: SharedOptions

  @spec sort(keyword()) :: {:ok, String.t() | nil} | {:error, Error.t()}
  defdelegate sort(opts), to: SharedOptions

  @spec timeout_options(keyword()) :: keyword()
  defdelegate timeout_options(opts), to: SharedOptions

  @spec profile_id(term()) :: {:ok, String.t()} | {:error, Error.t()}
  defdelegate profile_id(profile_id), to: SharedOptions

  @spec effective_testmode(MollieEx.Client.t(), keyword()) ::
          {:ok, boolean() | nil} | {:error, Error.t()}
  defdelegate effective_testmode(client, opts), to: SharedOptions

  @spec testmode(boolean() | nil | term()) :: {:ok, boolean() | nil} | {:error, Error.t()}
  defdelegate testmode(testmode), to: SharedOptions

  @spec configuration_error(term()) :: {:error, Error.t()}
  defdelegate configuration_error(reason), to: SharedOptions
end
