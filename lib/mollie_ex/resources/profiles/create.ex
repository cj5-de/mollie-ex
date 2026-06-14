defmodule MollieEx.Resources.Profiles.Create do
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

  @spec build(Client.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, params, opts)
      when is_map(params) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client) do
      RequestBuilder.build(opts,
        method: :post,
        path: "/profiles",
        path_template: "/profiles",
        body: Casing.to_mollie_body(params, []),
        idempotency_policy: :optional,
        operation: :profiles_create
      )
    end
  end

  def build(%Client{}, _params, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _params, _opts), do: Options.configuration_error(:invalid_profile_params)
end
