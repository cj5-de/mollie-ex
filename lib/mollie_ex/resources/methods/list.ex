defmodule MollieEx.Resources.Methods.List do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :amount,
    :billing_country,
    :include,
    :include_wallets,
    :locale,
    :order_line_categories,
    :profile_id,
    :resource,
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
        path: "/methods",
        path_template: "/methods",
        query: query,
        idempotency_policy: :unsupported,
        operation: :methods_list,
        testmode: Keyword.get(query, :testmode)
      )
    end
  end

  def build(%Client{}, _opts), do: Options.configuration_error(:invalid_options)

  defp query(%Client{} = client, opts) do
    with :ok <- Options.reject_api_key_scoped_fields(client, opts),
         {:ok, amount} <- amount_query(opts),
         {:ok, billing_country} <- Options.string_query_option(opts, :billing_country),
         {:ok, include} <- Options.string_option(opts, :include),
         {:ok, include_wallets} <- Options.string_query_option(opts, :include_wallets),
         {:ok, locale} <- Options.string_query_option(opts, :locale),
         {:ok, order_line_categories} <-
           Options.string_query_option(opts, :order_line_categories),
         {:ok, resource} <- Options.string_query_option(opts, :resource),
         {:ok, sequence_type} <- Options.string_query_option(opts, :sequence_type),
         {:ok, profile_id} <- Options.effective_profile_id(client, opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      query =
        Options.query(
          billingCountry: billing_country,
          include: include,
          includeWallets: include_wallets,
          locale: locale,
          orderLineCategories: order_line_categories,
          profileId: profile_id,
          resource: resource,
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
