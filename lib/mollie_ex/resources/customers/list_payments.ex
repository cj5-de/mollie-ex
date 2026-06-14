defmodule MollieEx.Resources.Customers.ListPayments do
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

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, customer_id, opts)
      when is_binary(customer_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_scoped_fields(client, opts),
         {:ok, customer_id} <- Options.customer_id(customer_id),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- Options.limit(opts),
         {:ok, sort} <- Options.sort(opts),
         {:ok, profile_id} <- Options.effective_profile_id(client, opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: "/customers/" <> Options.encode_path_segment(customer_id) <> "/payments",
        path_template: "/customers/{customerId}/payments",
        query:
          Options.query(
            from: from,
            limit: limit,
            sort: sort,
            profileId: profile_id,
            testmode: testmode
          ),
        idempotency_policy: :unsupported,
        operation: :customers_list_payments,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _customer_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _customer_id, _opts), do: configuration_error(:invalid_customer_id)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
