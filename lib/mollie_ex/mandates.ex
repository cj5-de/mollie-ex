defmodule MollieEx.Mandates do
  @moduledoc """
  Create, retrieve, list, and revoke Mollie mandates for customers.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.
  """
  @moduledoc since: "0.4.0"

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Mandate
  alias MollieEx.Resources.Mandates.{Create, Get, Revoke}
  alias MollieEx.Resources.Mandates.List, as: ListRequest
  alias MollieEx.Resources.RequestRunner

  @type create_params :: map()
  @type create_option ::
          {:idempotency_key, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type list_option ::
          {:from, String.t()}
          | {:limit, pos_integer()}
          | {:scopes, [String.t()]}
          | {:sort, :asc | :desc | String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type revoke_option ::
          {:idempotency_key, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Creates a mandate for a customer.

  Mandate creation supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.4.0"
  @spec create(Client.t(), String.t(), create_params(), [create_option()]) ::
          {:ok, Mandate.t()} | {:error, Error.t()}
  def create(client, customer_id, params, opts \\ [])

  def create(%Client{} = client, customer_id, params, opts)
      when is_binary(customer_id) and is_map(params) and is_list(opts) do
    RequestRunner.run_resource(
      Create.build(client, customer_id, params, opts),
      client,
      Mandate,
      :mandates_create
    )
  end

  def create(%Client{}, _customer_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def create(%Client{}, _customer_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_mandate_params)

  def create(%Client{}, _customer_id, _params, _opts),
    do: configuration_error(:invalid_customer_id)

  def create(_client, _customer_id, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a customer mandate by ID.
  """
  @doc since: "0.4.0"
  @spec get(Client.t(), String.t(), String.t(), [get_option()]) ::
          {:ok, Mandate.t()} | {:error, Error.t()}
  def get(client, customer_id, mandate_id, opts \\ [])

  def get(%Client{} = client, customer_id, mandate_id, opts)
      when is_binary(customer_id) and is_binary(mandate_id) and is_list(opts) do
    RequestRunner.run_resource(
      Get.build(client, customer_id, mandate_id, opts),
      client,
      Mandate,
      :mandates_get
    )
  end

  def get(%Client{}, _customer_id, _mandate_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, customer_id, _mandate_id, _opts) when not is_binary(customer_id),
    do: configuration_error(:invalid_customer_id)

  def get(%Client{}, _customer_id, _mandate_id, _opts),
    do: configuration_error(:invalid_mandate_id)

  def get(_client, _customer_id, _mandate_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Lists customer mandates.
  """
  @doc since: "0.4.0"
  @spec list(Client.t(), String.t(), [list_option()]) ::
          {:ok, MollieList.t(Mandate.t())} | {:error, Error.t()}
  def list(client, customer_id, opts \\ [])

  def list(%Client{} = client, customer_id, opts)
      when is_binary(customer_id) and is_list(opts) do
    RequestRunner.run_resource_list(
      ListRequest.build(client, customer_id, opts),
      client,
      "mandates",
      Mandate,
      :mandates_list
    )
  end

  def list(%Client{}, _customer_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def list(%Client{}, _customer_id, _opts), do: configuration_error(:invalid_customer_id)
  def list(_client, _customer_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Revokes a customer mandate.

  Mandate revocation supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.4.0"
  @spec revoke(Client.t(), String.t(), String.t(), [revoke_option()]) ::
          {:ok, :no_content} | {:error, Error.t()}
  def revoke(client, customer_id, mandate_id, opts \\ [])

  def revoke(%Client{} = client, customer_id, mandate_id, opts)
      when is_binary(customer_id) and is_binary(mandate_id) and is_list(opts) do
    RequestRunner.run_no_content(Revoke.build(client, customer_id, mandate_id, opts), client)
  end

  def revoke(%Client{}, _customer_id, _mandate_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def revoke(%Client{}, customer_id, _mandate_id, _opts) when not is_binary(customer_id),
    do: configuration_error(:invalid_customer_id)

  def revoke(%Client{}, _customer_id, _mandate_id, _opts),
    do: configuration_error(:invalid_mandate_id)

  def revoke(_client, _customer_id, _mandate_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
