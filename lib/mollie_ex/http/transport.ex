defmodule MollieEx.HTTP.Transport do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.{FinchAdapter, Idempotency, Request, Response, RetryPolicy, Telemetry}

  @json_content_type "application/json"
  @default_headers [
    {"content-type", @json_content_type}
  ]
  @transport_owned_headers ~w(accept authorization content-type idempotency-key user-agent)
  @timeout_http_reasons [:timeout, :request_timeout]

  @spec request(Client.t(), Request.t(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def request(%Client{} = client, %Request{} = request, opts \\ []) do
    {telemetry?, opts} = Keyword.pop(opts, :telemetry, true)
    start_time = if telemetry?, do: Telemetry.start(client, request)
    result = do_request(client, request, opts)

    if telemetry? do
      Telemetry.emit_result(client, request, result, start_time)
    end

    result
  end

  defp do_request(%Client{} = client, %Request{} = request, opts) do
    with :ok <- Idempotency.validate_request(request),
         {:ok, body} <- encode_body(request),
         {:ok, token} <- auth_token(client.auth),
         :ok <- FinchAdapter.ensure_pool(client),
         {:ok, req_options} <- req_options(client, request, token, opts, body),
         {:ok, response} <- Req.request(req_options) do
      response(client, request, response)
    else
      {:error, %Error{} = error} ->
        {:error, error}

      {:error, exception} ->
        {:error, transport_error(client, request, exception)}
    end
  end

  defp encode_body(%Request{body: nil}), do: {:ok, nil}

  defp encode_body(%Request{} = request) do
    case Jason.encode(request.body) do
      {:ok, body} -> {:ok, body}
      {:error, error} -> invalid_json_body_error(request, error)
    end
  rescue
    exception ->
      invalid_json_body_error(request, exception)
  end

  defp invalid_json_body_error(%Request{} = request, error) do
    {:error,
     Error.exception(
       type: :configuration,
       reason: :invalid_json_body,
       method: request.method,
       path: request.path,
       operation: request.operation,
       source: error
     )}
  end

  defp req_options(client, request, token, opts, body) do
    with {:ok, pool_timeout} <- timeout_option(client, opts, :pool_timeout),
         {:ok, receive_timeout} <- timeout_option(client, opts, :receive_timeout),
         {:ok, request_timeout} <- timeout_option(client, opts, :request_timeout) do
      req_options =
        [
          method: request.method,
          base_url: client.base_url,
          url: request.path,
          params: request.query,
          headers: headers(client, request, token),
          decode_body: false,
          redirect: false,
          pool_timeout: pool_timeout,
          receive_timeout: receive_timeout
        ]
        |> Keyword.merge(RetryPolicy.options(client, request))
        |> maybe_put_body(body)
        |> FinchAdapter.put_options(client, request_timeout)

      {:ok, req_options}
    else
      :error -> invalid_timeout_error(request)
    end
  end

  defp timeout_option(%Client{} = client, opts, key) do
    value =
      if Keyword.has_key?(opts, key) do
        Keyword.fetch!(opts, key)
      else
        Map.fetch!(client, key)
      end

    case value do
      timeout when is_integer(timeout) and timeout > 0 -> {:ok, timeout}
      _timeout -> :error
    end
  end

  defp invalid_timeout_error(%Request{} = request) do
    {:error,
     Error.exception(
       type: :configuration,
       reason: :invalid_timeout,
       method: request.method,
       path: request.path,
       operation: request.operation
     )}
  end

  defp maybe_put_body(req_options, nil), do: req_options
  defp maybe_put_body(req_options, body), do: Keyword.put(req_options, :body, body)

  defp headers(client, request, token) do
    [accept_header(request) | @default_headers]
    |> Kernel.++([{"authorization", "Bearer " <> token}, {"user-agent", client.user_agent}])
    |> Kernel.++(reject_transport_owned_headers(request.headers))
    |> Idempotency.put_header(request)
  end

  defp accept_header(%Request{accept: accept}) when is_binary(accept) do
    case String.trim(accept) do
      "" -> {"accept", @json_content_type}
      accept -> {"accept", accept}
    end
  end

  defp accept_header(%Request{}), do: {"accept", @json_content_type}

  defp reject_transport_owned_headers(headers) do
    Enum.reject(headers, fn {name, _value} -> transport_owned_header?(name) end)
  end

  defp transport_owned_header?(name) when is_binary(name) do
    name
    |> String.downcase()
    |> then(&(&1 in @transport_owned_headers))
  end

  defp transport_owned_header?(name) when is_atom(name) do
    name
    |> Atom.to_string()
    |> String.replace("_", "-")
    |> String.downcase()
    |> then(&(&1 in @transport_owned_headers))
  end

  defp transport_owned_header?(_name), do: false

  defp response(client, request, %Req.Response{} = response) do
    case decode_response(response) do
      {:ok, body, raw} ->
        if response.status in 200..299 do
          {:ok,
           %Response{status: response.status, headers: response.headers, body: body, raw: raw}}
        else
          {:error, api_error(client, request, response, body)}
        end

      {:error, error} ->
        {:error, decode_error(client, request, response, error)}
    end
  end

  defp decode_response(%Req.Response{body: ""}), do: {:ok, nil, nil}
  defp decode_response(%Req.Response{body: nil}), do: {:ok, nil, nil}

  defp decode_response(%Req.Response{} = response) do
    if json_response?(response) do
      case Jason.decode(response.body) do
        {:ok, body} -> {:ok, body, body}
        {:error, error} -> {:error, error}
      end
    else
      {:ok, response.body, response.body}
    end
  end

  defp json_response?(%Req.Response{} = response) do
    response
    |> Req.Response.get_header("content-type")
    |> Enum.any?(&json_content_type?/1)
  end

  defp json_content_type?(content_type) when is_binary(content_type) do
    media_type =
      content_type
      |> String.split(";", parts: 2)
      |> List.first()
      |> String.trim()
      |> String.downcase()

    media_type == @json_content_type or
      (String.starts_with?(media_type, "application/") and
         String.ends_with?(media_type, "+json"))
  end

  defp auth_token({mode, credential}) when mode in [:api_key, :oauth, :organization_token] do
    resolve_credential(credential)
  end

  defp auth_token({:token_provider, module, function, args}) do
    module
    |> apply(function, args)
    |> provider_token()
  rescue
    exception ->
      {:error,
       Error.exception(type: :authentication, reason: :token_provider_failed, source: exception)}
  end

  defp resolve_credential(credential) when is_binary(credential), do: non_empty_token(credential)

  defp resolve_credential(credential) when is_function(credential, 0) do
    credential
    |> then(& &1.())
    |> non_empty_token()
  rescue
    exception ->
      {:error,
       Error.exception(type: :authentication, reason: :credential_failed, source: exception)}
  end

  defp provider_token({:ok, token}), do: non_empty_token(token)
  defp provider_token(token), do: non_empty_token(token)

  defp non_empty_token(token) when is_binary(token) do
    token = String.trim(token)

    if token == "" do
      {:error, Error.exception(type: :authentication, reason: :missing_token)}
    else
      {:ok, token}
    end
  end

  defp non_empty_token(_token),
    do: {:error, Error.exception(type: :authentication, reason: :invalid_token)}

  defp api_error(client, request, response, body) do
    [
      type: error_type(response.status),
      status: response.status,
      method: request.method,
      path: request.path,
      operation: request.operation,
      request_id: request_id(response.headers),
      headers: response.headers,
      raw: body,
      source: %{base_url: client.base_url}
    ]
    |> Keyword.merge(api_error_fields(body))
    |> Error.exception()
  end

  defp api_error_fields(%{} = body) do
    [
      title: Map.get(body, "title"),
      detail: Map.get(body, "detail"),
      field: Map.get(body, "field"),
      links: Map.get(body, "_links")
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp api_error_fields(_body), do: []

  defp decode_error(_client, request, response, error) do
    Error.exception(
      type: :decode,
      status: response.status,
      method: request.method,
      path: request.path,
      operation: request.operation,
      headers: response.headers,
      raw: response.body,
      source: error
    )
  end

  defp transport_error(_client, request, %Req.TransportError{reason: :timeout} = error) do
    Error.exception(
      type: :timeout,
      method: request.method,
      path: request.path,
      operation: request.operation,
      reason: :timeout,
      source: error
    )
  end

  defp transport_error(_client, request, %Req.HTTPError{reason: reason} = error)
       when reason in @timeout_http_reasons do
    Error.exception(
      type: :timeout,
      method: request.method,
      path: request.path,
      operation: request.operation,
      reason: reason,
      source: error
    )
  end

  defp transport_error(_client, request, %Req.TransportError{reason: reason} = error) do
    Error.exception(
      type: :transport,
      method: request.method,
      path: request.path,
      operation: request.operation,
      reason: reason,
      source: error
    )
  end

  defp transport_error(_client, request, %Req.HTTPError{reason: reason} = error) do
    Error.exception(
      type: :transport,
      method: request.method,
      path: request.path,
      operation: request.operation,
      reason: reason,
      source: error
    )
  end

  defp transport_error(_client, request, error) do
    Error.exception(
      type: :transport,
      method: request.method,
      path: request.path,
      operation: request.operation,
      source: error
    )
  end

  defp error_type(401), do: :authentication
  defp error_type(403), do: :authorization
  defp error_type(404), do: :not_found
  defp error_type(410), do: :gone
  defp error_type(422), do: :validation
  defp error_type(408), do: :timeout
  defp error_type(429), do: :rate_limited
  defp error_type(504), do: :timeout
  defp error_type(status) when status in 500..599, do: :server_error
  defp error_type(_status), do: :api_error

  defp request_id(headers) do
    headers
    |> Map.get("x-request-id", [])
    |> List.first()
  end
end
