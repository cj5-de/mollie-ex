defmodule MollieEx.Resources.PaymentRoutes.Create do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Casing
  alias MollieEx.Resources.Options

  @allowed_options [
    :idempotency_key,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]
  @structured_body_keys ~w(amount destination)

  @spec build(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, payment_id, params, opts)
      when is_binary(payment_id) and is_map(params) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         :ok <- Options.reject_api_key_testmode(client, params, opts),
         {:ok, payment_id} <- Options.payment_id(payment_id),
         {:ok, body, testmode} <- body(client, params, opts) do
      request = %Request{
        method: :post,
        path: "/payments/" <> Options.encode_path_segment(payment_id) <> "/routes",
        path_template: "/payments/{paymentId}/routes",
        body: body,
        idempotency_key: Keyword.get(opts, :idempotency_key),
        idempotency_policy: :optional,
        operation: :payment_routes_create,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _payment_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _payment_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_route_params)

  def build(%Client{}, _payment_id, _params, _opts), do: configuration_error(:invalid_payment_id)

  defp body(%Client{} = client, params, opts) do
    with :ok <- Options.require_param(params, [:amount, "amount"], :missing_amount),
         :ok <-
           Options.require_param(
             params,
             [:destination, "destination"],
             :missing_destination
           ),
         {:ok, testmode} <- Options.effective_testmode(client, params, opts) do
      body =
        params
        |> Casing.to_mollie_body(@structured_body_keys)
        |> Options.drop_testmode()
        |> Options.put_body("testmode", testmode)

      {:ok, body, testmode}
    end
  end

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
