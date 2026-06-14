defmodule MollieEx.Resources.RequestBuilderTest do
  use ExUnit.Case, async: true

  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.RequestBuilder

  describe "build/2" do
    test "builds a request and returns timeout options" do
      assert {:ok, %Request{} = request, transport_opts} =
               RequestBuilder.build(
                 [
                   pool_timeout: 1_000,
                   receive_timeout: 2_000,
                   request_timeout: 3_000,
                   unrelated: :ignored
                 ],
                 method: :get,
                 path: "/payments",
                 path_template: "/payments",
                 query: [limit: 10],
                 idempotency_policy: :unsupported,
                 operation: :payments_list,
                 testmode: true
               )

      assert request.method == :get
      assert request.path == "/payments"
      assert request.path_template == "/payments"
      assert request.query == [limit: 10]
      assert request.idempotency_policy == :unsupported
      assert request.operation == :payments_list
      assert request.testmode == true

      assert transport_opts == [
               pool_timeout: 1_000,
               receive_timeout: 2_000,
               request_timeout: 3_000
             ]
    end

    test "copies optional idempotency keys from options" do
      assert {:ok, request, []} =
               RequestBuilder.build(
                 [idempotency_key: "key-123"],
                 method: :post,
                 path: "/payments",
                 idempotency_policy: :optional
               )

      assert request.idempotency_key == "key-123"
    end

    test "copies required idempotency keys from options" do
      assert {:ok, request, []} =
               RequestBuilder.build(
                 [idempotency_key: "key-123"],
                 method: :post,
                 path: "/transfers",
                 idempotency_policy: :required
               )

      assert request.idempotency_key == "key-123"
    end

    test "does not copy idempotency keys for unsupported requests" do
      assert {:ok, request, []} =
               RequestBuilder.build(
                 [idempotency_key: "key-123"],
                 method: :get,
                 path: "/payments",
                 idempotency_policy: :unsupported
               )

      assert request.idempotency_key == nil
    end
  end
end
