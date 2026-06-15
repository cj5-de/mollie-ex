defmodule MollieEx.Resources.Organizations.Get do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :testmode,
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
         {:ok, organization_id} <- Options.organization_id(organization_id),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: Options.resource_path(["organizations", organization_id]),
        path_template: "/organizations/{organizationId}",
        query: Options.query(testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :organizations_get,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _organization_id, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _organization_id, _opts),
    do: Options.configuration_error(:invalid_organization_id)
end
