defmodule MollieEx.Redaction.Text do
  @moduledoc false

  alias MollieEx.Redaction.Policy

  @redacted Policy.redacted()
  @secret_key_pattern Policy.secret_key_pattern()
  @header_key_pattern Policy.header_key_pattern()
  @redactable_key_pattern "(?:#{@secret_key_pattern}|#{@header_key_pattern})"
  @quoted_secret_key_pattern "\"#{@redactable_key_pattern}\""
  @atom_secret_key_pattern ":#{@redactable_key_pattern}"
  @authorization_scheme_pattern "apikey|api[_-]?key|jwt|bearer|basic|digest|token|oauth|negotiate|hawk|mac|aws4-hmac-sha256"

  @url_userinfo_pattern ~r/\b([a-z][a-z0-9+.-]*:\/\/)(?!\[REDACTED\]@)([^\/\s?#@]+)@(?=[^\/\s?#@]+)/i

  @bearer_pattern ~r/(bearer\s+)(?!\[REDACTED\])[^"'\s,;\]\}]+/i

  @authorization_header_dump_pattern ~r/\b(authorization)(:\s*)(?!\s*(?:Bearer\s+)?\[REDACTED\])(?!\s*["'])([^\r\n]*?)(?=(?:\s+[A-Za-z][A-Za-z0-9-]*:\s*)|\r?\n|$)/i

  @authorization_quoted_pair_pattern ~r/\b(authorization)(:\s*)(["'])(?!\[REDACTED\])([^"']+)\3/i

  @cookie_header_dump_pattern ~r/\b(set[-_]?cookie|cookie)(:\s*)(?!\[REDACTED\])([^\r\n]*?)(?=(?:\s+[A-Za-z][A-Za-z0-9-]*:\s*)|\r?\n|$)/i

  @json_secret_pair_pattern ~r/(#{@quoted_secret_key_pattern}\s*:\s*)(?!\s*"\[REDACTED\]")("[^"]+"|'[^']+'|[^\s,;&\]\}]+)/i

  @inspect_arrow_secret_pair_pattern ~r/((?:#{@quoted_secret_key_pattern}|#{@atom_secret_key_pattern})\s*=>\s*)(?!\s*"\[REDACTED\]"|\[REDACTED\])("[^"]+"|'[^']+'|[^\s,;&\]\}]+)/i

  @inspect_tuple_secret_pair_pattern ~r/(\{\s*(?:#{@quoted_secret_key_pattern}|#{@atom_secret_key_pattern})\s*,\s*)(?!\s*"\[REDACTED\]"|\[REDACTED\])("[^"]+"|'[^']+'|[^\s,;&\]\}]+)/i

  @keyword_secret_pair_pattern ~r/\b(#{@secret_key_pattern})(:\s*)(?!\s*"?\[REDACTED\]"?)("[^"]+"|'[^']+'|[^\s,;&\]\}]+)/i

  @header_secret_pair_pattern ~r/(^|[^A-Za-z0-9_-])(#{@header_key_pattern})(\s*=\s*)(?!\s*"?\[REDACTED\]"?)("[^"]+"|'[^']+'|[^\r\n]*?)(?=(?:[\s,]+[A-Za-z_][A-Za-z0-9_-]*=)|(?:\s+[A-Za-z][A-Za-z0-9-]*:\s*)|\r?\n|$)/i

  @secret_pair_pattern ~r/\b(#{@secret_key_pattern})\s*=\s*(?!\[REDACTED\])("[^"]+"|'[^']+'|[^\s,;&\]\}]+)/i

  # Best-effort fallback for already-stringified data; structured redaction is preferred.
  @spec redact(binary()) :: binary()
  def redact(text) when is_binary(text) do
    if String.valid?(text) do
      redact_valid_text(text)
    else
      redact_invalid_binary(text)
    end
  end

  defp redact_invalid_binary(text) do
    text
    |> String.chunk(:valid)
    |> Enum.map_join(&redact_binary_chunk/1)
  end

  defp redact_binary_chunk(chunk) do
    if String.valid?(chunk) do
      redact_valid_text(chunk)
    else
      inspect(chunk, binaries: :as_binaries)
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
      &Regex.replace(@cookie_header_dump_pattern, &1, fn _match, key, separator, _secret ->
        key <> separator <> @redacted
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

  defp redacted_secret_value("\"" <> _secret), do: ~s("#{@redacted}")
  defp redacted_secret_value("'" <> _secret), do: "'#{@redacted}'"
  defp redacted_secret_value(_secret), do: @redacted
end
