defmodule MollieEx.Resources.Payments.Create do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :idempotency_key,
    :include,
    :profile_id,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]
  @structured_body_keys ~w(amount billingAddress shippingAddress applicationFee lines routing company)

  @spec build(Client.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_scoped_fields(client, params, opts),
         {:ok, include} <- Options.string_option(opts, :include),
         {:ok, body, testmode} <- body(client, params, opts) do
      RequestBuilder.build(opts,
        method: :post,
        path: "/payments",
        path_template: "/payments",
        query: Options.query(include: include),
        body: body,
        idempotency_policy: :optional,
        operation: :payments_create,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _params, _opts), do: Options.configuration_error(:invalid_payment_params)

  defp body(%Client{} = client, params, opts),
    do: Options.body_with_profile(client, params, opts, @structured_body_keys, [])
end
