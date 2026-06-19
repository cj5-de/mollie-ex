defmodule MollieEx.Clients do
  @moduledoc """
  Retrieve Mollie partner clients.

  These endpoints require a Mollie advanced access token, represented in this
  SDK as an `:organization_token` client or a `:token_provider` returning an
  organization-level bearer token.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Client
  alias MollieEx.ClientResource
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Resources.Clients.{Get, List}
  alias MollieEx.Resources.RequestRunner

  @type list_option ::
          {:embed, String.t()}
          | {:from, String.t()}
          | {:limit, pos_integer()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:embed, String.t()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Lists clients linked to the authenticated account.

  This endpoint requires `:organization_token` or `:token_provider` auth.
  """
  @doc since: "0.5.0"
  @spec list(Client.t(), [list_option()]) ::
          {:ok, MollieList.t(ClientResource.t())} | {:error, Error.t()}
  def list(client, opts \\ [])

  def list(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource_list(
      List.build(client, opts),
      client,
      "clients",
      ClientResource,
      :clients_list
    )
  end

  def list(%Client{}, _opts), do: configuration_error(:invalid_options)
  def list(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a client by organization ID.

  This endpoint requires `:organization_token` or `:token_provider` auth.
  """
  @doc since: "0.5.0"
  @spec get(Client.t(), String.t(), [get_option()]) ::
          {:ok, ClientResource.t()} | {:error, Error.t()}
  def get(client, organization_id, opts \\ [])

  def get(%Client{} = client, organization_id, opts)
      when is_binary(organization_id) and is_list(opts) do
    RequestRunner.run_resource(
      Get.build(client, organization_id, opts),
      client,
      ClientResource,
      :clients_get
    )
  end

  def get(%Client{}, _organization_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, _organization_id, _opts),
    do: configuration_error(:invalid_client_id)

  def get(_client, _organization_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
