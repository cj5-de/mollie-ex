defmodule MollieEx.Resources.PaymentRoutes.Get do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options

  @allowed_options [
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = _client, payment_id, route_id, opts)
      when is_binary(payment_id) and is_binary(route_id) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         {:ok, payment_id} <- Options.payment_id(payment_id),
         {:ok, route_id} <- Options.route_id(route_id) do
      request = %Request{
        method: :get,
        path:
          "/payments/" <>
            Options.encode_path_segment(payment_id) <>
            "/routes/" <>
            Options.encode_path_segment(route_id),
        path_template: "/payments/{paymentId}/routes/{routeId}",
        idempotency_policy: :unsupported,
        operation: :payment_routes_get
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _payment_id, _route_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, payment_id, _route_id, _opts) when not is_binary(payment_id),
    do: configuration_error(:invalid_payment_id)

  def build(%Client{}, _payment_id, _route_id, _opts), do: configuration_error(:invalid_route_id)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
