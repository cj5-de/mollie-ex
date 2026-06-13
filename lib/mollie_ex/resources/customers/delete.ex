defmodule MollieEx.Resources.Customers.Delete do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options

  @allowed_options [
    :idempotency_key,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, customer_id, opts)
      when is_binary(customer_id) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         {:ok, customer_id} <- Options.customer_id(customer_id),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      request = %Request{
        method: :delete,
        path: "/customers/" <> Options.encode_path_segment(customer_id),
        path_template: "/customers/{customerId}",
        body: Options.body_testmode(testmode),
        idempotency_key: Keyword.get(opts, :idempotency_key),
        idempotency_policy: :optional,
        operation: :customers_delete,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _customer_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _customer_id, _opts), do: configuration_error(:invalid_customer_id)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
