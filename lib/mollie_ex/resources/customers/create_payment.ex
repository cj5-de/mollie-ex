defmodule MollieEx.Resources.Customers.CreatePayment do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Casing
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
  @customer_id_keys ["customerId", "customer_id", :customer_id]
  @structured_body_keys ~w(amount billingAddress shippingAddress applicationFee lines routing company)

  @spec build(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, customer_id, params, opts)
      when is_binary(customer_id) and is_map(params) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         :ok <- Options.reject_api_key_scoped_fields(client, params, opts),
         {:ok, customer_id} <- Options.customer_id(customer_id),
         {:ok, include} <- Options.string_option(opts, :include),
         {:ok, body, testmode} <- body(client, params, opts) do
      RequestBuilder.build(opts,
        method: :post,
        path: "/customers/" <> Options.encode_path_segment(customer_id) <> "/payments",
        path_template: "/customers/{customerId}/payments",
        query: Options.query(include: include),
        body: body,
        idempotency_policy: :optional,
        operation: :customers_create_payment,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _customer_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _customer_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_payment_params)

  def build(%Client{}, _customer_id, _params, _opts),
    do: configuration_error(:invalid_customer_id)

  defp body(%Client{} = client, params, opts) do
    with {:ok, profile_id} <- Options.effective_profile_id(client, params, opts),
         {:ok, testmode} <- Options.effective_testmode(client, params, opts) do
      body =
        params
        |> Casing.to_mollie_body(@structured_body_keys)
        |> Map.drop(["profileId", "profile_id", :profile_id, "testmode", :testmode])
        |> Map.drop(@customer_id_keys)
        |> Options.put_body("profileId", profile_id)
        |> Options.put_body("testmode", testmode)

      {:ok, body, testmode}
    end
  end

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
