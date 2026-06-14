defmodule MollieEx.Resources.PaymentLinks.Create do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Casing
  alias MollieEx.Resources.Options

  @allowed_options [
    :idempotency_key,
    :profile_id,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]
  @structured_body_keys ~w(amount minimumAmount applicationFee lines billingAddress shippingAddress)

  @spec build(Client.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         :ok <- Options.reject_api_key_scoped_fields(client, params, opts),
         :ok <- Options.require_param(params, [:description, "description"], :missing_description),
         {:ok, body, testmode} <- body(client, params, opts) do
      request = %Request{
        method: :post,
        path: "/payment-links",
        path_template: "/payment-links",
        body: body,
        idempotency_key: Keyword.get(opts, :idempotency_key),
        idempotency_policy: :optional,
        operation: :payment_links_create,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _params, _opts), do: configuration_error(:invalid_payment_link_params)

  defp body(%Client{} = client, params, opts) do
    with {:ok, profile_id} <- Options.effective_profile_id(client, params, opts),
         {:ok, testmode} <- Options.effective_testmode(client, params, opts) do
      body =
        params
        |> Casing.to_mollie_body(@structured_body_keys)
        |> Map.drop(["profileId", "profile_id", :profile_id, "testmode", :testmode])
        |> Options.put_body("profileId", profile_id)
        |> Options.put_body("testmode", testmode)

      {:ok, body, testmode}
    end
  end

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
