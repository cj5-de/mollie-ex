defmodule MollieEx.Resources.Chargebacks.Get do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options

  @allowed_options [
    :embed,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, payment_id, chargeback_id, opts)
      when is_binary(payment_id) and is_binary(chargeback_id) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         {:ok, payment_id} <- Options.payment_id(payment_id),
         {:ok, chargeback_id} <- Options.chargeback_id(chargeback_id),
         {:ok, embed} <- Options.string_option(opts, :embed),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      request = %Request{
        method: :get,
        path:
          "/payments/" <>
            Options.encode_path_segment(payment_id) <>
            "/chargebacks/" <>
            Options.encode_path_segment(chargeback_id),
        path_template: "/payments/{paymentId}/chargebacks/{chargebackId}",
        query: query(embed, testmode),
        idempotency_policy: :unsupported,
        operation: :chargebacks_get,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _payment_id, _chargeback_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, payment_id, _chargeback_id, _opts) when not is_binary(payment_id),
    do: configuration_error(:invalid_payment_id)

  def build(%Client{}, _payment_id, _chargeback_id, _opts),
    do: configuration_error(:invalid_chargeback_id)

  defp query(embed, testmode) do
    []
    |> Options.put_query(:embed, embed)
    |> Options.put_query(:testmode, testmode)
  end

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
