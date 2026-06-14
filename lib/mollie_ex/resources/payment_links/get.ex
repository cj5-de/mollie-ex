defmodule MollieEx.Resources.PaymentLinks.Get do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, payment_link_id, opts)
      when is_binary(payment_link_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         {:ok, payment_link_id} <- Options.payment_link_id(payment_link_id),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: Options.resource_path(["payment-links", payment_link_id]),
        path_template: "/payment-links/{paymentLinkId}",
        query: Options.query(testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :payment_links_get,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _payment_link_id, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _payment_link_id, _opts),
    do: Options.configuration_error(:invalid_payment_link_id)
end
