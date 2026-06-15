defmodule MollieEx.Organizations do
  @moduledoc """
  Retrieve Mollie organizations and partner status.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.Organization
  alias MollieEx.Partner
  alias MollieEx.Resources.Organizations.{Current, Get, PartnerStatus}
  alias MollieEx.Resources.RequestRunner

  @type get_option ::
          {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type option ::
          {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Retrieves an organization by ID.
  """
  @doc since: "0.5.0"
  @spec get(Client.t(), String.t(), [get_option()]) ::
          {:ok, Organization.t()} | {:error, Error.t()}
  def get(client, organization_id, opts \\ [])

  def get(%Client{} = client, organization_id, opts)
      when is_binary(organization_id) and is_list(opts) do
    RequestRunner.run_resource(
      Get.build(client, organization_id, opts),
      client,
      Organization,
      :organizations_get
    )
  end

  def get(%Client{}, _organization_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, _organization_id, _opts),
    do: configuration_error(:invalid_organization_id)

  def get(_client, _organization_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves the currently authenticated organization.
  """
  @doc since: "0.5.0"
  @spec current(Client.t(), [option()]) :: {:ok, Organization.t()} | {:error, Error.t()}
  def current(client, opts \\ [])

  def current(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource(
      Current.build(client, opts),
      client,
      Organization,
      :organizations_current
    )
  end

  def current(%Client{}, _opts), do: configuration_error(:invalid_options)
  def current(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves the partner status for the currently authenticated organization.
  """
  @doc since: "0.5.0"
  @spec partner_status(Client.t(), [option()]) :: {:ok, Partner.t()} | {:error, Error.t()}
  def partner_status(client, opts \\ [])

  def partner_status(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource(
      PartnerStatus.build(client, opts),
      client,
      Partner,
      :organizations_partner_status
    )
  end

  def partner_status(%Client{}, _opts), do: configuration_error(:invalid_options)
  def partner_status(_client, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
