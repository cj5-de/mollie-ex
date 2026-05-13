defmodule MollieEx.RedactionTest do
  use ExUnit.Case, async: true

  alias MollieEx.Redaction

  test "redacts documented sensitive headers only" do
    headers = [
      {"Authorization", "Bearer auth_secret"},
      {"Proxy-Authorization", "Basic proxy_secret"},
      {"Cookie", "session=cookie_secret"},
      {"Set-Cookie", "session=set_cookie_secret"},
      {"Idempotency-Key", "order-123"},
      {"X-Client-Signature", "signature_secret"},
      {"X-Client-Signed-At", "2026-05-13T10:00:00Z"},
      {"x-request-id", "req_123"}
    ]

    assert Redaction.redact_headers(headers) == [
             {"Authorization", Redaction.redacted()},
             {"Proxy-Authorization", Redaction.redacted()},
             {"Cookie", Redaction.redacted()},
             {"Set-Cookie", Redaction.redacted()},
             {"Idempotency-Key", Redaction.redacted()},
             {"X-Client-Signature", Redaction.redacted()},
             {"X-Client-Signed-At", "2026-05-13T10:00:00Z"},
             {"x-request-id", "req_123"}
           ]
  end

  test "redacts documented credential keys in structured data" do
    data = %{
      api_key: "api_secret",
      organization_token: "organization_secret",
      access_token: "access_secret",
      refresh_token: "refresh_secret",
      client_secret: "client_secret",
      idempotency_key: "order-123",
      x_client_signature: "signature_secret",
      webhook_secret: "not_core_scope",
      safe: "visible"
    }

    assert Redaction.redact(data) == %{
             api_key: Redaction.redacted(),
             organization_token: Redaction.redacted(),
             access_token: Redaction.redacted(),
             refresh_token: Redaction.redacted(),
             client_secret: Redaction.redacted(),
             idempotency_key: Redaction.redacted(),
             x_client_signature: Redaction.redacted(),
             webhook_secret: "not_core_scope",
             safe: "visible"
           }
  end

  test "redacts documented credential shapes in text" do
    text =
      ~s(api_key=api_secret organization_token=org_secret access_token=access_secret refresh_token=refresh_secret clientSecret=client_secret idempotency-key=order-123 X-Client-Signature: signature_secret)

    redacted = Redaction.redact_text(text)

    assert redacted =~ "api_key=#{Redaction.redacted()}"
    assert redacted =~ "organization_token=#{Redaction.redacted()}"
    assert redacted =~ "access_token=#{Redaction.redacted()}"
    assert redacted =~ "refresh_token=#{Redaction.redacted()}"
    assert redacted =~ "clientSecret=#{Redaction.redacted()}"
    assert redacted =~ "idempotency-key=#{Redaction.redacted()}"
    assert redacted =~ "X-Client-Signature: #{Redaction.redacted()}"

    for secret <- [
          "api_secret",
          "org_secret",
          "access_secret",
          "refresh_secret",
          "client_secret",
          "order-123",
          "signature_secret"
        ] do
      refute redacted =~ secret
    end
  end

  test "redacts Authorization header text variants" do
    text =
      Enum.join(
        [
          "Authorization: ApiKey api_secret",
          "Authorization: JWT jwt_secret",
          "Authorization: plain_secret",
          "Authorization: Basic basic_secret",
          ~s(authorization: "ApiKey quoted_secret")
        ],
        "\n"
      )

    redacted = Redaction.redact_text(text)

    assert redacted =~ "Authorization: ApiKey #{Redaction.redacted()}"
    assert redacted =~ "Authorization: JWT #{Redaction.redacted()}"
    assert redacted =~ "Authorization: #{Redaction.redacted()}"
    assert redacted =~ "Authorization: Basic #{Redaction.redacted()}"
    assert redacted =~ ~s(authorization: "ApiKey #{Redaction.redacted()}")

    refute redacted =~ "api_secret"
    refute redacted =~ "jwt_secret"
    refute redacted =~ "plain_secret"
    refute redacted =~ "basic_secret"
    refute redacted =~ "quoted_secret"
  end

  test "does not redact X-Client-Signed-At or webhook secret without a feature-specific policy" do
    text =
      "X-Client-Signed-At: 2026-05-13T10:00:00Z webhook_secret=feature_specific"

    assert Redaction.redact_text(text) == text
  end

  test "idempotency key fingerprints are stable and do not expose the raw key" do
    fingerprint = Redaction.idempotency_key_fingerprint("order-123")

    assert fingerprint == Redaction.idempotency_key_fingerprint("order-123")
    assert String.starts_with?(fingerprint, "sha256:")
    assert byte_size(fingerprint) == byte_size("sha256:") + 16
    refute fingerprint =~ "order-123"
    assert Redaction.idempotency_key_fingerprint(nil) == nil
  end
end
