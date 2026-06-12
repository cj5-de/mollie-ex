defmodule MollieEx.Resources.Payments.Create do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Casing
  alias MollieEx.Resources.Payments.Options

  @allowed_options [
    :idempotency_key,
    :include,
    :profile_id,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]
  @structured_body_keys ~w(amount billingAddress shippingAddress applicationFee lines routing company)

  @spec build(Client.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         :ok <- reject_api_key_scoped_fields(client, params, opts),
         {:ok, include} <- Options.string_option(opts, :include),
         {:ok, body, testmode} <- body(client, params, opts) do
      request = %Request{
        method: :post,
        path: "/payments",
        path_template: "/payments",
        query: query(include),
        body: body,
        idempotency_key: Keyword.get(opts, :idempotency_key),
        idempotency_policy: :optional,
        operation: :payments_create,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _params, _opts), do: configuration_error(:invalid_payment_params)

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
        |> maybe_put("profileId", profile_id)
        |> maybe_put("testmode", testmode)

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
    |> profile_id()
  end

  defp profile_id(profile_id) when is_binary(profile_id) do
    profile_id = String.trim(profile_id)

    if profile_id == "" do
      configuration_error(:invalid_profile_id)
    else
      {:ok, profile_id}
    end
  end

  defp profile_id(nil), do: configuration_error(:missing_profile_id)
  defp profile_id(_profile_id), do: configuration_error(:invalid_profile_id)

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

  defp query(nil), do: []
  defp query(include), do: [include: include]

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
