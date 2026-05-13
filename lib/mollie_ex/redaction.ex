defmodule MollieEx.Redaction do
  @moduledoc false

  alias MollieEx.Redaction.Policy
  alias MollieEx.Redaction.Term
  alias MollieEx.Redaction.Text

  @doc false
  @spec redacted() :: String.t()
  def redacted, do: Policy.redacted()

  @doc false
  @spec redact(term()) :: term()
  defdelegate redact(value), to: Term

  @doc false
  @spec redact_headers(nil | map() | [{term(), term()}]) :: nil | map() | [{term(), term()}]
  def redact_headers(nil), do: nil

  def redact_headers(headers) when is_map(headers) do
    Map.new(headers, &redact_header/1)
  end

  def redact_headers(headers) when is_list(headers) do
    Enum.map(headers, fn
      {key, value} -> redact_header({key, value})
      value -> redact(value)
    end)
  end

  @doc false
  @spec redact_map(nil | map()) :: nil | map()
  def redact_map(nil), do: nil
  def redact_map(map) when is_map(map), do: redact(map)

  @doc false
  @spec redact_text(term()) :: term()
  def redact_text(text) when is_binary(text) do
    Text.redact(text)
  end

  def redact_text(value), do: value

  @doc false
  @spec idempotency_key_fingerprint(binary() | nil) :: String.t() | nil
  def idempotency_key_fingerprint(nil), do: nil

  def idempotency_key_fingerprint(key) when is_binary(key) do
    hash =
      key
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

    "sha256:" <> hash
  end

  defp redact_header({key, value}) do
    if Policy.sensitive_header?(key) or Policy.sensitive_key?(key) do
      {key, Policy.redacted()}
    else
      {redact(key), redact(value)}
    end
  end
end
