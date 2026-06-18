defmodule MollieEx.Resources.Options do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.Resources.Casing

  @profile_param_keys [:profile_id, "profile_id", "profileId"]
  @testmode_param_keys [:testmode, "testmode"]
  @timeout_options [:pool_timeout, :receive_timeout, :request_timeout]

  @spec ensure_keyword(keyword() | term()) :: :ok | {:error, Error.t()}
  def ensure_keyword(opts) when is_list(opts) do
    if Keyword.keyword?(opts), do: :ok, else: configuration_error(:invalid_options)
  end

  def ensure_keyword(_opts), do: configuration_error(:invalid_options)

  @spec validate_options(keyword() | term(), [atom()]) :: :ok | {:error, Error.t()}
  def validate_options(opts, allowed) when is_list(allowed) do
    with :ok <- ensure_keyword(opts) do
      reject_unknown(opts, allowed)
    end
  end

  @spec reject_unknown(keyword(), [atom()]) :: :ok | {:error, Error.t()}
  def reject_unknown(opts, allowed) do
    case opts |> Keyword.keys() |> Enum.reject(&(&1 in allowed)) do
      [] -> :ok
      [key | _keys] -> configuration_error({:unsupported_option, key})
    end
  end

  @spec string_option(keyword(), atom()) :: {:ok, String.t() | nil} | {:error, Error.t()}
  def string_option(opts, key) do
    case Keyword.get(opts, key) do
      nil -> {:ok, nil}
      value when is_binary(value) -> {:ok, value}
      _value -> configuration_error({:invalid_option, key})
    end
  end

  @spec string_query_option(keyword(), atom()) :: {:ok, String.t() | nil} | {:error, Error.t()}
  def string_query_option(opts, key) do
    case Keyword.get(opts, key) do
      nil ->
        {:ok, nil}

      value when is_binary(value) ->
        value
        |> String.trim()
        |> non_empty_string_option(key)

      _value ->
        configuration_error({:invalid_option, key})
    end
  end

  @spec limit(keyword()) :: {:ok, pos_integer() | nil} | {:error, Error.t()}
  def limit(opts) do
    case Keyword.get(opts, :limit) do
      nil -> {:ok, nil}
      limit when is_integer(limit) and limit in 1..250 -> {:ok, limit}
      _limit -> configuration_error({:invalid_option, :limit})
    end
  end

  @spec sort(keyword()) :: {:ok, String.t() | nil} | {:error, Error.t()}
  def sort(opts) do
    case Keyword.get(opts, :sort) do
      nil -> {:ok, nil}
      :asc -> {:ok, "asc"}
      :desc -> {:ok, "desc"}
      "asc" -> {:ok, "asc"}
      "desc" -> {:ok, "desc"}
      _sort -> configuration_error({:invalid_option, :sort})
    end
  end

  @spec timeout_options(keyword()) :: keyword()
  def timeout_options(opts), do: Keyword.take(opts, @timeout_options)

  @spec put_query(keyword(), atom(), term()) :: keyword()
  def put_query(query, _key, nil), do: query
  def put_query(query, key, value), do: Keyword.put(query, key, value)

  @spec query(keyword()) :: keyword()
  def query(values) do
    Enum.reduce(values, [], fn {key, value}, query ->
      put_query(query, key, value)
    end)
  end

  @spec put_body(map(), String.t(), term()) :: map()
  def put_body(body, _key, nil), do: body
  def put_body(body, key, value), do: Map.put(body, key, value)

  @spec body_testmode(boolean() | nil) :: map() | nil
  def body_testmode(nil), do: nil
  def body_testmode(testmode) when is_boolean(testmode), do: %{"testmode" => testmode}

  @spec drop_testmode(map()) :: map()
  def drop_testmode(body), do: Map.drop(body, ["testmode", :testmode])

  @spec body_with_testmode(Client.t(), map(), keyword(), [String.t()]) ::
          {:ok, map(), boolean() | nil} | {:error, Error.t()}
  def body_with_testmode(%Client{} = client, params, opts, structured_body_keys)
      when is_map(params) and is_list(opts) and is_list(structured_body_keys) do
    with {:ok, testmode} <- effective_testmode(client, params, opts) do
      body =
        params
        |> Casing.to_mollie_body(structured_body_keys)
        |> drop_testmode()
        |> put_body("testmode", testmode)

      {:ok, body, testmode}
    end
  end

  @spec body_with_profile(Client.t(), map(), keyword(), [String.t()], [term()]) ::
          {:ok, map(), boolean() | nil} | {:error, Error.t()}
  def body_with_profile(%Client{} = client, params, opts, structured_body_keys, extra_drop_keys)
      when is_map(params) and is_list(opts) and is_list(structured_body_keys) and
             is_list(extra_drop_keys) do
    with {:ok, profile_id} <- effective_profile_id(client, params, opts),
         {:ok, testmode} <- effective_testmode(client, params, opts) do
      body =
        params
        |> Casing.to_mollie_body(structured_body_keys)
        |> Map.drop(@profile_param_keys ++ @testmode_param_keys ++ extra_drop_keys)
        |> put_body("profileId", profile_id)
        |> put_body("testmode", testmode)

      {:ok, body, testmode}
    end
  end

  @spec fetch_param(map(), [term()]) :: {:ok, term()} | :error
  def fetch_param(params, keys) when is_map(params) and is_list(keys) do
    Enum.reduce_while(keys, :error, fn key, :error ->
      if Map.has_key?(params, key) do
        {:halt, {:ok, Map.fetch!(params, key)}}
      else
        {:cont, :error}
      end
    end)
  end

  @spec param_or_default(map(), [term()], term()) :: term()
  def param_or_default(params, keys, default) do
    case fetch_param(params, keys) do
      {:ok, value} -> value
      :error -> default
    end
  end

  @spec require_param(map(), [term()], term()) :: :ok | {:error, Error.t()}
  def require_param(params, keys, reason) do
    if has_param?(params, keys) do
      :ok
    else
      configuration_error(reason)
    end
  end

  @spec reject_profile_id(map()) :: :ok | {:error, Error.t()}
  def reject_profile_id(params) do
    if has_param?(params, @profile_param_keys) do
      configuration_error(:unsupported_profile_id)
    else
      :ok
    end
  end

  @spec reject_api_key_testmode(Client.t(), map(), keyword()) :: :ok | {:error, Error.t()}
  def reject_api_key_testmode(%Client{auth: {:api_key, _credential}}, params, opts) do
    if Keyword.has_key?(opts, :testmode) or has_param?(params, @testmode_param_keys) do
      configuration_error(:unsupported_testmode)
    else
      :ok
    end
  end

  def reject_api_key_testmode(%Client{}, _params, _opts), do: :ok

  @spec reject_api_key_scoped_fields(Client.t(), keyword()) :: :ok | {:error, Error.t()}
  def reject_api_key_scoped_fields(%Client{auth: {:api_key, _credential}}, opts) do
    cond do
      Keyword.has_key?(opts, :profile_id) ->
        configuration_error(:unsupported_profile_id)

      Keyword.has_key?(opts, :testmode) ->
        configuration_error(:unsupported_testmode)

      true ->
        :ok
    end
  end

  def reject_api_key_scoped_fields(%Client{}, _opts), do: :ok

  @spec reject_api_key_scoped_fields(Client.t(), map(), keyword()) ::
          :ok | {:error, Error.t()}
  def reject_api_key_scoped_fields(%Client{auth: {:api_key, _credential}}, params, opts) do
    cond do
      Keyword.has_key?(opts, :profile_id) or has_param?(params, @profile_param_keys) ->
        configuration_error(:unsupported_profile_id)

      Keyword.has_key?(opts, :testmode) or has_param?(params, @testmode_param_keys) ->
        configuration_error(:unsupported_testmode)

      true ->
        :ok
    end
  end

  def reject_api_key_scoped_fields(%Client{}, _params, _opts), do: :ok

  @spec resource_id(String.t(), atom()) :: {:ok, String.t()} | {:error, Error.t()}
  def resource_id(id, reason) do
    id = String.trim(id)

    if id == "" do
      configuration_error(reason)
    else
      {:ok, id}
    end
  end

  @spec payment_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def payment_id(payment_id), do: resource_id(payment_id, :invalid_payment_id)

  @spec customer_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def customer_id(customer_id), do: resource_id(customer_id, :invalid_customer_id)

  @spec refund_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def refund_id(refund_id), do: resource_id(refund_id, :invalid_refund_id)

  @spec capture_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def capture_id(capture_id), do: resource_id(capture_id, :invalid_capture_id)

  @spec chargeback_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def chargeback_id(chargeback_id), do: resource_id(chargeback_id, :invalid_chargeback_id)

  @spec route_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def route_id(route_id), do: resource_id(route_id, :invalid_route_id)

  @spec payment_link_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def payment_link_id(payment_link_id),
    do: resource_id(payment_link_id, :invalid_payment_link_id)

  @spec method_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def method_id(method_id), do: resource_id(method_id, :invalid_method_id)

  @spec mandate_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def mandate_id(mandate_id), do: resource_id(mandate_id, :invalid_mandate_id)

  @spec subscription_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def subscription_id(subscription_id),
    do: resource_id(subscription_id, :invalid_subscription_id)

  @spec profile_id(term()) :: {:ok, String.t()} | {:error, Error.t()}
  def profile_id(profile_id) when is_binary(profile_id) do
    profile_id = String.trim(profile_id)

    if profile_id == "" do
      configuration_error(:invalid_profile_id)
    else
      {:ok, profile_id}
    end
  end

  def profile_id(nil), do: configuration_error(:missing_profile_id)
  def profile_id(_profile_id), do: configuration_error(:invalid_profile_id)

  @spec permission_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def permission_id(permission_id),
    do: resource_id(permission_id, :invalid_permission_id)

  @spec organization_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def organization_id(organization_id),
    do: resource_id(organization_id, :invalid_organization_id)

  @spec client_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def client_id(client_id), do: resource_id(client_id, :invalid_client_id)

  @spec balance_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def balance_id(balance_id), do: resource_id(balance_id, :invalid_balance_id)

  @spec balance_transfer_id(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def balance_transfer_id(balance_transfer_id),
    do: resource_id(balance_transfer_id, :invalid_balance_transfer_id)

  @spec effective_profile_id(Client.t(), keyword()) ::
          {:ok, String.t() | nil} | {:error, Error.t()}
  def effective_profile_id(%Client{auth: {:api_key, _credential}}, _opts), do: {:ok, nil}

  def effective_profile_id(%Client{} = client, opts) do
    case Keyword.fetch(opts, :profile_id) do
      {:ok, profile_id} -> profile_id
      :error -> client.profile_id
    end
    |> profile_id()
  end

  @spec effective_profile_id(Client.t(), map(), keyword()) ::
          {:ok, String.t() | nil} | {:error, Error.t()}
  def effective_profile_id(%Client{auth: {:api_key, _credential}}, _params, _opts),
    do: {:ok, nil}

  def effective_profile_id(%Client{} = client, params, opts) do
    case Keyword.fetch(opts, :profile_id) do
      {:ok, profile_id} ->
        profile_id

      :error ->
        param_or_default(params, @profile_param_keys, client.profile_id)
    end
    |> profile_id()
  end

  @spec effective_testmode(Client.t(), keyword()) ::
          {:ok, boolean() | nil} | {:error, Error.t()}
  def effective_testmode(%Client{auth: {:api_key, _credential}}, opts) do
    if Keyword.has_key?(opts, :testmode) do
      configuration_error(:unsupported_testmode)
    else
      {:ok, nil}
    end
  end

  def effective_testmode(%Client{} = client, opts) do
    opts
    |> Keyword.get(:testmode, client.testmode)
    |> testmode()
  end

  @spec effective_testmode(Client.t(), map(), keyword()) ::
          {:ok, boolean() | nil} | {:error, Error.t()}
  def effective_testmode(%Client{auth: {:api_key, _credential}}, _params, _opts), do: {:ok, nil}

  def effective_testmode(%Client{} = client, params, opts) do
    case Keyword.fetch(opts, :testmode) do
      {:ok, testmode} -> testmode
      :error -> param_or_default(params, @testmode_param_keys, client.testmode)
    end
    |> testmode()
  end

  @spec testmode(boolean() | nil | term()) :: {:ok, boolean() | nil} | {:error, Error.t()}
  def testmode(testmode) when is_boolean(testmode), do: {:ok, testmode}
  def testmode(nil), do: {:ok, nil}
  def testmode(_testmode), do: configuration_error(:invalid_testmode)

  @spec require_api_key_client(Client.t()) :: :ok | {:error, Error.t()}
  def require_api_key_client(%Client{auth: {:api_key, _credential}}), do: :ok
  def require_api_key_client(%Client{}), do: configuration_error(:unsupported_auth_mode)

  @spec require_organization_token_client(Client.t()) :: :ok | {:error, Error.t()}
  def require_organization_token_client(%Client{auth: {:organization_token, _credential}}),
    do: :ok

  def require_organization_token_client(%Client{}),
    do: configuration_error(:unsupported_auth_mode)

  @spec reject_api_key_client(Client.t()) :: :ok | {:error, Error.t()}
  def reject_api_key_client(%Client{auth: {:api_key, _credential}}),
    do: configuration_error(:unsupported_auth_mode)

  def reject_api_key_client(%Client{}), do: :ok

  @spec encode_path_segment(String.t()) :: String.t()
  def encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)

  @spec resource_path(nonempty_list(String.t())) :: String.t()
  def resource_path(segments), do: "/" <> Enum.map_join(segments, "/", &encode_path_segment/1)

  @spec configuration_error(term()) :: {:error, Error.t()}
  def configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end

  defp has_param?(params, keys), do: Enum.any?(keys, &Map.has_key?(params, &1))

  defp non_empty_string_option("", key), do: configuration_error({:invalid_option, key})
  defp non_empty_string_option(value, _key), do: {:ok, value}
end
