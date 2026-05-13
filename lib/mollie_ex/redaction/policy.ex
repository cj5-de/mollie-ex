defmodule MollieEx.Redaction.Policy do
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

  @spec redacted() :: String.t()
  def redacted, do: @redacted

  @spec secret_key_pattern() :: String.t()
  def secret_key_pattern, do: @secret_key_pattern

  @spec header_key_pattern() :: String.t()
  def header_key_pattern, do: @header_key_pattern

  @spec sensitive_header?(term()) :: boolean()
  def sensitive_header?(key) do
    case normalize_key(key) do
      nil -> false
      key -> MapSet.member?(@sensitive_headers, key)
    end
  end

  @spec sensitive_key?(term()) :: boolean()
  def sensitive_key?(key) do
    case normalize_key(key) do
      nil -> false
      key -> MapSet.member?(@sensitive_keys, key)
    end
  end

  @spec normalize_key(term()) :: String.t() | nil
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
