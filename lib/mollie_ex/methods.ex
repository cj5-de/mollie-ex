defmodule MollieEx.Methods do
  @moduledoc """
  Retrieve Mollie payment methods.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.
  """
  @moduledoc since: "0.4.0"

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Method
  alias MollieEx.Resources.Methods.{All, Get}
  alias MollieEx.Resources.Methods.List, as: ListRequest
  alias MollieEx.Resources.RequestRunner

  @type list_option ::
          {:amount, map()}
          | {:billing_country, String.t()}
          | {:include, String.t()}
          | {:include_wallets, String.t()}
          | {:locale, String.t()}
          | {:order_line_categories, String.t()}
          | {:profile_id, String.t()}
          | {:resource, String.t()}
          | {:sequence_type, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type all_option ::
          {:amount, map()}
          | {:include, String.t()}
          | {:locale, String.t()}
          | {:profile_id, String.t()}
          | {:sequence_type, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:currency, String.t()}
          | {:include, String.t()}
          | {:locale, String.t()}
          | {:profile_id, String.t()}
          | {:sequence_type, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Lists enabled Mollie payment methods.
  """
  @doc since: "0.4.0"
  @spec list(Client.t(), [list_option()]) ::
          {:ok, MollieList.t(Method.t())} | {:error, Error.t()}
  def list(client, opts \\ [])

  def list(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource_list(
      ListRequest.build(client, opts),
      client,
      "methods",
      Method,
      :methods_list
    )
  end

  def list(%Client{}, _opts), do: configuration_error(:invalid_options)
  def list(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Lists all Mollie payment methods, including unavailable methods.
  """
  @doc since: "0.4.0"
  @spec all(Client.t(), [all_option()]) ::
          {:ok, MollieList.t(Method.t())} | {:error, Error.t()}
  def all(client, opts \\ [])

  def all(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource_list(
      All.build(client, opts),
      client,
      "methods",
      Method,
      :methods_all
    )
  end

  def all(%Client{}, _opts), do: configuration_error(:invalid_options)
  def all(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a Mollie payment method by ID.
  """
  @doc since: "0.4.0"
  @spec get(Client.t(), String.t(), [get_option()]) ::
          {:ok, Method.t()} | {:error, Error.t()}
  def get(client, method_id, opts \\ [])

  def get(%Client{} = client, method_id, opts)
      when is_binary(method_id) and is_list(opts) do
    RequestRunner.run_resource(
      Get.build(client, method_id, opts),
      client,
      Method,
      :methods_get
    )
  end

  def get(%Client{}, _method_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, _method_id, _opts), do: configuration_error(:invalid_method_id)
  def get(_client, _method_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
