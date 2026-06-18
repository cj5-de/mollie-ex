defmodule MollieEx.Invoices do
  @moduledoc """
  Retrieve Mollie invoices.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.Invoice
  alias MollieEx.List, as: MollieList
  alias MollieEx.Resources.Invoices.{Get, List}
  alias MollieEx.Resources.RequestRunner

  @type list_option ::
          {:reference, String.t()}
          | {:year, String.t()}
          | {:from, String.t()}
          | {:limit, pos_integer()}
          | {:sort, :asc | :desc | String.t()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Lists invoices for the current organization.
  """
  @doc since: "0.5.0"
  @spec list(Client.t(), [list_option()]) ::
          {:ok, MollieList.t(Invoice.t())} | {:error, Error.t()}
  def list(client, opts \\ [])

  def list(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource_list(
      List.build(client, opts),
      client,
      "invoices",
      Invoice,
      :invoices_list
    )
  end

  def list(%Client{}, _opts), do: configuration_error(:invalid_options)
  def list(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves an invoice by ID.

  To retrieve an invoice by invoice reference number, use `list/2` with the
  `:reference` option.
  """
  @doc since: "0.5.0"
  @spec get(Client.t(), String.t(), [get_option()]) ::
          {:ok, Invoice.t()} | {:error, Error.t()}
  def get(client, invoice_id, opts \\ [])

  def get(%Client{} = client, invoice_id, opts)
      when is_binary(invoice_id) and is_list(opts) do
    RequestRunner.run_resource(
      Get.build(client, invoice_id, opts),
      client,
      Invoice,
      :invoices_get
    )
  end

  def get(%Client{}, _invoice_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, _invoice_id, _opts),
    do: configuration_error(:invalid_invoice_id)

  def get(_client, _invoice_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
