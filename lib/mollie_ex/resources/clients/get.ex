defmodule MollieEx.Resources.Clients.Get do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :embed,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, organization_id, opts)
      when is_binary(organization_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client),
         {:ok, client_id} <- Options.client_id(organization_id),
         {:ok, embed} <- Options.string_query_option(opts, :embed) do
      RequestBuilder.build(opts,
        method: :get,
        path: Options.resource_path(["clients", client_id]),
        path_template: "/clients/{organizationId}",
        query: Options.query(embed: embed),
        idempotency_policy: :unsupported,
        operation: :clients_get
      )
    end
  end

  def build(%Client{}, _organization_id, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _organization_id, _opts),
    do: Options.configuration_error(:invalid_client_id)
end
