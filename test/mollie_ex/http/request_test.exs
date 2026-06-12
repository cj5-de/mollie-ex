defmodule MollieEx.HTTP.RequestTest do
  use ExUnit.Case, async: true

  alias MollieEx.HTTP.Request

  test "builds a request boundary with defaults" do
    assert %Request{} = request = %Request{method: :get, path: "/payments/tr_123"}

    assert request.method == :get
    assert request.path == "/payments/tr_123"
    assert request.query == []
    assert request.headers == []
    assert request.body == nil
    assert request.idempotency_key == nil
    assert request.idempotency_policy == :unsupported
    assert request.operation == nil
    assert request.retry_policy == :default
  end

  test "stores request metadata without transport details" do
    request = %Request{
      method: :post,
      path: "/payments",
      query: [include: "details"],
      headers: [{"x-test-header", "visible"}],
      body: %{"amount" => %{"currency" => "EUR", "value" => "10.00"}},
      idempotency_key: "order-123",
      idempotency_policy: :optional,
      operation: :payments_create,
      retry_policy: :disabled
    }

    assert request.path == "/payments"
    refute String.starts_with?(request.path, "/v2/")
    assert request.operation == :payments_create
    assert request.idempotency_policy == :optional
  end
end
