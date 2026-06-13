defmodule MollieEx.Resources.Payments.ReleaseAuthorization do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Payments.Options

  @allowed_options [
    :idempotency_key,
    :profile_id,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, payment_id, opts) when is_binary(payment_id) and is_list(opts) do
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         {:ok, payment_id} <- payment_id(payment_id),
         :ok <- reject_api_key_scoped_fields(client, opts),
         {:ok, body, testmode} <- body(client, opts) do
      request = %Request{
        method: :post,
        path: "/payments/" <> encode_path_segment(payment_id) <> "/release-authorization",
        path_template: "/payments/{paymentId}/release-authorization",
        body: body,
        idempotency_key: Keyword.get(opts, :idempotency_key),
        idempotency_policy: :optional,
        operation: :payments_release_authorization,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _payment_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def build(%Client{}, _payment_id, _opts), do: configuration_error(:invalid_payment_id)

  defp payment_id(payment_id) do
    payment_id = String.trim(payment_id)

    if payment_id == "" do
      configuration_error(:invalid_payment_id)
    else
      {:ok, payment_id}
    end
  end

  defp reject_api_key_scoped_fields(%Client{auth: {:api_key, _credential}}, opts) do
    cond do
      Keyword.has_key?(opts, :profile_id) ->
        configuration_error(:unsupported_profile_id)

      Keyword.has_key?(opts, :testmode) ->
        configuration_error(:unsupported_testmode)

      true ->
        :ok
    end
  end

  defp reject_api_key_scoped_fields(%Client{}, _opts), do: :ok

  defp body(%Client{} = client, opts) do
    with {:ok, profile_id} <- effective_profile_id(client, opts),
         {:ok, testmode} <- effective_testmode(client, opts) do
      body =
        %{}
        |> maybe_put("profileId", profile_id)
        |> maybe_put("testmode", testmode)
        |> empty_to_nil()

      {:ok, body, testmode}
    end
  end

  defp effective_profile_id(%Client{auth: {:api_key, _credential}}, _opts),
    do: {:ok, nil}

  defp effective_profile_id(%Client{} = client, opts) do
    case Keyword.fetch(opts, :profile_id) do
      {:ok, profile_id} -> profile_id
      :error -> client.profile_id
    end
    |> Options.profile_id()
  end

  defp effective_testmode(%Client{auth: {:api_key, _credential}}, _opts), do: {:ok, nil}

  defp effective_testmode(%Client{} = client, opts) do
    opts
    |> Keyword.get(:testmode, client.testmode)
    |> Options.testmode()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp empty_to_nil(map) when map_size(map) == 0, do: nil
  defp empty_to_nil(map), do: map

  defp encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
