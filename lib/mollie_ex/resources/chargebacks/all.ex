defmodule MollieEx.Resources.Chargebacks.All do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :from,
    :limit,
    :sort,
    :embed,
    :profile_id,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), keyword()) :: {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, opts) when is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         :ok <- Options.reject_api_key_scoped_fields(client, opts),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- Options.limit(opts),
         {:ok, sort} <- Options.sort(opts),
         {:ok, embed} <- Options.string_option(opts, :embed),
         {:ok, profile_id} <- effective_profile_id(client, opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: "/chargebacks",
        path_template: "/chargebacks",
        query:
          Options.query(
            from: from,
            limit: limit,
            sort: sort,
            embed: embed,
            profileId: profile_id,
            testmode: testmode
          ),
        idempotency_policy: :unsupported,
        operation: :chargebacks_all,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _opts), do: configuration_error(:invalid_options)

  defp effective_profile_id(%Client{auth: {:api_key, _credential}}, _opts), do: {:ok, nil}

  defp effective_profile_id(%Client{} = client, opts) do
    case Keyword.fetch(opts, :profile_id) do
      {:ok, profile_id} -> profile_id
      :error -> client.profile_id
    end
    |> optional_profile_id()
  end

  defp optional_profile_id(nil), do: {:ok, nil}
  defp optional_profile_id(profile_id), do: Options.profile_id(profile_id)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
