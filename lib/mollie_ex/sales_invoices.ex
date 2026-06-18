defmodule MollieEx.SalesInvoices do
  @moduledoc """
  Create, retrieve, list, update, and delete Mollie sales invoices.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.

  Sales invoice writes support caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Resources.RequestRunner
  alias MollieEx.Resources.SalesInvoices.{Create, Delete, Get, Update}
  alias MollieEx.Resources.SalesInvoices.List, as: ListRequest
  alias MollieEx.SalesInvoice

  @type create_params :: map()
  @type create_option ::
          {:idempotency_key, String.t()}
          | {:profile_id, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type list_option ::
          {:from, String.t()}
          | {:limit, pos_integer()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type update_params :: map()
  @type update_option ::
          {:idempotency_key, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type delete_option ::
          {:idempotency_key, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Creates a Mollie sales invoice.
  """
  @doc since: "0.5.0"
  @spec create(Client.t(), create_params(), [create_option()]) ::
          {:ok, SalesInvoice.t()} | {:error, Error.t()}
  def create(client, params, opts \\ [])

  def create(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    RequestRunner.run_resource(
      Create.build(client, params, opts),
      client,
      SalesInvoice,
      :sales_invoices_create
    )
  end

  def create(%Client{}, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def create(%Client{}, _params, _opts), do: configuration_error(:invalid_sales_invoice_params)
  def create(_client, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Lists Mollie sales invoices.
  """
  @doc since: "0.5.0"
  @spec list(Client.t(), [list_option()]) ::
          {:ok, MollieList.t(SalesInvoice.t())} | {:error, Error.t()}
  def list(client, opts \\ [])

  def list(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource_list(
      ListRequest.build(client, opts),
      client,
      "sales_invoices",
      SalesInvoice,
      :sales_invoices_list
    )
  end

  def list(%Client{}, _opts), do: configuration_error(:invalid_options)
  def list(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a Mollie sales invoice by ID.
  """
  @doc since: "0.5.0"
  @spec get(Client.t(), String.t(), [get_option()]) ::
          {:ok, SalesInvoice.t()} | {:error, Error.t()}
  def get(client, sales_invoice_id, opts \\ [])

  def get(%Client{} = client, sales_invoice_id, opts)
      when is_binary(sales_invoice_id) and is_list(opts) do
    RequestRunner.run_resource(
      Get.build(client, sales_invoice_id, opts),
      client,
      SalesInvoice,
      :sales_invoices_get
    )
  end

  def get(%Client{}, _sales_invoice_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, _sales_invoice_id, _opts),
    do: configuration_error(:invalid_sales_invoice_id)

  def get(_client, _sales_invoice_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Updates a Mollie sales invoice by ID.
  """
  @doc since: "0.5.0"
  @spec update(Client.t(), String.t(), update_params(), [update_option()]) ::
          {:ok, SalesInvoice.t()} | {:error, Error.t()}
  def update(client, sales_invoice_id, params, opts \\ [])

  def update(%Client{} = client, sales_invoice_id, params, opts)
      when is_binary(sales_invoice_id) and is_map(params) and is_list(opts) do
    RequestRunner.run_resource(
      Update.build(client, sales_invoice_id, params, opts),
      client,
      SalesInvoice,
      :sales_invoices_update
    )
  end

  def update(%Client{}, _sales_invoice_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def update(%Client{}, _sales_invoice_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_sales_invoice_params)

  def update(%Client{}, _sales_invoice_id, _params, _opts),
    do: configuration_error(:invalid_sales_invoice_id)

  def update(_client, _sales_invoice_id, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Deletes a draft Mollie sales invoice by ID.
  """
  @doc since: "0.5.0"
  @spec delete(Client.t(), String.t(), [delete_option()]) ::
          {:ok, :no_content} | {:error, Error.t()}
  def delete(client, sales_invoice_id, opts \\ [])

  def delete(%Client{} = client, sales_invoice_id, opts)
      when is_binary(sales_invoice_id) and is_list(opts) do
    RequestRunner.run_no_content(Delete.build(client, sales_invoice_id, opts), client)
  end

  def delete(%Client{}, _sales_invoice_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def delete(%Client{}, _sales_invoice_id, _opts),
    do: configuration_error(:invalid_sales_invoice_id)

  def delete(_client, _sales_invoice_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
