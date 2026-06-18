defmodule MollieEx.Resources.SalesInvoices.Create do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :idempotency_key,
    :profile_id,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]
  @structured_body_keys ~w(paymentDetails emailDetails recipient lines discount)

  @spec build(Client.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_scoped_fields(client, params, opts),
         :ok <- Options.require_param(params, [:status, "status"], :missing_status),
         :ok <-
           Options.require_param(
             params,
             [:recipient_identifier, "recipient_identifier", "recipientIdentifier"],
             :missing_recipient_identifier
           ),
         :ok <- Options.require_param(params, [:recipient, "recipient"], :missing_recipient),
         :ok <- Options.require_param(params, [:lines, "lines"], :missing_lines),
         {:ok, body, testmode} <-
           Options.body_with_profile(client, params, opts, @structured_body_keys, []) do
      RequestBuilder.build(opts,
        method: :post,
        path: "/sales-invoices",
        path_template: "/sales-invoices",
        body: body,
        idempotency_policy: :optional,
        operation: :sales_invoices_create,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _params, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _params, _opts),
    do: Options.configuration_error(:invalid_sales_invoice_params)
end
