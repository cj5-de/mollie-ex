defmodule MollieEx.Resources.PaymentRoutes.UpdateReleaseDate do
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

  @spec build(Client.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, payment_id, route_id, release_date, opts)
      when is_binary(payment_id) and is_binary(route_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         {:ok, payment_id} <- Options.payment_id(payment_id),
         {:ok, route_id} <- Options.route_id(route_id),
         {:ok, release_date} <- release_date(release_date),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :patch,
        path:
          "/payments/" <>
            Options.encode_path_segment(payment_id) <>
            "/routes/" <>
            Options.encode_path_segment(route_id),
        path_template: "/payments/{paymentId}/routes/{routeId}",
        body: body(release_date, testmode),
        idempotency_policy: :optional,
        operation: :payment_routes_update_release_date,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _payment_id, _route_id, _release_date, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, payment_id, _route_id, _release_date, _opts)
      when not is_binary(payment_id),
      do: Options.configuration_error(:invalid_payment_id)

  def build(%Client{}, _payment_id, route_id, _release_date, _opts)
      when not is_binary(route_id),
      do: Options.configuration_error(:invalid_route_id)

  def build(%Client{}, _payment_id, _route_id, _release_date, _opts),
    do: Options.configuration_error(:invalid_release_date)

  defp release_date(release_date) when is_binary(release_date) do
    release_date
    |> String.trim()
    |> parse_release_date()
  end

  defp release_date(_release_date), do: Options.configuration_error(:invalid_release_date)

  defp parse_release_date(""), do: Options.configuration_error(:invalid_release_date)

  defp parse_release_date(release_date) do
    case Date.from_iso8601(release_date) do
      {:ok, date} -> {:ok, Date.to_iso8601(date)}
      {:error, _reason} -> Options.configuration_error(:invalid_release_date)
    end
  end

  defp body(release_date, testmode) do
    %{"releaseDate" => release_date}
    |> Options.put_body("testmode", testmode)
  end
end
