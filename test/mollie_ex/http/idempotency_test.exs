defmodule MollieEx.HTTP.IdempotencyTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error
  alias MollieEx.HTTP.{Idempotency, Request}

  test "validates required idempotency keys" do
    request = %Request{
      method: :post,
      path: "/transfers",
      idempotency_key: "order-123",
      idempotency_policy: :required,
      operation: :transfers_create
    }

    assert :ok = Idempotency.validate_request(request)
  end

  test "rejects missing required idempotency keys" do
    for key <- [nil, "", "  "] do
      request = %Request{
        method: :post,
        path: "/transfers",
        idempotency_key: key,
        idempotency_policy: :required,
        operation: :transfers_create
      }

      assert {:error, %Error{} = error} = Idempotency.validate_request(request)
      assert error.type == :configuration
      assert error.reason == :missing_idempotency_key
      assert error.method == :post
      assert error.path == "/transfers"
      assert error.operation == :transfers_create
    end
  end

  test "rejects header-unsafe idempotency keys" do
    for key <- ["order-123\n", "order-123" <> <<0>>, "order-é", <<255>>] do
      request = %Request{
        method: :post,
        path: "/payments",
        idempotency_key: key,
        idempotency_policy: :optional,
        operation: :payments_create
      }

      assert {:error, %Error{} = error} = Idempotency.validate_request(request)
      assert error.type == :configuration
      assert error.reason == :invalid_idempotency_key
      assert error.idempotency_key_fingerprint =~ ~r/^sha256:[0-9a-f]{16}$/
    end
  end

  test "allows missing optional idempotency keys" do
    request = %Request{
      method: :post,
      path: "/payments",
      idempotency_policy: :optional,
      operation: :payments_create
    }

    assert :ok = Idempotency.validate_request(request)
  end

  test "detects valid keys for retry policy" do
    assert Idempotency.valid_key?("order-123")

    refute Idempotency.valid_key?(nil)
    refute Idempotency.valid_key?("")
    refute Idempotency.valid_key?("  ")
    refute Idempotency.valid_key?("order-é")
    refute Idempotency.valid_key?("order-123\r\n")
  end

  test "removes custom idempotency headers before transport-owned insertion" do
    headers = [
      {"idempotency-key", "caller-key"},
      {"Idempotency-Key", "caller-key-2"},
      {"x-request-trace", "trace-123"},
      {:idempotency_key, "atom-header"},
      {:"idempotency-key", "quoted-atom-header"},
      {:x_request_trace, "atom-trace"}
    ]

    assert Idempotency.reject_custom_headers(headers) == [
             {"x-request-trace", "trace-123"},
             {:x_request_trace, "atom-trace"}
           ]
  end

  test "adds only policy-owned idempotency headers" do
    headers = [{"accept", "application/json"}]

    optional_request = %Request{
      method: :post,
      path: "/payments",
      idempotency_key: " order-123 ",
      idempotency_policy: :optional
    }

    unsupported_request = %Request{
      method: :get,
      path: "/payments/tr_123",
      idempotency_key: "order-123",
      idempotency_policy: :unsupported
    }

    assert [{"idempotency-key", "order-123"} | ^headers] =
             Idempotency.put_header(headers, optional_request)

    assert Idempotency.put_header(headers, unsupported_request) == headers
  end
end
