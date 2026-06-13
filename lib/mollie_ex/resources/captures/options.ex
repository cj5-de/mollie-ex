defmodule MollieEx.Resources.Captures.Options do
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

  @spec limit(keyword()) :: {:ok, pos_integer() | nil} | {:error, Error.t()}
  defdelegate limit(opts), to: SharedOptions

  @spec timeout_options(keyword()) :: keyword()
  defdelegate timeout_options(opts), to: SharedOptions

  @spec payment_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def payment_id(payment_id), do: SharedOptions.resource_id(payment_id, :invalid_payment_id)

  @spec capture_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def capture_id(capture_id), do: SharedOptions.resource_id(capture_id, :invalid_capture_id)

  @spec effective_testmode(MollieEx.Client.t(), keyword()) ::
          {:ok, boolean() | nil} | {:error, Error.t()}
  defdelegate effective_testmode(client, opts), to: SharedOptions

  @spec encode_path_segment(String.t()) :: String.t()
  defdelegate encode_path_segment(value), to: SharedOptions

  @spec configuration_error(term()) :: {:error, Error.t()}
  defdelegate configuration_error(reason), to: SharedOptions

  @spec testmode(boolean() | nil | term()) :: {:ok, boolean() | nil} | {:error, Error.t()}
  defdelegate testmode(testmode), to: SharedOptions
end
