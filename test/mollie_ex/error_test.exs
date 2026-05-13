defmodule MollieEx.ErrorTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error
  alias MollieEx.Redaction

  @error_types [
    :api_error,
    :authentication,
    :authorization,
    :not_found,
    :gone,
    :validation,
    :rate_limited,
    :server_error,
    :timeout,
    :transport,
    :decode,
    :configuration,
    :unexpected
  ]

  test "constructs each stable error type" do
    for type <- @error_types do
      assert %Error{type: ^type} = Error.exception(type: type)
    end
  end

  test "normalizes supported string attrs and ignores unsupported attrs" do
    expected_message = "api_key=#{Redaction.redacted()}"
    expected_path = "/payments?api_key=#{Redaction.redacted()}"

    assert %Error{
             type: :validation,
             message: ^expected_message,
             path: ^expected_path
           } =
             Error.exception(%{
               "type" => "validation",
               "message" => "api_key=message_secret",
               "path" => "/payments?api_key=path_secret",
               "unknown" => "ignored"
             })
  end

  test "stores redacted headers and preserves non-sensitive Mollie request metadata" do
    error =
      Error.exception(
        type: :authentication,
        headers: [
          {"Authorization", "Bearer auth_secret"},
          {"Proxy-Authorization", "Basic proxy_secret"},
          {"Cookie", "session=cookie_secret"},
          {"Idempotency-Key", "order-123"},
          {"X-Client-Signature", "signature_secret"},
          {"X-Client-Signed-At", "2026-05-13T10:00:00Z"},
          {"x-request-id", "req_123"}
        ]
      )

    assert error.headers == [
             {"Authorization", Redaction.redacted()},
             {"Proxy-Authorization", Redaction.redacted()},
             {"Cookie", Redaction.redacted()},
             {"Idempotency-Key", Redaction.redacted()},
             {"X-Client-Signature", Redaction.redacted()},
             {"X-Client-Signed-At", "2026-05-13T10:00:00Z"},
             {"x-request-id", "req_123"}
           ]

    safe = inspect(Map.from_struct(error))

    refute safe =~ "auth_secret"
    refute safe =~ "proxy_secret"
    refute safe =~ "cookie_secret"
    refute safe =~ "order-123"
    refute safe =~ "signature_secret"
    assert safe =~ "2026-05-13T10:00:00Z"
    assert safe =~ "req_123"
  end

  test "stores redacted body raw source reason and request metadata" do
    error =
      Error.exception(
        type: :transport,
        message: "client_secret=message_secret",
        method: "post",
        path: "https://user:pass@example.com/payments?api_key=path_secret",
        operation: "access_token=operation_secret",
        request_id: "refresh_token=request_secret",
        reason: "organization_token=reason_secret",
        body: %{api_key: "body_secret", safe: "visible"},
        raw: [access_token: "raw_secret", safe: "visible"],
        source: RuntimeError.exception("client_secret=source_secret")
      )

    assert error.message == "client_secret=#{Redaction.redacted()}"
    assert error.method == "post"

    assert error.path ==
             "https://#{Redaction.redacted()}@example.com/payments?api_key=#{Redaction.redacted()}"

    assert error.operation == "access_token=#{Redaction.redacted()}"
    assert error.request_id == "refresh_token=#{Redaction.redacted()}"
    assert error.reason == "organization_token=#{Redaction.redacted()}"
    assert error.body == %{api_key: Redaction.redacted(), safe: "visible"}
    assert error.raw == [access_token: Redaction.redacted(), safe: "visible"]
    assert error.source == "%RuntimeError{}"

    safe = inspect(Map.from_struct(error))

    for secret <- [
          "message_secret",
          "user:pass",
          "path_secret",
          "operation_secret",
          "request_secret",
          "reason_secret",
          "body_secret",
          "raw_secret",
          "source_secret"
        ] do
      refute safe =~ secret
    end
  end

  test "preserves safe Mollie API details in messages and inspect output" do
    error =
      Error.exception(
        type: :validation,
        status: 422,
        title: "Unprocessable Entity",
        detail: "The amount is invalid.",
        field: "amount.value",
        request_id: "req_123",
        links: %{
          "documentation" => %{
            "href" => "https://docs.mollie.com/reference/handling-errors"
          }
        },
        raw: %{
          "status" => 422,
          "detail" => "The amount is invalid.",
          "api_key" => "raw_secret"
        }
      )

    message = Exception.message(error)
    inspected = inspect(error)
    stored = inspect(Map.from_struct(error))

    assert message =~ "MollieEx validation error"
    assert message =~ "status: 422"
    assert message =~ "title: Unprocessable Entity"
    assert message =~ "detail: The amount is invalid."
    assert message =~ "field: amount.value"
    assert message =~ "request_id: req_123"

    assert inspected =~ "Unprocessable Entity"
    assert inspected =~ "The amount is invalid."
    assert inspected =~ "amount.value"
    assert inspected =~ "docs.mollie.com"

    assert stored =~ "The amount is invalid."
    assert stored =~ "docs.mollie.com"
    refute stored =~ "raw_secret"
    refute inspected =~ "raw:"
  end

  test "Exception.message inspect and Map.from_struct do not expose fake credentials" do
    error =
      Error.exception(
        type: :authentication,
        message: ~s(Authorization: ApiKey api_key_secret\n{"clientSecret":"client_secret_value"}),
        headers: [{"Authorization", "Bearer header_secret"}],
        body: %{refresh_token: "refresh_secret", safe: "visible"},
        raw: %{organization_token: "organization_secret"}
      )

    message = Exception.message(error)
    inspected = inspect(error)
    stored = inspect(Map.from_struct(error))

    assert message =~ "Authorization: ApiKey #{Redaction.redacted()}"
    assert message =~ ~s("clientSecret":"#{Redaction.redacted()}")
    assert stored =~ "visible"

    for text <- [message, inspected, stored] do
      refute text =~ "api_key_secret"
      refute text =~ "client_secret_value"
      refute text =~ "header_secret"
      refute text =~ "refresh_secret"
      refute text =~ "organization_secret"
    end
  end

  test "redacts documented Authorization text variants" do
    variants = [
      {"Authorization: ApiKey api_secret", "Authorization: ApiKey #{Redaction.redacted()}"},
      {"Authorization: JWT jwt_secret", "Authorization: JWT #{Redaction.redacted()}"},
      {"Authorization: plain_secret", "Authorization: #{Redaction.redacted()}"},
      {"Authorization: Basic basic_secret", "Authorization: Basic #{Redaction.redacted()}"},
      {~s(authorization: "ApiKey quoted_secret"),
       ~s(authorization: "ApiKey #{Redaction.redacted()}")}
    ]

    for {input, expected} <- variants do
      error = Error.exception(type: :authentication, message: input)

      assert error.message == expected
      assert Exception.message(error) == expected
      refute inspect(error) =~ "secret"
    end
  end

  test "normalizes valid iodata messages and paths through the error constructor" do
    error =
      Error.exception(
        type: :validation,
        message: ["Authorization: Bearer ", "message_secret"],
        path: ["api", "_key=path_secret"]
      )

    assert error.message == "Authorization: Bearer #{Redaction.redacted()}"
    assert error.path == "api_key=#{Redaction.redacted()}"
    refute inspect(Map.from_struct(error)) =~ "message_secret"
    refute inspect(Map.from_struct(error)) =~ "path_secret"
  end

  test "formats non-iodata lists safely without requiring cross-fragment parsing" do
    error =
      Error.exception(
        type: :validation,
        message: [{"Authorization", "Bearer message_secret"}],
        path: [0, %{api_key: "path_secret", safe: "visible"}]
      )

    stored = inspect(Map.from_struct(error))

    assert error.message =~ ~s({"Authorization", "#{Redaction.redacted()}"})
    assert stored =~ "path:"
    assert stored =~ "visible"
    refute stored =~ "message_secret"
    refute stored =~ "path_secret"
  end
end
