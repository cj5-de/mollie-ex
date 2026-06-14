defmodule MollieEx.Resources.Refunds.Cancel do
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

  @spec build(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, payment_id, refund_id, opts)
      when is_binary(payment_id) and is_binary(refund_id) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         {:ok, payment_id} <- Options.payment_id(payment_id),
         {:ok, refund_id} <- Options.refund_id(refund_id),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      request = %Request{
        method: :delete,
        path:
          "/payments/" <>
            Options.encode_path_segment(payment_id) <>
            "/refunds/" <>
            Options.encode_path_segment(refund_id),
        path_template: "/payments/{paymentId}/refunds/{refundId}",
        query: Options.query(testmode: testmode),
        idempotency_key: Keyword.get(opts, :idempotency_key),
        idempotency_policy: :optional,
        operation: :refunds_cancel,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, payment_id, _refund_id, opts)
      when is_binary(payment_id) and not is_list(opts),
      do: configuration_error(:invalid_options)

  def build(%Client{}, _payment_id, _refund_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, payment_id, _refund_id, _opts) when not is_binary(payment_id),
    do: configuration_error(:invalid_payment_id)

  def build(%Client{}, _payment_id, _refund_id, _opts),
    do: configuration_error(:invalid_refund_id)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
