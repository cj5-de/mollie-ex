defmodule MollieEx.Resources.Invoices.Get do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, invoice_id, opts)
      when is_binary(invoice_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client),
         {:ok, invoice_id} <- Options.invoice_id(invoice_id) do
      RequestBuilder.build(opts,
        method: :get,
        path: Options.resource_path(["invoices", invoice_id]),
        path_template: "/invoices/{invoiceId}",
        idempotency_policy: :unsupported,
        operation: :invoices_get
      )
    end
  end

  def build(%Client{}, _invoice_id, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _invoice_id, _opts),
    do: Options.configuration_error(:invalid_invoice_id)
end
