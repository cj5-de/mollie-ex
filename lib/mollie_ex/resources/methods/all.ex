defmodule MollieEx.Resources.Methods.All do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :amount,
    :include,
    :locale,
    :profile_id,
    :sequence_type,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, opts) when is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         {:ok, query} <- query(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: "/methods/all",
        path_template: "/methods/all",
        query: query,
        idempotency_policy: :unsupported,
        operation: :methods_all,
        testmode: Keyword.get(query, :testmode)
      )
    end
  end

  def build(%Client{}, _opts), do: Options.configuration_error(:invalid_options)

  defp query(%Client{} = client, opts) do
    with :ok <- Options.reject_api_key_scoped_fields(client, opts),
         {:ok, amount} <- amount_query(opts),
         {:ok, include} <- Options.string_option(opts, :include),
         {:ok, locale} <- Options.string_query_option(opts, :locale),
         {:ok, sequence_type} <- Options.string_query_option(opts, :sequence_type),
         {:ok, profile_id} <- Options.effective_profile_id(client, opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      query =
        Options.query(
          include: include,
          locale: locale,
          profileId: profile_id,
          sequenceType: sequence_type,
          testmode: testmode
        ) ++ amount

      {:ok, query}
    end
  end

  defp amount_query(opts) do
    case Keyword.get(opts, :amount) do
      nil ->
        {:ok, []}

      %{} = amount ->
        value = Map.get(amount, :value) || Map.get(amount, "value")
        currency = Map.get(amount, :currency) || Map.get(amount, "currency")

        if valid_amount_part?(value) and valid_amount_part?(currency) do
          {:ok, [{"amount[value]", value}, {"amount[currency]", currency}]}
        else
          Options.configuration_error({:invalid_option, :amount})
        end

      _amount ->
        Options.configuration_error({:invalid_option, :amount})
    end
  end

  defp valid_amount_part?(value), do: is_binary(value) and String.trim(value) != ""
end
