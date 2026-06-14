defmodule MollieEx.Resources.Payments.Create do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Casing
  alias MollieEx.Resources.Options

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
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         :ok <- Options.reject_api_key_scoped_fields(client, params, opts),
         {:ok, include} <- Options.string_option(opts, :include),
         {:ok, body, testmode} <- body(client, params, opts) do
      request = %Request{
        method: :post,
        path: "/payments",
        path_template: "/payments",
        query: Options.query(include: include),
        body: body,
        idempotency_key: Keyword.get(opts, :idempotency_key),
        idempotency_policy: :optional,
        operation: :payments_create,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _params, _opts), do: configuration_error(:invalid_payment_params)

  defp body(%Client{} = client, params, opts) do
    with {:ok, profile_id} <- Options.effective_profile_id(client, params, opts),
         {:ok, testmode} <- Options.effective_testmode(client, params, opts) do
      body =
        params
        |> encode_body_params()
        |> Map.drop(["profileId", "profile_id", :profile_id, "testmode", :testmode])
        |> Options.put_body("profileId", profile_id)
        |> Options.put_body("testmode", testmode)

      {:ok, body, testmode}
    end
  end

  defp encode_body_params(params) do
    Map.new(params, fn {key, value} ->
      mollie_key = Casing.to_mollie_key(key)
      {mollie_key, encode_body_value(mollie_key, value)}
    end)
  end

  defp encode_body_value(key, value) when key in @structured_body_keys,
    do: Casing.to_mollie(value)

  defp encode_body_value(_key, value), do: value

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
