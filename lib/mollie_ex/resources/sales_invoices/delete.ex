defmodule MollieEx.Resources.SalesInvoices.Delete do
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
  @hal_accept "application/hal+json"

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, sales_invoice_id, opts)
      when is_binary(sales_invoice_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         {:ok, sales_invoice_id} <- Options.sales_invoice_id(sales_invoice_id),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :delete,
        path: Options.resource_path(["sales-invoices", sales_invoice_id]),
        path_template: "/sales-invoices/{salesInvoiceId}",
        accept: @hal_accept,
        body: Options.body_testmode(testmode),
        idempotency_policy: :optional,
        operation: :sales_invoices_delete,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _sales_invoice_id, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _sales_invoice_id, _opts),
    do: Options.configuration_error(:invalid_sales_invoice_id)
end
