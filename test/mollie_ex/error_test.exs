defmodule MollieEx.ErrorTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error

  @redacted "[REDACTED]"

  defmodule RawDiagnostic do
    defstruct [:status, :headers, :safe, :nested]
  end

  defmodule Request do
    defstruct [:body, :headers, :safe]
  end

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
    expected_message = "api_key=#{@redacted}"
    expected_path = "/payments?api_key=#{@redacted}"

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
             {"Authorization", @redacted},
             {"Proxy-Authorization", @redacted},
             {"Cookie", @redacted},
             {"Idempotency-Key", @redacted},
             {"X-Client-Signature", @redacted},
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

  test "drops body and stores redacted raw source reason and request metadata" do
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

    assert error.message == "client_secret=#{@redacted}"
    assert error.method == "post"

    assert error.path ==
             "https://#{@redacted}@example.com/payments?api_key=#{@redacted}"

    assert error.operation == "access_token=#{@redacted}"
    assert error.request_id == "refresh_token=#{@redacted}"
    assert error.reason == "organization_token=#{@redacted}"
    assert error.body == nil
    assert error.raw == [access_token: @redacted, safe: "visible"]
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

  test "fingerprints raw idempotency keys at construction time" do
    raw_key_error =
      Error.exception(
        type: :transport,
        idempotency_key_fingerprint: "order-123"
      )

    hash_shaped_raw_key = "sha256:deadbeefcafebabe"

    hash_shaped_raw_key_error =
      Error.exception(
        type: :transport,
        idempotency_key_fingerprint: hash_shaped_raw_key
      )

    assert raw_key_error.idempotency_key_fingerprint =~ ~r/^sha256:[0-9a-f]{16}$/
    refute raw_key_error.idempotency_key_fingerprint == "order-123"
    assert hash_shaped_raw_key_error.idempotency_key_fingerprint =~ ~r/^sha256:[0-9a-f]{16}$/
    refute hash_shaped_raw_key_error.idempotency_key_fingerprint == hash_shaped_raw_key

    assert Map.from_struct(raw_key_error).idempotency_key_fingerprint ==
             raw_key_error.idempotency_key_fingerprint

    assert Map.from_struct(hash_shaped_raw_key_error).idempotency_key_fingerprint ==
             hash_shaped_raw_key_error.idempotency_key_fingerprint

    for text <- [
          inspect(raw_key_error),
          inspect(hash_shaped_raw_key_error)
        ] do
      refute text =~ "order-123"
      refute text =~ "deadbeefcafebabe"
    end
  end

  test "inspect omits idempotency fingerprints from presentation" do
    stored_fingerprint = "sha256:0123456789abcdef"

    error =
      %Error{
        type: :transport,
        idempotency_key_fingerprint: stored_fingerprint
      }

    malformed =
      %Error{
        type: :transport,
        idempotency_key_fingerprint: "manual-secret"
      }

    assert error.idempotency_key_fingerprint == stored_fingerprint
    assert Map.from_struct(error).idempotency_key_fingerprint == stored_fingerprint

    refute inspect(error) =~ "idempotency_key_fingerprint"
    refute inspect(error) =~ stored_fingerprint
    refute Exception.message(error) =~ "idempotency_key_fingerprint"
    refute Exception.message(error) =~ stored_fingerprint

    refute inspect(malformed) =~ "idempotency_key_fingerprint"
    refute inspect(malformed) =~ "manual-secret"
  end

  test "formats exception-backed messages as collapsed markers" do
    error =
      Error.exception(
        type: :unexpected,
        message: RuntimeError.exception("api_key=message_exception_secret")
      )

    assert error.message == "%RuntimeError{}"
    assert Exception.message(error) == "%RuntimeError{}"
    assert inspect(error) =~ ~s(message: "%RuntimeError{}")

    for text <- [Exception.message(error), inspect(error), inspect(Map.from_struct(error))] do
      refute text =~ "message_exception_secret"
    end
  end

  test "drops body but preserves redacted raw decode payloads" do
    error =
      Error.exception(
        type: :decode,
        raw: <<"api_key=raw_secret", 255, "ab">>,
        body: %{
          invalid_binary: <<255, "ab">>,
          numbers: [65, 66, 67],
          utf8_bytes: [195, 164],
          nested: [access_token: "access_secret"]
        }
      )

    assert error.body == nil
    assert error.raw == <<"api_key=#{@redacted}", 255, "ab">>
    assert is_binary(error.raw)

    stored = inspect(Map.from_struct(error))

    refute stored =~ "raw_secret"
    refute stored =~ "access_secret"
    refute stored =~ "[65, 66, 67]"
  end

  test "preserves raw response shape while redacting documented credentials" do
    error =
      Error.exception(
        type: :api_error,
        raw: %{
          "status" => 422,
          "detail" => "The amount is invalid.",
          "unknown" => "visible",
          "api_key" => "raw_secret",
          nested: [
            access_token: "access_secret",
            numbers: [65, 66, 67],
            source: RuntimeError.exception("client_secret=source_secret")
          ]
        }
      )

    assert error.raw["status"] == 422
    assert error.raw["detail"] == "The amount is invalid."
    assert error.raw["unknown"] == "visible"
    assert error.raw["api_key"] == @redacted
    assert error.raw.nested[:access_token] == @redacted
    assert error.raw.nested[:numbers] == [65, 66, 67]
    assert error.raw.nested[:source] == "%RuntimeError{}"
    assert Map.from_struct(error).raw.nested[:numbers] == [65, 66, 67]
    assert Error.exception(type: :decode, raw: [65, 66, 67]).raw == [65, 66, 67]

    stored = inspect(Map.from_struct(error))
    message = Exception.message(error)
    inspected = inspect(error)

    assert stored =~ "visible"
    refute message =~ "visible"
    refute inspected =~ "visible"

    for text <- [stored, message, inspected] do
      refute text =~ "raw_secret"
      refute text =~ "access_secret"
      refute text =~ "source_secret"
    end
  end

  test "drops nested request bodies while preserving safe request metadata" do
    error =
      Error.exception(
        type: :transport,
        raw: %{
          request: %{
            body: %{email: "customer@example.test", description: "private order"},
            request_body: %{email: "alternate@example.test"},
            method: "POST",
            headers: [{"Authorization", "Bearer nested_request_secret"}],
            safe: "visible"
          }
        }
      )

    assert error.raw.request.body == nil
    assert error.raw.request.request_body == nil
    assert error.raw.request.method == "POST"
    assert error.raw.request.headers == [{"Authorization", @redacted}]
    assert error.raw.request.safe == "visible"

    for text <- [inspect(Map.from_struct(error)), inspect(error), Exception.message(error)] do
      refute text =~ "customer@example.test"
      refute text =~ "alternate@example.test"
      refute text =~ "private order"
      refute text =~ "nested_request_secret"
    end
  end

  test "preserves response bodies outside request context" do
    error =
      Error.exception(
        type: :api_error,
        raw: %{
          response: %{
            body: %{detail: "visible response detail"}
          }
        }
      )

    assert error.raw.response.body.detail == "visible response detail"
  end

  test "preserves ambiguous request-named response diagnostics" do
    error =
      Error.exception(
        type: :api_error,
        raw: %{
          "request" => %{
            "body" => %{
              "detail" => "visible response diagnostic",
              "api_key" => "ambiguous_body_secret"
            }
          }
        }
      )

    assert error.raw["request"]["body"]["detail"] == "visible response diagnostic"
    assert error.raw["request"]["body"]["api_key"] == @redacted

    stored = inspect(Map.from_struct(error))
    inspected = inspect(error)
    message = Exception.message(error)

    assert stored =~ "visible response diagnostic"
    refute inspected =~ "visible response diagnostic"
    refute message =~ "visible response diagnostic"

    for text <- [stored, inspected, message] do
      refute text =~ "ambiguous_body_secret"
    end
  end

  test "drops request-like struct bodies while preserving safe diagnostics" do
    error =
      Error.exception(
        type: :transport,
        raw: %Request{
          body: %{email: "struct-customer@example.test"},
          headers: [{"Authorization", "Bearer request_struct_secret"}],
          safe: "visible"
        }
      )

    assert error.raw.body == nil
    assert error.raw.headers == [{"Authorization", @redacted}]
    assert error.raw.safe == "visible"

    for text <- [inspect(Map.from_struct(error)), inspect(error), Exception.message(error)] do
      refute text =~ "struct-customer@example.test"
      refute text =~ "request_struct_secret"
    end
  end

  test "redacts credential-bearing charlists in raw diagnostics" do
    raw_charlist_error =
      Error.exception(
        type: :decode,
        raw: ~c"api_key=charlist_secret"
      )

    nested_charlist_error =
      Error.exception(
        type: :api_error,
        raw: %{
          diagnostic: ~c"Authorization: Bearer nested_charlist_secret",
          numbers: [65, 66, 67]
        }
      )

    assert is_list(raw_charlist_error.raw)
    assert to_string(raw_charlist_error.raw) == "api_key=#{@redacted}"
    assert to_string(nested_charlist_error.raw.diagnostic) == "Authorization: Bearer #{@redacted}"
    assert nested_charlist_error.raw.numbers == [65, 66, 67]

    for text <- [
          inspect(Map.from_struct(raw_charlist_error)),
          inspect(raw_charlist_error),
          Exception.message(raw_charlist_error),
          inspect(Map.from_struct(nested_charlist_error)),
          inspect(nested_charlist_error),
          Exception.message(nested_charlist_error)
        ] do
      refute text =~ "charlist_secret"
      refute text =~ "nested_charlist_secret"
    end
  end

  test "redacts credential-bearing atoms in stored and rendered diagnostics" do
    error =
      Error.exception(
        type: :transport,
        reason: :"api_key=atom_reason_secret",
        request_id: :"client_secret=atom_request_secret",
        operation: :"access_token=atom_operation_secret",
        raw: %{
          diagnostic: :"Authorization: Bearer atom_raw_secret",
          safe: :visible_atom
        }
      )

    direct =
      %Error{
        type: :transport,
        reason: :"api_key=direct_atom_secret",
        request_id: :"client_secret=direct_request_secret"
      }

    assert error.reason == "api_key=#{@redacted}"
    assert error.request_id == "client_secret=#{@redacted}"
    assert error.operation == "access_token=#{@redacted}"
    assert error.raw.diagnostic == "Authorization: Bearer #{@redacted}"
    assert error.raw.safe == :visible_atom

    for text <- [
          inspect(Map.from_struct(error)),
          inspect(error),
          Exception.message(error),
          inspect(direct),
          Exception.message(direct)
        ] do
      refute text =~ "atom_reason_secret"
      refute text =~ "atom_request_secret"
      refute text =~ "atom_operation_secret"
      refute text =~ "atom_raw_secret"
      refute text =~ "direct_atom_secret"
      refute text =~ "direct_request_secret"
    end
  end

  test "preserves non-exception struct fields in raw diagnostics" do
    error =
      Error.exception(
        type: :api_error,
        raw: %RawDiagnostic{
          status: 500,
          headers: [
            {"Authorization", "Bearer struct_secret"},
            {"X-Request-Id", "req_123"}
          ],
          safe: "visible",
          nested: %{client_secret: "nested_secret"}
        }
      )

    assert error.raw.status == 500

    assert error.raw.headers == [
             {"Authorization", @redacted},
             {"X-Request-Id", "req_123"}
           ]

    assert error.raw.safe == "visible"
    assert error.raw.nested.client_secret == @redacted

    stored = inspect(Map.from_struct(error))
    inspected = inspect(error)

    assert stored =~ "visible"
    assert stored =~ "req_123"
    refute inspected =~ "visible"
    refute inspected =~ "req_123"

    for text <- [stored, inspected] do
      refute text =~ "struct_secret"
      refute text =~ "nested_secret"
    end
  end

  test "keeps exception structs and source opaque" do
    raw_error =
      Error.exception(
        type: :api_error,
        raw: RuntimeError.exception("api_key=raw_exception_secret")
      )

    source_error =
      Error.exception(
        type: :transport,
        source: RuntimeError.exception("client_secret=source_exception_secret")
      )

    assert raw_error.raw == "%RuntimeError{}"
    assert source_error.source == "%RuntimeError{}"

    for text <- [
          inspect(Map.from_struct(raw_error)),
          inspect(raw_error),
          inspect(Map.from_struct(source_error)),
          inspect(source_error)
        ] do
      refute text =~ "raw_exception_secret"
      refute text =~ "source_exception_secret"
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
          "unknown" => "visible",
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
    assert stored =~ "visible"
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

    assert message =~ "Authorization: ApiKey #{@redacted}"
    assert message =~ ~s("clientSecret":"#{@redacted}")
    refute stored =~ "visible"

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
      {"Authorization: ApiKey api_secret", "Authorization: ApiKey #{@redacted}"},
      {"Authorization: JWT jwt_secret", "Authorization: JWT #{@redacted}"},
      {"Authorization: plain_secret", "Authorization: #{@redacted}"},
      {"Authorization: Basic basic_secret", "Authorization: Basic #{@redacted}"},
      {~s(authorization: "ApiKey quoted_secret"), ~s(authorization: "ApiKey #{@redacted}")}
    ]

    for {input, expected} <- variants do
      error = Error.exception(type: :authentication, message: input)

      assert error.message == expected
      assert Exception.message(error) == expected
      refute inspect(error) =~ "secret"
    end
  end

  test "redacts proxy authorization in already-stringified Elixir text" do
    map_error =
      Error.exception(message: inspect(%{proxy_authorization: "Basic proxy_secret", safe: "ok"}))

    keyword_error =
      Error.exception(message: [proxy_authorization: "Basic proxy_secret", safe: "ok"])

    for error <- [map_error, keyword_error] do
      message = Exception.message(error)
      inspected = inspect(error)
      stored = inspect(Map.from_struct(error))

      assert error.message =~ ~s(proxy_authorization: "#{@redacted}")
      assert message =~ ~s(proxy_authorization: "#{@redacted}")
      assert message =~ ~s(safe: "ok")
      refute inspected =~ "proxy_secret"
      refute stored =~ "proxy_secret"
    end
  end

  test "redacts cookies in inspected Elixir text without corrupting adjacent fields" do
    errors = [
      Error.exception(message: %{cookie: "session=cookie_secret", safe: "ok"}),
      Error.exception(message: inspect(%{cookie: "session=cookie_secret", safe: "ok"})),
      Error.exception(message: inspect(cookie: "session=cookie_secret", safe: "ok"))
    ]

    for error <- errors do
      message = Exception.message(error)
      inspected = inspect(error)
      stored = inspect(Map.from_struct(error))

      assert message =~ ~s(cookie: "#{@redacted}")
      assert message =~ ~s(safe: "ok")
      refute message =~ "cookie_secret"
      refute message =~ "cookie:[REDACTED]"
      refute inspected =~ "cookie_secret"
      refute stored =~ "cookie_secret"
    end
  end

  test "normalizes valid iodata messages and paths through the error constructor" do
    error =
      Error.exception(
        type: :validation,
        message: ["Authorization: Bearer ", "message_secret"],
        path: ["api", "_key=path_secret"]
      )

    assert error.message == "Authorization: Bearer #{@redacted}"
    assert error.path == "api_key=#{@redacted}"
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

    assert error.message =~ ~s({"Authorization", "#{@redacted}"})
    assert stored =~ "path:"
    assert stored =~ "visible"
    refute stored =~ "message_secret"
    refute stored =~ "path_secret"
  end
end
