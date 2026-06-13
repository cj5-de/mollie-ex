defmodule MollieEx.Resources.PaymentLinks.Create do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Casing
  alias MollieEx.Resources.PaymentLinks.Options

  @allowed_options [
    :idempotency_key,
    :profile_id,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]
  @structured_body_keys ~w(amount minimumAmount applicationFee lines billingAddress shippingAddress)

  @spec build(Client.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         :ok <- reject_api_key_scoped_fields(client, params, opts),
         :ok <- require_param(params, [:description, "description"], :missing_description),
         {:ok, body, testmode} <- body(client, params, opts) do
      request = %Request{
        method: :post,
        path: "/payment-links",
        path_template: "/payment-links",
        body: body,
        idempotency_key: Keyword.get(opts, :idempotency_key),
        idempotency_policy: :optional,
        operation: :payment_links_create,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _params, _opts), do: configuration_error(:invalid_payment_link_params)

  defp reject_api_key_scoped_fields(%Client{auth: {:api_key, _credential}}, params, opts) do
    cond do
      Keyword.has_key?(opts, :profile_id) or Map.has_key?(params, :profile_id) or
        Map.has_key?(params, "profile_id") or Map.has_key?(params, "profileId") ->
        configuration_error(:unsupported_profile_id)

      Keyword.has_key?(opts, :testmode) or Map.has_key?(params, :testmode) or
          Map.has_key?(params, "testmode") ->
        configuration_error(:unsupported_testmode)

      true ->
        :ok
    end
  end

  defp reject_api_key_scoped_fields(%Client{}, _params, _opts), do: :ok

  defp body(%Client{} = client, params, opts) do
    with {:ok, profile_id} <- effective_profile_id(client, params, opts),
         {:ok, testmode} <- effective_testmode(client, params, opts) do
      body =
        params
        |> encode_body_params()
        |> Map.drop(["profileId", "profile_id", :profile_id, "testmode", :testmode])
        |> Options.put_body("profileId", profile_id)
        |> Options.put_body("testmode", testmode)

      {:ok, body, testmode}
    end
  end

  defp effective_profile_id(%Client{auth: {:api_key, _credential}}, _params, _opts),
    do: {:ok, nil}

  defp effective_profile_id(%Client{} = client, params, opts) do
    case Keyword.fetch(opts, :profile_id) do
      {:ok, profile_id} ->
        profile_id

      :error ->
        param_or_default(params, [:profile_id, "profile_id", "profileId"], client.profile_id)
    end
    |> Options.profile_id()
  end

  defp effective_testmode(%Client{auth: {:api_key, _credential}}, _params, _opts), do: {:ok, nil}

  defp effective_testmode(%Client{} = client, params, opts) do
    case Keyword.fetch(opts, :testmode) do
      {:ok, testmode} -> testmode
      :error -> param_or_default(params, [:testmode, "testmode"], client.testmode)
    end
    |> Options.testmode()
  end

  defp param_or_default(params, keys, default) do
    case fetch_param(params, keys) do
      {:ok, value} -> value
      :error -> default
    end
  end

  defp require_param(params, keys, reason) do
    if Enum.any?(keys, &Map.has_key?(params, &1)) do
      :ok
    else
      configuration_error(reason)
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

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
