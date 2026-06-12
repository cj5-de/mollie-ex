defmodule MollieEx.HTTP.RetryPolicyTest do
  use ExUnit.Case, async: true

  alias MollieEx.Client
  alias MollieEx.HTTP.{Request, RetryPolicy}

  @api_key "test_retry_secret"

  test "disables retries when request retry policy is disabled" do
    client = client()
    request = %Request{method: :get, path: "/payments/tr_123", retry_policy: :disabled}

    assert RetryPolicy.options(client, request) == [retry: false]
  end

  test "retries safe methods on transient responses" do
    client = client()

    for method <- [:get, :head] do
      request = %Request{method: method, path: "/payments/tr_123"}

      assert {:delay, delay} = retry_result(client, request, response(503))
      assert delay in 250..499
    end
  end

  test "retries writes only with valid idempotency keys" do
    client = client()
    failure = response(503)

    assert false ==
             retry_result(
               client,
               %Request{method: :post, path: "/payments", idempotency_policy: :optional},
               failure
             )

    assert false ==
             retry_result(
               client,
               %Request{
                 method: :post,
                 path: "/payments",
                 idempotency_key: "order-é",
                 idempotency_policy: :optional
               },
               failure
             )

    assert {:delay, delay} =
             retry_result(
               client,
               %Request{
                 method: :post,
                 path: "/payments",
                 idempotency_key: "order-123",
                 idempotency_policy: :optional
               },
               failure
             )

    assert delay in 250..499
  end

  test "does not retry non-transient responses" do
    client = client()
    request = %Request{method: :get, path: "/payments/tr_123"}

    assert false == retry_result(client, request, response(422))
  end

  test "honors retry-after on rate limit and service unavailable responses" do
    client = client()
    request = %Request{method: :get, path: "/payments/tr_123"}

    assert {:delay, 0} = retry_result(client, request, retry_after_response(429, ["0"]))
    assert {:delay, 0} = retry_result(client, request, retry_after_response(503, ["0"]))
  end

  test "falls back to jittered exponential delay for malformed retry-after headers" do
    client = client()
    request = %Request{method: :get, path: "/payments/tr_123"}

    assert {:delay, delay} =
             retry_result(client, request, retry_after_response(503, ["bad-date"]))

    assert delay in 250..499
  end

  test "falls back to jittered exponential delay for duplicate retry-after headers" do
    client = client()
    request = %Request{method: :get, path: "/payments/tr_123"}

    assert {:delay, delay} = retry_result(client, request, retry_after_response(503, ["0", "1"]))
    assert delay in 250..499
  end

  test "retries selected transport and HTTP/2 failures" do
    client = client()
    request = %Request{method: :get, path: "/payments/tr_123"}

    assert {:delay, timeout_delay} =
             retry_result(client, request, Req.TransportError.exception(reason: :timeout))

    assert timeout_delay in 250..499

    assert {:delay, http2_delay} =
             retry_result(
               client,
               request,
               Req.HTTPError.exception(protocol: :http2, reason: :connection_closed)
             )

    assert http2_delay in 250..499

    assert false ==
             retry_result(
               client,
               request,
               Req.HTTPError.exception(protocol: :http1, reason: :connection_closed)
             )
  end

  defp retry_result(%Client{} = client, %Request{} = request, response_or_exception) do
    retry_fun =
      client
      |> RetryPolicy.options(request)
      |> Keyword.fetch!(:retry)

    retry_fun.(Req.new(), response_or_exception)
  end

  defp response(status), do: %Req.Response{status: status}

  defp retry_after_response(status, retry_after) do
    %Req.Response{status: status, headers: %{"retry-after" => retry_after}}
  end

  defp client(opts \\ []) do
    [api_key: @api_key]
    |> Keyword.merge(opts)
    |> Client.new!()
  end
end
