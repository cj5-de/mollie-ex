defmodule MollieEx.Resources.Profiles.Get do
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
  def build(%Client{} = client, profile_id, opts)
      when is_binary(profile_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client),
         {:ok, profile_id} <- Options.profile_id(profile_id),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: Options.resource_path(["profiles", profile_id]),
        path_template: "/profiles/{profileId}",
        query: Options.query(testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :profiles_get,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _profile_id, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _profile_id, _opts), do: Options.configuration_error(:invalid_profile_id)
end
