defmodule MollieEx.Resources.SalesInvoices.Update do
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
  @structured_body_keys ~w(paymentDetails emailDetails recipient lines discount)
  @non_update_keys [:testmode, "testmode", :profile_id, "profile_id", "profileId"]
  @hal_accept "application/hal+json"

  @spec build(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, sales_invoice_id, params, opts)
      when is_binary(sales_invoice_id) and is_map(params) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         {:ok, sales_invoice_id} <- Options.sales_invoice_id(sales_invoice_id),
         :ok <- require_update_params(params),
         :ok <- Options.reject_profile_id(params),
         :ok <- Options.reject_api_key_testmode(client, params, opts),
         {:ok, body, testmode} <-
           Options.body_with_testmode(client, params, opts, @structured_body_keys) do
      RequestBuilder.build(opts,
        method: :patch,
        path: Options.resource_path(["sales-invoices", sales_invoice_id]),
        path_template: "/sales-invoices/{salesInvoiceId}",
        accept: @hal_accept,
        body: body,
        idempotency_policy: :optional,
        operation: :sales_invoices_update,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _sales_invoice_id, _params, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _sales_invoice_id, params, _opts) when not is_map(params),
    do: Options.configuration_error(:invalid_sales_invoice_params)

  def build(%Client{}, _sales_invoice_id, _params, _opts),
    do: Options.configuration_error(:invalid_sales_invoice_id)

  defp require_update_params(params) do
    params
    |> Map.drop(@non_update_keys)
    |> map_size()
    |> case do
      0 -> Options.configuration_error(:invalid_sales_invoice_params)
      _size -> :ok
    end
  end
end
