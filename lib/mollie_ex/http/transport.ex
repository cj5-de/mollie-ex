defmodule MollieEx.HTTP.Transport do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.{Request, Response}

  @json_content_type "application/json"
  @default_headers [
    {"accept", @json_content_type},
    {"content-type", @json_content_type}
  ]
  @retry_base_delay 250
  @retry_max_delay 5_000
  @retryable_statuses [408, 429, 500, 502, 503, 504]
  @retryable_transport_reasons [:timeout, :econnrefused, :closed]
  @retryable_http2_reasons [:unprocessed, :pool_not_available, :timeout, :request_timeout]
  @timeout_http_reasons [:timeout, :request_timeout]

  @spec request(Client.t(), Request.t(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def request(%Client{} = client, %Request{} = request, opts \\ []) do
    with :ok <- validate_request(request),
         {:ok, token} <- auth_token(client.auth),
         {:ok, req_options} <- req_options(client, request, token, opts),
         {:ok, response} <- Req.request(req_options) do
      response(client, request, response)
    else
      {:error, %Error{} = error} ->
        {:error, error}

      {:error, exception} ->
        {:error, transport_error(client, request, exception)}
    end
  end

  defp validate_request(%Request{idempotency_policy: :required} = request) do
    if valid_idempotency_key?(request.idempotency_key) do
      :ok
    else
      {:error,
       Error.exception(
         type: :configuration,
         reason: :missing_idempotency_key,
         method: request.method,
         path: request.path,
         operation: request.operation
       )}
    end
  end

  defp validate_request(%Request{}), do: :ok

  defp valid_idempotency_key?(key) when is_binary(key), do: String.trim(key) != ""
  defp valid_idempotency_key?(_key), do: false

  defp req_options(client, request, token, opts) do
    req_options =
      [
        method: request.method,
        base_url: client.base_url,
        url: request.path,
        params: request.query,
        headers: headers(client, request, token),
        decode_body: false,
        redirect: false,
        pool_timeout: Keyword.get(opts, :pool_timeout, client.pool_timeout),
        receive_timeout: Keyword.get(opts, :receive_timeout, client.receive_timeout),
        finch_request: finch_request(Keyword.get(opts, :request_timeout, client.request_timeout))
      ]
      |> Keyword.merge(retry_options(client, request))
      |> maybe_put_json(request.body)
      |> maybe_put_finch(client)
      |> maybe_put_req_test(client)

    {:ok, req_options}
  end

  defp maybe_put_json(req_options, nil), do: req_options
  defp maybe_put_json(req_options, body), do: Keyword.put(req_options, :json, body)

  defp retry_options(_client, %Request{retry_policy: :disabled}), do: [retry: false]

  defp retry_options(%Client{} = client, %Request{} = request) do
    [
      retry: retry_policy(client, request),
      max_retries: client.max_retries,
      retry_log_level: false
    ]
  end

  defp retry_policy(%Client{} = client, %Request{} = request) do
    fn req, response_or_exception ->
      if retryable?(request, response_or_exception) do
        {:delay, retry_delay(client, req, response_or_exception)}
      else
        false
      end
    end
  end

  defp retryable?(%Request{} = request, response_or_exception) do
    retryable_request?(request) and retryable_failure?(response_or_exception)
  end

  defp retryable_request?(%Request{method: method}) when method in [:get, :head], do: true

  defp retryable_request?(%Request{idempotency_policy: policy, idempotency_key: key})
       when policy in [:optional, :required] do
    valid_idempotency_key?(key)
  end

  defp retryable_request?(%Request{}), do: false

  defp retryable_failure?(%Req.Response{status: status}) when status in @retryable_statuses,
    do: true

  defp retryable_failure?(%Req.Response{}), do: false

  defp retryable_failure?(%Req.TransportError{reason: reason})
       when reason in @retryable_transport_reasons,
       do: true

  defp retryable_failure?(%Req.HTTPError{protocol: :http2, reason: reason})
       when reason in @retryable_http2_reasons,
       do: true

  defp retryable_failure?(_response_or_exception), do: false

  defp retry_delay(
         %Client{} = client,
         %Req.Request{} = req,
         %Req.Response{status: status} = response
       )
       when status in [429, 503] do
    case retry_after(response) do
      delay when is_integer(delay) -> min(delay, client.max_retry_after)
      nil -> exponential_retry_delay(req)
    end
  end

  defp retry_delay(_client, %Req.Request{} = req, _response_or_exception) do
    exponential_retry_delay(req)
  end

  defp exponential_retry_delay(%Req.Request{} = req) do
    req
    |> Req.Request.get_private(:req_retry_count, 0)
    |> then(&(@retry_base_delay * Integer.pow(2, &1)))
    |> min(@retry_max_delay)
  end

  defp retry_after(%Req.Response{} = response) do
    Req.Response.get_retry_after(response)
  rescue
    ArgumentError -> nil
  end

  defp maybe_put_finch(req_options, %Client{finch_name: nil, connect_timeout: connect_timeout}),
    do: Keyword.put(req_options, :connect_options, timeout: connect_timeout)

  defp maybe_put_finch(req_options, %Client{finch_name: finch}),
    do: Keyword.put(req_options, :finch, finch)

  defp maybe_put_req_test(req_options, %Client{transport: {:req_test, name}}) do
    req_options
    |> Keyword.delete(:finch_request)
    |> Keyword.delete(:finch)
    |> Keyword.delete(:connect_options)
    |> Keyword.put(:plug, {Req.Test, name})
  end

  defp maybe_put_req_test(req_options, %Client{transport: :finch}), do: req_options

  defp headers(client, request, token) do
    @default_headers
    |> Kernel.++([{"authorization", "Bearer " <> token}, {"user-agent", client.user_agent}])
    |> Kernel.++(request.headers)
    |> maybe_add_idempotency_key(request)
  end

  defp maybe_add_idempotency_key(headers, %Request{
         idempotency_policy: policy,
         idempotency_key: key
       })
       when policy in [:optional, :required] and is_binary(key) do
    key = String.trim(key)

    if key == "" do
      headers
    else
      [{"idempotency-key", key} | headers]
    end
  end

  defp maybe_add_idempotency_key(headers, _request), do: headers

  defp finch_request(request_timeout) do
    fn req, finch_request, finch_name, finch_options ->
      finch_options = Keyword.put(finch_options, :request_timeout, request_timeout)

      case Finch.request(finch_request, finch_name, finch_options) do
        {:ok, finch_response} -> {req, Req.Response.new(finch_response)}
        {:error, exception} -> {req, normalize_finch_error(exception)}
      end
    end
  end

  defp normalize_finch_error(%Finch.Error{reason: reason})
       when reason in @timeout_http_reasons,
       do: Req.TransportError.exception(reason: :timeout)

  defp normalize_finch_error(%Finch.Error{reason: reason}),
    do: Req.HTTPError.exception(protocol: :http2, reason: reason)

  defp normalize_finch_error(%Finch.TransportError{reason: reason}),
    do: Req.TransportError.exception(reason: reason)

  defp normalize_finch_error(%Finch.HTTPError{module: Mint.HTTP2, reason: reason}),
    do: Req.HTTPError.exception(protocol: :http2, reason: reason)

  defp normalize_finch_error(%Finch.HTTPError{reason: reason}),
    do: Req.HTTPError.exception(protocol: :http1, reason: reason)

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
    |> Enum.any?(&String.starts_with?(&1, @json_content_type))
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
