defmodule MollieEx.Resources.Subscriptions.All do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :from,
    :limit,
    :profile_id,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, opts) when is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_scoped_fields(client, opts),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- Options.limit(opts),
         {:ok, profile_id} <- optional_profile_id(client, opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: "/subscriptions",
        path_template: "/subscriptions",
        query: Options.query(from: from, limit: limit, profileId: profile_id, testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :subscriptions_all,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _opts), do: Options.configuration_error(:invalid_options)

  defp optional_profile_id(%Client{auth: {:api_key, _credential}}, _opts), do: {:ok, nil}

  defp optional_profile_id(%Client{} = client, opts) do
    case Keyword.fetch(opts, :profile_id) do
      {:ok, nil} -> {:ok, nil}
      {:ok, profile_id} -> Options.profile_id(profile_id)
      :error -> {:ok, client.profile_id}
    end
  end
end
