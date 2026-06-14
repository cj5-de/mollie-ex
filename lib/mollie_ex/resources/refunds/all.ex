defmodule MollieEx.Resources.Refunds.All do
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
         {:ok, profile_id} <- Options.effective_profile_id(client, opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: "/refunds",
        path_template: "/refunds",
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
        operation: :refunds_all,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _opts), do: configuration_error(:invalid_options)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
