defmodule MollieEx.Resources.Payments.Cancel do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Payments.Options

  @allowed_options [
    :idempotency_key,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, payment_id, opts) when is_binary(payment_id) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         {:ok, payment_id} <- payment_id(payment_id),
         {:ok, body, testmode} <- body(client, opts) do
      request = %Request{
        method: :delete,
        path: "/payments/" <> encode_path_segment(payment_id),
        path_template: "/payments/{paymentId}",
        body: body,
        idempotency_key: Keyword.get(opts, :idempotency_key),
        idempotency_policy: :optional,
        operation: :payments_cancel,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _payment_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _payment_id, _opts), do: configuration_error(:invalid_payment_id)

  defp payment_id(payment_id) do
    payment_id = String.trim(payment_id)

    if payment_id == "" do
      configuration_error(:invalid_payment_id)
    else
      {:ok, payment_id}
    end
  end

  defp body(%Client{} = client, opts) do
    with {:ok, testmode} <- Options.effective_testmode(client, opts) do
      {:ok, Options.body_testmode(testmode), testmode}
    end
  end

  defp encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
