defmodule MollieEx.Resources.Customers.Options do
  @moduledoc false

  alias MollieEx.Error
  alias MollieEx.Resources.Options, as: SharedOptions

  @spec ensure_keyword(keyword() | term()) :: :ok | {:error, Error.t()}
  defdelegate ensure_keyword(opts), to: SharedOptions

  @spec reject_unknown(keyword(), [atom()]) :: :ok | {:error, Error.t()}
  defdelegate reject_unknown(opts, allowed), to: SharedOptions

  @spec string_query_option(keyword(), atom()) :: {:ok, String.t() | nil} | {:error, Error.t()}
  defdelegate string_query_option(opts, key), to: SharedOptions

  @spec timeout_options(keyword()) :: keyword()
  defdelegate timeout_options(opts), to: SharedOptions

  @spec put_query(keyword(), atom(), term()) :: keyword()
  defdelegate put_query(query, key, value), to: SharedOptions

  @spec put_body(map(), String.t(), term()) :: map()
  defdelegate put_body(body, key, value), to: SharedOptions

  @spec body_testmode(boolean() | nil) :: map() | nil
  defdelegate body_testmode(testmode), to: SharedOptions

  @spec drop_testmode(map()) :: map()
  defdelegate drop_testmode(body), to: SharedOptions

  @spec limit(keyword()) :: {:ok, pos_integer() | nil} | {:error, Error.t()}
  defdelegate limit(opts), to: SharedOptions

  @spec sort(keyword()) :: {:ok, String.t() | nil} | {:error, Error.t()}
  defdelegate sort(opts), to: SharedOptions

  @spec customer_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def customer_id(customer_id), do: SharedOptions.resource_id(customer_id, :invalid_customer_id)

  @spec effective_testmode(MollieEx.Client.t(), keyword()) ::
          {:ok, boolean() | nil} | {:error, Error.t()}
  defdelegate effective_testmode(client, opts), to: SharedOptions

  @spec testmode(boolean() | nil | term()) :: {:ok, boolean() | nil} | {:error, Error.t()}
  defdelegate testmode(testmode), to: SharedOptions

  @spec encode_path_segment(String.t()) :: String.t()
  defdelegate encode_path_segment(value), to: SharedOptions

  @spec configuration_error(term()) :: {:error, Error.t()}
  defdelegate configuration_error(reason), to: SharedOptions
end
