defmodule MollieEx.Resources.Payments.List do
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
    :profile_id,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), keyword()) :: {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, opts) when is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_scoped_fields(client, opts),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- limit(opts),
         {:ok, sort} <- Options.sort(opts),
         {:ok, profile_id} <- Options.effective_profile_id(client, opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: "/payments",
        path_template: "/payments",
        query:
          Options.query(
            from: from,
            limit: limit,
            sort: sort,
            profileId: profile_id,
            testmode: testmode
          ),
        idempotency_policy: :unsupported,
        operation: :payments_list,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _opts), do: Options.configuration_error(:invalid_options)

  defp limit(opts) do
    case Keyword.get(opts, :limit) do
      nil -> {:ok, nil}
      limit when is_integer(limit) and limit > 0 -> {:ok, limit}
      _limit -> Options.configuration_error({:invalid_option, :limit})
    end
  end
end
