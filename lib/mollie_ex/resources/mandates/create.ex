defmodule MollieEx.Resources.Mandates.Create do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :idempotency_key,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, customer_id, params, opts)
      when is_binary(customer_id) and is_map(params) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_testmode(client, params, opts),
         {:ok, customer_id} <- Options.customer_id(customer_id),
         {:ok, body, testmode} <- Options.body_with_testmode(client, params, opts, []) do
      RequestBuilder.build(opts,
        method: :post,
        path: Options.resource_path(["customers", customer_id, "mandates"]),
        path_template: "/customers/{customerId}/mandates",
        body: body,
        idempotency_policy: :optional,
        operation: :mandates_create,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _customer_id, _params, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _customer_id, params, _opts) when not is_map(params),
    do: Options.configuration_error(:invalid_mandate_params)

  def build(%Client{}, _customer_id, _params, _opts),
    do: Options.configuration_error(:invalid_customer_id)
end
