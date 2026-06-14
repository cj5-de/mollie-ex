defmodule MollieEx.Resources.PaymentLinks.ListPayments do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :from,
    :limit,
    :sort,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, payment_link_id, opts)
      when is_binary(payment_link_id) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         {:ok, payment_link_id} <- Options.payment_link_id(payment_link_id),
         {:ok, from} <- Options.string_query_option(opts, :from),
         {:ok, limit} <- Options.limit(opts),
         {:ok, sort} <- Options.sort(opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: "/payment-links/" <> Options.encode_path_segment(payment_link_id) <> "/payments",
        path_template: "/payment-links/{paymentLinkId}/payments",
        query: Options.query(from: from, limit: limit, sort: sort, testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :payment_links_list_payments,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _payment_link_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _payment_link_id, _opts),
    do: configuration_error(:invalid_payment_link_id)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
