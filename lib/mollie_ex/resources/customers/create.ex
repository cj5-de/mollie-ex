defmodule MollieEx.Resources.Customers.Create do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Casing
  alias MollieEx.Resources.Customers.Options

  @allowed_options [
    :idempotency_key,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), map(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         :ok <- reject_api_key_testmode(client, params, opts),
         {:ok, body, testmode} <- body(client, params, opts) do
      request = %Request{
        method: :post,
        path: "/customers",
        path_template: "/customers",
        body: body,
        idempotency_key: Keyword.get(opts, :idempotency_key),
        idempotency_policy: :optional,
        operation: :customers_create,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _params, _opts), do: configuration_error(:invalid_customer_params)

  defp reject_api_key_testmode(%Client{auth: {:api_key, _credential}}, params, opts) do
    if Keyword.has_key?(opts, :testmode) or Map.has_key?(params, :testmode) or
         Map.has_key?(params, "testmode") do
      configuration_error(:unsupported_testmode)
    else
      :ok
    end
  end

  defp reject_api_key_testmode(%Client{}, _params, _opts), do: :ok

  defp body(%Client{} = client, params, opts) do
    with {:ok, testmode} <- effective_testmode(client, params, opts) do
      body =
        params
        |> encode_body_params()
        |> Options.drop_testmode()
        |> Options.put_body("testmode", testmode)

      {:ok, body, testmode}
    end
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

  defp fetch_param(params, keys) do
    Enum.reduce_while(keys, :error, fn key, :error ->
      if Map.has_key?(params, key) do
        {:halt, {:ok, Map.fetch!(params, key)}}
      else
        {:cont, :error}
      end
    end)
  end

  defp encode_body_params(params) do
    Map.new(params, fn {key, value} -> {Casing.to_mollie_key(key), value} end)
  end

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
