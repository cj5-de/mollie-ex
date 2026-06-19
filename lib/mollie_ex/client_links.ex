defmodule MollieEx.ClientLinks do
  @moduledoc """
  Create Mollie client links for partner onboarding.

  Client link creation requires a Mollie advanced access token, represented in
  this SDK as an `:organization_token` client or a `:token_provider` returning
  an organization-level bearer token.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Client
  alias MollieEx.ClientLink
  alias MollieEx.Error
  alias MollieEx.Resources.ClientLinks.Create
  alias MollieEx.Resources.RequestRunner

  @type create_option ::
          {:idempotency_key, String.t()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Creates a client link for onboarding a merchant to an OAuth application.

  This endpoint requires `:organization_token` or `:token_provider` auth.
  """
  @doc since: "0.5.0"
  @spec create(Client.t(), map(), [create_option()]) ::
          {:ok, ClientLink.t()} | {:error, Error.t()}
  def create(client, params, opts \\ [])

  def create(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    RequestRunner.run_resource(
      Create.build(client, params, opts),
      client,
      ClientLink,
      :client_links_create
    )
  end

  def create(%Client{}, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def create(%Client{}, _params, _opts),
    do: configuration_error(:invalid_client_link_params)

  def create(_client, _params, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
