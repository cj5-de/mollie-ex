defmodule MollieEx.ErrorRedactionTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error

  @redacted "[REDACTED]"

  test "redacts documented sensitive headers only through error construction" do
    error =
      Error.exception(
        type: :authentication,
        headers: [
          {"Authorization", "Bearer auth_secret"},
          {"Proxy-Authorization", "Basic proxy_secret"},
          {"Cookie", "session=cookie_secret"},
          {"Set-Cookie", "session=set_cookie_secret"},
          {"Idempotency-Key", "order-123"},
          {"X-Client-Signature", "signature_secret"},
          {"X-Client-Signed-At", "2026-05-13T10:00:00Z"},
          {"x-request-id", "req_123"}
        ]
      )

    assert error.headers == [
             {"Authorization", @redacted},
             {"Proxy-Authorization", @redacted},
             {"Cookie", @redacted},
             {"Set-Cookie", @redacted},
             {"Idempotency-Key", @redacted},
             {"X-Client-Signature", @redacted},
             {"X-Client-Signed-At", "2026-05-13T10:00:00Z"},
             {"x-request-id", "req_123"}
           ]
  end

  test "redacts documented credential keys in diagnostic terms" do
    error =
      Error.exception(
        message: %{
          api_key: "api_secret",
          organization_token: "organization_secret",
          access_token: "access_secret",
          refresh_token: "refresh_secret",
          client_secret: "client_value_secret",
          idempotency_key: "order-123",
          x_client_signature: "signature_secret",
          webhook_secret: "not_core_scope",
          safe: "visible"
        }
      )

    message = Exception.message(error)

    assert message =~ ~s(api_key: "#{@redacted}")
    assert message =~ ~s(organization_token: "#{@redacted}")
    assert message =~ ~s(access_token: "#{@redacted}")
    assert message =~ ~s(refresh_token: "#{@redacted}")
    assert message =~ ~s(client_secret: "#{@redacted}")
    assert message =~ ~s(idempotency_key: "#{@redacted}")
    assert message =~ ~s(x_client_signature: "#{@redacted}")
    assert message =~ ~s(webhook_secret: "not_core_scope")
    assert message =~ ~s(safe: "visible")

    for secret <- [
          "api_secret",
          "organization_secret",
          "access_secret",
          "refresh_secret",
          "client_value_secret",
          "order-123",
          "signature_secret"
        ] do
      refute message =~ secret
    end
  end

  test "redacts documented credential shapes in text messages" do
    text =
      ~s(api_key=api_secret organization_token=org_secret access_token=access_secret refresh_token=refresh_secret clientSecret=client_secret idempotency-key=order-123 X-Client-Signature: signature_secret)

    error = Error.exception(message: text)
    message = Exception.message(error)

    assert message =~ "api_key=#{@redacted}"
    assert message =~ "organization_token=#{@redacted}"
    assert message =~ "access_token=#{@redacted}"
    assert message =~ "refresh_token=#{@redacted}"
    assert message =~ "clientSecret=#{@redacted}"
    assert message =~ "idempotency-key=#{@redacted}"
    assert message =~ "X-Client-Signature: #{@redacted}"

    for secret <- [
          "api_secret",
          "org_secret",
          "access_secret",
          "refresh_secret",
          "client_secret",
          "order-123",
          "signature_secret"
        ] do
      refute message =~ secret
    end
  end

  test "redacts Authorization header text variants" do
    variants = [
      {"Authorization: ApiKey api_secret", "Authorization: ApiKey #{@redacted}"},
      {"Authorization: JWT jwt_secret", "Authorization: JWT #{@redacted}"},
      {"Authorization: plain_secret", "Authorization: #{@redacted}"},
      {"Authorization: Basic basic_secret", "Authorization: Basic #{@redacted}"},
      {~s(authorization: "ApiKey quoted_secret"), ~s(authorization: "ApiKey #{@redacted}")}
    ]

    for {input, expected} <- variants do
      error = Error.exception(message: input)

      assert error.message == expected
      assert Exception.message(error) == expected
    end
  end

  test "redacts proxy authorization and cookie fields in inspected Elixir text" do
    cases = [
      {~s(%{proxy_authorization: "Basic proxy_secret", safe: "ok"}),
       ~s(%{proxy_authorization: "#{@redacted}", safe: "ok"})},
      {~s(%{cookie: "session=cookie_secret", safe: "ok"}),
       ~s(%{cookie: "#{@redacted}", safe: "ok"})},
      {~s([cookie: "session=cookie_secret", safe: "ok"]),
       ~s([cookie: "#{@redacted}", safe: "ok"])},
      {~s(%{set_cookie: "session=set_cookie_secret", safe: "ok"}),
       ~s(%{set_cookie: "#{@redacted}", safe: "ok"})}
    ]

    for {input, expected} <- cases do
      error = Error.exception(message: input)

      assert Exception.message(error) == expected
      assert Exception.message(error) =~ ~s(safe: "ok")
    end
  end

  test "still redacts cookie header dump lines" do
    text =
      "Cookie: session=cookie_secret\nSet-Cookie: session=set_cookie_secret\nX-Request-Id: req_123"

    error = Error.exception(message: text)

    assert Exception.message(error) ==
             "Cookie: #{@redacted}\nSet-Cookie: #{@redacted}\nX-Request-Id: req_123"

    refute Exception.message(error) =~ "cookie_secret"
    refute Exception.message(error) =~ "set_cookie_secret"
  end

  test "does not redact X-Client-Signed-At or webhook secret without a feature-specific policy" do
    text =
      "X-Client-Signed-At: 2026-05-13T10:00:00Z webhook_secret=feature_specific"

    assert Exception.message(Error.exception(message: text)) == text
  end

  test "idempotency key fingerprints are stable and do not expose the raw key" do
    hash_shaped_raw_key = "sha256:deadbeefcafebabe"

    first =
      Error.exception(
        type: :transport,
        idempotency_key_fingerprint: "order-123"
      )

    second =
      Error.exception(
        type: :transport,
        idempotency_key_fingerprint: "order-123"
      )

    hash_shaped_key =
      Error.exception(
        type: :transport,
        idempotency_key_fingerprint: hash_shaped_raw_key
      )

    assert first.idempotency_key_fingerprint == second.idempotency_key_fingerprint
    assert String.starts_with?(first.idempotency_key_fingerprint, "sha256:")
    assert byte_size(first.idempotency_key_fingerprint) == byte_size("sha256:") + 16
    refute first.idempotency_key_fingerprint =~ "order-123"
    assert hash_shaped_key.idempotency_key_fingerprint =~ ~r/^sha256:[0-9a-f]{16}$/
    refute hash_shaped_key.idempotency_key_fingerprint == hash_shaped_raw_key
    refute inspect(hash_shaped_key) =~ "deadbeefcafebabe"
    refute inspect(hash_shaped_key) =~ "idempotency_key_fingerprint"

    assert Error.exception(type: :transport, idempotency_key_fingerprint: nil).idempotency_key_fingerprint ==
             nil
  end
end
