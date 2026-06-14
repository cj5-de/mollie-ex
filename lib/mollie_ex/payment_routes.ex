defmodule MollieEx.PaymentRoutes do
  @moduledoc """
  Create, retrieve, update, and list Mollie delayed payment routes.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.

  Route creation accepts a caller-owned idempotency key. The SDK never
  generates idempotency keys implicitly.

  ```elixir
  {:ok, route} =
    MollieEx.PaymentRoutes.create(
      client,
      "tr_123",
      %{
        amount: %{currency: "EUR", value: "10.00"},
        destination: %{type: "organization", organization_id: "org_123"}
      },
      idempotency_key: "1de10c6a-8b87-4e0c-9c88-52f4c8936d5d"
    )
  ```
  """
  @moduledoc since: "0.2.0"

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Resources.PaymentRoutes.{Create, Get, UpdateReleaseDate}
  alias MollieEx.Resources.PaymentRoutes.List, as: ListRequest
  alias MollieEx.Resources.RequestRunner
  alias MollieEx.Route

  @type create_params :: map()
  @type create_option ::
          {:idempotency_key, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type update_release_date_option ::
          {:idempotency_key, String.t()}
          | {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type list_option ::
          {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Creates a delayed route for a Mollie payment.

  Route creation supports caller-owned idempotency keys. The SDK never
  generates idempotency keys implicitly.
  """
  @doc since: "0.2.0"
  @spec create(Client.t(), String.t(), create_params(), [create_option()]) ::
          {:ok, Route.t()} | {:error, Error.t()}
  def create(client, payment_id, params, opts \\ [])

  def create(%Client{} = client, payment_id, params, opts)
      when is_binary(payment_id) and is_map(params) and is_list(opts) do
    with {:ok, request, transport_opts} <- Create.build(client, payment_id, params, opts) do
      request_route(client, request, transport_opts, :payment_routes_create)
    end
  end

  def create(%Client{}, _payment_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def create(%Client{}, _payment_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_route_params)

  def create(%Client{}, _payment_id, _params, _opts), do: configuration_error(:invalid_payment_id)
  def create(_client, _payment_id, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a delayed route by payment ID and route ID.
  """
  @doc since: "0.2.0"
  @spec get(Client.t(), String.t(), String.t(), [get_option()]) ::
          {:ok, Route.t()} | {:error, Error.t()}
  def get(client, payment_id, route_id, opts \\ [])

  def get(%Client{} = client, payment_id, route_id, opts)
      when is_binary(payment_id) and is_binary(route_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- Get.build(client, payment_id, route_id, opts) do
      request_route(client, request, transport_opts, :payment_routes_get)
    end
  end

  def get(%Client{}, _payment_id, _route_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, payment_id, _route_id, _opts) when not is_binary(payment_id),
    do: configuration_error(:invalid_payment_id)

  def get(%Client{}, _payment_id, _route_id, _opts), do: configuration_error(:invalid_route_id)
  def get(_client, _payment_id, _route_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Updates the release date for a delayed route.

  The release date must be a date-only `YYYY-MM-DD` string.

  Route release date updates support caller-owned idempotency keys. The SDK
  never generates idempotency keys implicitly.
  """
  @doc since: "0.3.0"
  @spec update_release_date(
          Client.t(),
          String.t(),
          String.t(),
          String.t(),
          [update_release_date_option()]
        ) ::
          {:ok, Route.t()} | {:error, Error.t()}
  def update_release_date(client, payment_id, route_id, release_date, opts \\ [])

  def update_release_date(%Client{} = client, payment_id, route_id, release_date, opts)
      when is_binary(payment_id) and is_binary(route_id) and is_list(opts) do
    with {:ok, request, transport_opts} <-
           UpdateReleaseDate.build(client, payment_id, route_id, release_date, opts) do
      request_route(client, request, transport_opts, :payment_routes_update_release_date)
    end
  end

  def update_release_date(%Client{}, _payment_id, _route_id, _release_date, opts)
      when not is_list(opts),
      do: configuration_error(:invalid_options)

  def update_release_date(%Client{}, payment_id, _route_id, _release_date, _opts)
      when not is_binary(payment_id),
      do: configuration_error(:invalid_payment_id)

  def update_release_date(%Client{}, _payment_id, route_id, _release_date, _opts)
      when not is_binary(route_id),
      do: configuration_error(:invalid_route_id)

  def update_release_date(%Client{}, _payment_id, _route_id, _release_date, _opts),
    do: configuration_error(:invalid_release_date)

  def update_release_date(_client, _payment_id, _route_id, _release_date, _opts),
    do: configuration_error(:invalid_client)

  @doc """
  Lists delayed routes for a payment.
  """
  @doc since: "0.2.0"
  @spec list(Client.t(), String.t(), [list_option()]) ::
          {:ok, MollieList.t(Route.t())} | {:error, Error.t()}
  def list(client, payment_id, opts \\ [])

  def list(%Client{} = client, payment_id, opts) when is_binary(payment_id) and is_list(opts) do
    with {:ok, request, transport_opts} <- ListRequest.build(client, payment_id, opts) do
      request_route_list(client, request, transport_opts)
    end
  end

  def list(%Client{}, _payment_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def list(%Client{}, _payment_id, _opts), do: configuration_error(:invalid_payment_id)
  def list(_client, _payment_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end

  defp request_route(%Client{} = client, request, transport_opts, operation) do
    RequestRunner.decode(client, request, transport_opts, &Route.from_response(&1, operation))
  end

  defp request_route_list(%Client{} = client, request, transport_opts) do
    RequestRunner.decode_list(
      client,
      request,
      transport_opts,
      "routes",
      :payment_routes_list,
      &Route.from_response(&1, :payment_routes_list)
    )
  end
end
