defmodule MollieEx.Permissions do
  @moduledoc """
  Retrieve Mollie OAuth permissions.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Permission
  alias MollieEx.Resources.Permissions.{Get, List}
  alias MollieEx.Resources.RequestRunner

  @type list_option ::
          {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Lists permissions available to the current access token.
  """
  @doc since: "0.5.0"
  @spec list(Client.t(), [list_option()]) ::
          {:ok, MollieList.t(Permission.t())} | {:error, Error.t()}
  def list(client, opts \\ [])

  def list(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource_list(
      List.build(client, opts),
      client,
      "permissions",
      Permission,
      :permissions_list
    )
  end

  def list(%Client{}, _opts), do: configuration_error(:invalid_options)
  def list(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a permission by ID.
  """
  @doc since: "0.5.0"
  @spec get(Client.t(), String.t(), [get_option()]) ::
          {:ok, Permission.t()} | {:error, Error.t()}
  def get(client, permission_id, opts \\ [])

  def get(%Client{} = client, permission_id, opts)
      when is_binary(permission_id) and is_list(opts) do
    RequestRunner.run_resource(
      Get.build(client, permission_id, opts),
      client,
      Permission,
      :permissions_get
    )
  end

  def get(%Client{}, _permission_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, _permission_id, _opts),
    do: configuration_error(:invalid_permission_id)

  def get(_client, _permission_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
