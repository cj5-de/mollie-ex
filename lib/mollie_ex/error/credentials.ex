defmodule MollieEx.Error.Credentials do
  @moduledoc false

  @redacted "[REDACTED]"

  @sensitive_headers MapSet.new([
                       "api_key",
                       "authorization",
                       "cookie",
                       "idempotency_key",
                       "proxy_authorization",
                       "set_cookie",
                       "x_api_key",
                       "x_client_signature"
                     ])

  @sensitive_keys MapSet.new([
                    "api_key",
                    "oauth_token",
                    "organization_token",
                    "access_token",
                    "refresh_token",
                    "client_secret",
                    "idempotency_key",
                    "x_api_key",
                    "x_client_signature",
                    "authorization",
                    "proxy_authorization",
                    "cookie",
                    "set_cookie"
                  ])

  @secret_key_pattern "x[_-]?client[_-]?signature|x[_-]?api[_-]?key|api[_-]?key|oauth[_-]?token|organization[_-]?token|access[_-]?token|refresh[_-]?token|client[_-]?secret|idempotency[_-]?key"
  @header_key_pattern "x[_-]?client[_-]?signature|proxy[_-]?authorization|authorization|set[_-]?cookie|cookie|idempotency[_-]?key"
  @redactable_key_pattern "(?:#{@secret_key_pattern}|#{@header_key_pattern})"
  @keyword_redactable_key_pattern "(?:#{@secret_key_pattern}|proxy[_-]?authorization|set[_-]?cookie|cookie)"
  @quoted_secret_key_pattern "\"#{@redactable_key_pattern}\""
  @atom_secret_key_pattern ":#{@redactable_key_pattern}"
  @authorization_scheme_pattern "apikey|api[_-]?key|jwt|bearer|basic|digest|token|oauth|negotiate|hawk|mac|aws4-hmac-sha256"

  @url_userinfo_pattern ~r/\b([a-z][a-z0-9+.-]*:\/\/)(?!\[REDACTED\]@)([^\/\s?#@]+)@(?=[^\/\s?#@]+)/i
  @bearer_pattern ~r/(bearer\s+)(?!\[REDACTED\])[^"'\s,;\]\}]+/i
  @authorization_header_dump_pattern ~r/\b(authorization|proxy[-_]?authorization)(:\s*)(?!\s*(?:Bearer\s+)?\[REDACTED\])(?!\s*["'])([^\r\n]*?)(?=(?:\s+[A-Za-z][A-Za-z0-9-]*:\s*)|\r?\n|$)/i
  @authorization_quoted_pair_pattern ~r/\b(authorization|proxy[-_]?authorization)(:\s*)(["'])(?!\[REDACTED\])([^"']+)\3/i
  @cookie_header_dump_pattern ~r/(^|\r?\n)(set[-_]?cookie|cookie)(:\s*)(?!\[REDACTED\])([^\r\n]*?)(?=(?:\s+[A-Za-z][A-Za-z0-9-]*:\s*)|\r?\n|$)/i
  @json_secret_pair_pattern ~r/(#{@quoted_secret_key_pattern}\s*:\s*)(?!\s*"\[REDACTED\]")("[^"]+"|'[^']+'|[^\s,;&\]\}]+)/i
  @inspect_arrow_secret_pair_pattern ~r/((?:#{@quoted_secret_key_pattern}|#{@atom_secret_key_pattern})\s*=>\s*)(?!\s*"\[REDACTED\]"|\[REDACTED\])("[^"]+"|'[^']+'|[^\s,;&\]\}]+)/i
  @inspect_tuple_secret_pair_pattern ~r/(\{\s*(?:#{@quoted_secret_key_pattern}|#{@atom_secret_key_pattern})\s*,\s*)(?!\s*"\[REDACTED\]"|\[REDACTED\])("[^"]+"|'[^']+'|[^\s,;&\]\}]+)/i
  @keyword_secret_pair_pattern ~r/\b(#{@keyword_redactable_key_pattern})(:\s*)(?!\s*"?\[REDACTED\]"?)("[^"]+"|'[^']+'|[^\s,;&\]\}]+)/i
  @header_secret_pair_pattern ~r/(^|[^A-Za-z0-9_-])(#{@header_key_pattern})(\s*=\s*)(?!\s*"?\[REDACTED\]"?)("[^"]+"|'[^']+'|[^\r\n]*?)(?=(?:[\s,]+[A-Za-z_][A-Za-z0-9_-]*=)|(?:\s+[A-Za-z][A-Za-z0-9-]*:\s*)|\r?\n|$)/i
  @secret_pair_pattern ~r/\b(#{@secret_key_pattern})\s*=\s*(?!\[REDACTED\])("[^"]+"|'[^']+'|[^\s,;&\]\}]+)/i

  @doc false
  def redacted, do: @redacted

  @doc false
  def idempotency_key_fingerprint(nil), do: nil

  def idempotency_key_fingerprint(key) when is_binary(key), do: fingerprint(key)

  def idempotency_key_fingerprint(key) do
    key
    |> :erlang.term_to_binary()
    |> fingerprint()
  end

  @doc false
  def redact_atom(value) when is_atom(value) do
    text = Atom.to_string(value)
    redacted = redact_text(text)

    if redacted == text, do: value, else: redacted
  end

  @doc false
  def redact_text(text) when is_binary(text) do
    if String.valid?(text) do
      redact_valid_text(text)
    else
      redact_invalid_binary(text)
    end
  end

  @doc false
  def redact_binary_preserving_bytes(text) when is_binary(text) do
    if String.valid?(text) do
      redact_valid_text(text)
    else
      redact_invalid_binary_preserving_bytes(text)
    end
  end

  @doc false
  def sensitive_header?(key) do
    case normalize_key(key) do
      nil -> false
      key -> MapSet.member?(@sensitive_headers, key)
    end
  end

  @doc false
  def sensitive_key?(key) do
    case normalize_key(key) do
      nil -> false
      key -> MapSet.member?(@sensitive_keys, key)
    end
  end

  @doc false
  def normalize_key(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> normalize_key_string()
  end

  def normalize_key(key) when is_binary(key), do: normalize_key_string(key)

  def normalize_key(key) when is_list(key) do
    if Enum.all?(key, &is_integer/1) do
      key
      |> List.to_string()
      |> printable_key_string()
    else
      nil
    end
  rescue
    ArgumentError -> nil
    FunctionClauseError -> nil
    Protocol.UndefinedError -> nil
    UnicodeConversionError -> nil
  end

  def normalize_key(_key), do: nil

  defp fingerprint(value) do
    hash =
      value
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

    "sha256:" <> hash
  end

  defp redact_invalid_binary(text) do
    text
    |> String.chunk(:valid)
    |> Enum.map_join(&redact_binary_chunk/1)
  end

  defp redact_invalid_binary_preserving_bytes(text) do
    text
    |> String.chunk(:valid)
    |> Enum.map_join(&redact_binary_chunk_preserving_bytes/1)
  end

  defp redact_binary_chunk(chunk) do
    if String.valid?(chunk) do
      redact_valid_text(chunk)
    else
      inspect(chunk, binaries: :as_binaries)
    end
  end

  defp redact_binary_chunk_preserving_bytes(chunk) do
    if String.valid?(chunk) do
      redact_valid_text(chunk)
    else
      chunk
    end
  end

  defp redact_valid_text(text) do
    text
    |> then(
      &Regex.replace(@url_userinfo_pattern, &1, fn _match, scheme, _userinfo ->
        scheme <> @redacted <> "@"
      end)
    )
    |> then(&Regex.replace(@bearer_pattern, &1, fn _match, prefix -> prefix <> @redacted end))
    |> then(
      &Regex.replace(@authorization_header_dump_pattern, &1, fn match, key, separator, secret ->
        if String.trim(secret) == "" do
          match
        else
          key <> separator <> redact_authorization_value(secret)
        end
      end)
    )
    |> then(
      &Regex.replace(@authorization_quoted_pair_pattern, &1, fn _match,
                                                                key,
                                                                separator,
                                                                quote,
                                                                secret ->
        key <> separator <> quote <> redact_authorization_value(secret) <> quote
      end)
    )
    |> then(
      &Regex.replace(@cookie_header_dump_pattern, &1, fn _match,
                                                         prefix,
                                                         key,
                                                         separator,
                                                         _secret ->
        prefix <> key <> header_separator(separator) <> @redacted
      end)
    )
    |> then(
      &Regex.replace(@json_secret_pair_pattern, &1, fn _match, prefix, secret ->
        prefix <> redacted_secret_value(secret)
      end)
    )
    |> then(
      &Regex.replace(@inspect_arrow_secret_pair_pattern, &1, fn _match, prefix, secret ->
        prefix <> redacted_secret_value(secret)
      end)
    )
    |> then(
      &Regex.replace(@inspect_tuple_secret_pair_pattern, &1, fn _match, prefix, secret ->
        prefix <> redacted_secret_value(secret)
      end)
    )
    |> then(
      &Regex.replace(@keyword_secret_pair_pattern, &1, fn _match, key, separator, secret ->
        key <> separator <> redacted_secret_value(secret)
      end)
    )
    |> then(
      &Regex.replace(
        @header_secret_pair_pattern,
        &1,
        fn _match, prefix, key, separator, secret ->
          prefix <> key <> separator <> redacted_secret_value(secret)
        end
      )
    )
    |> then(
      &Regex.replace(@secret_pair_pattern, &1, fn _match, key, _secret ->
        key <> "=" <> @redacted
      end)
    )
  end

  defp redact_authorization_value(value) do
    case Regex.run(~r/^(\s*(?:#{@authorization_scheme_pattern})\s+).+/i, value) do
      [_match, scheme] -> scheme <> @redacted
      nil -> @redacted
    end
  end

  defp header_separator(separator) do
    if String.ends_with?(separator, " ") do
      separator
    else
      separator <> " "
    end
  end

  defp redacted_secret_value("\"" <> _secret), do: ~s("#{@redacted}")
  defp redacted_secret_value("'" <> _secret), do: "'#{@redacted}'"
  defp redacted_secret_value(_secret), do: @redacted

  defp printable_key_string(key) do
    if String.printable?(key), do: normalize_key_string(key), else: nil
  end

  defp normalize_key_string(key) do
    key
    |> String.replace("-", "_")
    |> Macro.underscore()
    |> String.downcase()
    |> String.replace(~r/_+/, "_")
  end
end
