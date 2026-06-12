defmodule MollieEx.HTTP.RetryPolicy do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.HTTP.{Idempotency, Request, RetryDelay}

  @retryable_statuses [408, 429, 500, 502, 503, 504]
  @retryable_transport_reasons [:timeout, :econnrefused, :closed]
  @retryable_http2_reasons [
    :unprocessed,
    :pool_not_available,
    :timeout,
    :request_timeout,
    :connection_closed,
    :disconnected
  ]

  @spec options(Client.t(), Request.t()) :: keyword()
  def options(_client, %Request{retry_policy: :disabled}), do: [retry: false]

  def options(%Client{} = client, %Request{} = request) do
    [
      retry: retry_fun(client, request),
      max_retries: client.max_retries,
      retry_log_level: false
    ]
  end

  defp retry_fun(%Client{} = client, %Request{} = request) do
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
    Idempotency.valid_key?(key)
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
    |> RetryDelay.jittered_exponential()
  end

  defp retry_after(%Req.Response{} = response) do
    case Req.Response.get_header(response, "retry-after") do
      [_delay] -> parse_retry_after(response)
      _zero_or_multiple_values -> nil
    end
  end

  defp parse_retry_after(%Req.Response{} = response) do
    Req.Response.get_retry_after(response)
  rescue
    ArgumentError ->
      nil
  end
end
