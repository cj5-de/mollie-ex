defmodule MollieEx.Resources.Captures.Create do
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
  @structured_body_keys ~w(amount)

  @spec build(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, payment_id, params, opts)
      when is_binary(payment_id) and is_map(params) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         :ok <- Options.reject_api_key_testmode(client, params, opts),
         {:ok, payment_id} <- Options.payment_id(payment_id),
         {:ok, body, testmode} <- body(client, params, opts) do
      RequestBuilder.build(opts,
        method: :post,
        path: "/payments/" <> Options.encode_path_segment(payment_id) <> "/captures",
        path_template: "/payments/{paymentId}/captures",
        body: body,
        idempotency_policy: :optional,
        operation: :captures_create,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _payment_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _payment_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_capture_params)

  def build(%Client{}, _payment_id, _params, _opts), do: configuration_error(:invalid_payment_id)

  defp body(%Client{} = client, params, opts),
    do: Options.body_with_testmode(client, params, opts, @structured_body_keys)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
