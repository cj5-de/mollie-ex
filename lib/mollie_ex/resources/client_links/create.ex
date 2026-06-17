defmodule MollieEx.Resources.ClientLinks.Create do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Casing
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :idempotency_key,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]
  @structured_body_keys ~w(owner address)

  @spec build(Client.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, params, opts)
      when is_map(params) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.require_organization_token_client(client),
         :ok <- Options.require_param(params, [:owner, "owner"], :missing_owner),
         :ok <- Options.require_param(params, [:name, "name"], :missing_name),
         :ok <- Options.require_param(params, [:address, "address"], :missing_address) do
      RequestBuilder.build(opts,
        method: :post,
        path: "/client-links",
        path_template: "/client-links",
        body: Casing.to_mollie_body(params, @structured_body_keys),
        idempotency_policy: :optional,
        operation: :client_links_create
      )
    end
  end

  def build(%Client{}, _params, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _params, _opts),
    do: Options.configuration_error(:invalid_client_link_params)
end
