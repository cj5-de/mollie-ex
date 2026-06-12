defmodule MollieEx.Resources.Payments.Update do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Casing
  alias MollieEx.Resources.Payments.Options

  @allowed_options [
    :idempotency_key,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]
  @structured_body_keys ~w(billingAddress shippingAddress)

  @spec build(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, payment_id, params, opts)
      when is_binary(payment_id) and is_map(params) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         {:ok, payment_id} <- payment_id(payment_id),
         :ok <- reject_profile_id(params),
         :ok <- reject_api_key_scoped_fields(client, params, opts),
         {:ok, body, testmode} <- body(client, params, opts) do
      request = %Request{
        method: :patch,
        path: "/payments/" <> encode_path_segment(payment_id),
        path_template: "/payments/{paymentId}",
        body: body,
        idempotency_key: Keyword.get(opts, :idempotency_key),
        idempotency_policy: :optional,
        operation: :payments_update,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _payment_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _payment_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_payment_params)

  def build(%Client{}, _payment_id, _params, _opts), do: configuration_error(:invalid_payment_id)

  defp payment_id(payment_id) do
    payment_id = String.trim(payment_id)

    if payment_id == "" do
      configuration_error(:invalid_payment_id)
    else
      {:ok, payment_id}
    end
  end

  defp reject_profile_id(params) do
    if Map.has_key?(params, :profile_id) or Map.has_key?(params, "profile_id") or
         Map.has_key?(params, "profileId") do
      configuration_error(:unsupported_profile_id)
    else
      :ok
    end
  end

  defp reject_api_key_scoped_fields(%Client{auth: {:api_key, _credential}}, params, opts) do
    if Keyword.has_key?(opts, :testmode) or Map.has_key?(params, :testmode) or
         Map.has_key?(params, "testmode") do
      configuration_error(:unsupported_testmode)
    else
      :ok
    end
  end

  defp reject_api_key_scoped_fields(%Client{}, _params, _opts), do: :ok

  defp body(%Client{} = client, params, opts) do
    with {:ok, testmode} <- effective_testmode(client, params, opts) do
      body =
        params
        |> encode_body_params()
        |> Map.drop(["testmode", :testmode])
        |> maybe_put("testmode", testmode)

      {:ok, body, testmode}
    end
  end

  defp effective_testmode(%Client{auth: {:api_key, _credential}}, _params, _opts), do: {:ok, nil}

  defp effective_testmode(%Client{} = client, params, opts) do
    case Keyword.fetch(opts, :testmode) do
      {:ok, testmode} -> testmode
      :error -> param_or_default(params, [:testmode, "testmode"], client.testmode)
    end
    |> testmode()
  end

  defp testmode(testmode) when is_boolean(testmode), do: {:ok, testmode}
  defp testmode(nil), do: {:ok, nil}
  defp testmode(_testmode), do: configuration_error(:invalid_testmode)

  defp param_or_default(params, keys, default) do
    case fetch_param(params, keys) do
      {:ok, value} -> value
      :error -> default
    end
  end

  defp encode_body_params(params) do
    Map.new(params, fn {key, value} ->
      mollie_key = Casing.to_mollie_key(key)
      {mollie_key, encode_body_value(mollie_key, value)}
    end)
  end

  defp encode_body_value(key, value) when key in @structured_body_keys,
    do: Casing.to_mollie(value)

  defp encode_body_value(_key, value), do: value

  defp fetch_param(params, keys) do
    Enum.reduce_while(keys, :error, fn key, :error ->
      if Map.has_key?(params, key) do
        {:halt, {:ok, Map.fetch!(params, key)}}
      else
        {:cont, :error}
      end
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
