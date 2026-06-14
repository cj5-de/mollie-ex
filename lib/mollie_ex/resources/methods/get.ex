defmodule MollieEx.Resources.Methods.Get do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :currency,
    :include,
    :locale,
    :profile_id,
    :sequence_type,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, method_id, opts)
      when is_binary(method_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         {:ok, method_id} <- Options.method_id(method_id),
         {:ok, query} <- query(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: Options.resource_path(["methods", method_id]),
        path_template: "/methods/{methodId}",
        query: query,
        idempotency_policy: :unsupported,
        operation: :methods_get,
        testmode: Keyword.get(query, :testmode)
      )
    end
  end

  def build(%Client{}, _method_id, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _method_id, _opts), do: Options.configuration_error(:invalid_method_id)

  defp query(%Client{} = client, opts) do
    with :ok <- Options.reject_api_key_scoped_fields(client, opts),
         {:ok, currency} <- Options.string_query_option(opts, :currency),
         {:ok, include} <- Options.string_option(opts, :include),
         {:ok, locale} <- Options.string_query_option(opts, :locale),
         {:ok, sequence_type} <- Options.string_query_option(opts, :sequence_type),
         {:ok, profile_id} <- Options.effective_profile_id(client, opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      {:ok,
       Options.query(
         currency: currency,
         include: include,
         locale: locale,
         profileId: profile_id,
         sequenceType: sequence_type,
         testmode: testmode
       )}
    end
  end
end
