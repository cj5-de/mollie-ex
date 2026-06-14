defmodule MollieEx.Resources.Mandates.Get do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, customer_id, mandate_id, opts)
      when is_binary(customer_id) and is_binary(mandate_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         {:ok, customer_id} <- Options.customer_id(customer_id),
         {:ok, mandate_id} <- Options.mandate_id(mandate_id),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: Options.resource_path(["customers", customer_id, "mandates", mandate_id]),
        path_template: "/customers/{customerId}/mandates/{mandateId}",
        query: Options.query(testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :mandates_get,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _customer_id, _mandate_id, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, customer_id, _mandate_id, _opts) when not is_binary(customer_id),
    do: Options.configuration_error(:invalid_customer_id)

  def build(%Client{}, _customer_id, _mandate_id, _opts),
    do: Options.configuration_error(:invalid_mandate_id)
end
