defmodule MollieEx.Resources.Customers.Get do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :include,
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
         {:ok, customer_id} <- Options.customer_id(customer_id),
         {:ok, include} <- Options.string_query_option(opts, :include),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: "/customers/" <> Options.encode_path_segment(customer_id),
        path_template: "/customers/{customerId}",
        query: Options.query(include: include, testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :customers_get,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _customer_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _customer_id, _opts), do: configuration_error(:invalid_customer_id)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
