defmodule MollieEx.Redaction.Term do
  @moduledoc false

  alias MollieEx.Redaction.Policy
  alias MollieEx.Redaction.Text

  @spec redact(term()) :: term()
  def redact(nil), do: nil

  def redact(value) when is_binary(value) do
    Text.redact(value)
  end

  def redact(%URI{} = value) do
    %URI{
      value
      | scheme: redact(value.scheme),
        authority: redact_uri_authority(value.authority),
        userinfo: redact_uri_userinfo(value.userinfo),
        host: redact(value.host),
        port: redact(value.port),
        path: redact(value.path),
        query: redact(value.query),
        fragment: redact(value.fragment)
    }
  end

  def redact(%MapSet{} = value) do
    value
    |> MapSet.to_list()
    |> Enum.map(&redact/1)
    |> MapSet.new()
  end

  def redact(%module{}), do: "%#{inspect(module)}{}"

  def redact(value) when is_map(value) do
    Map.new(value, fn {key, field_value} ->
      if Policy.sensitive_key?(key) or Policy.sensitive_header?(key) do
        {key, Policy.redacted()}
      else
        {redact(key), redact(field_value)}
      end
    end)
  end

  def redact(value) when is_list(value) do
    case printable_charlist_to_string(value) do
      {:ok, text} ->
        text
        |> Text.redact()
        |> String.to_charlist()

      :error ->
        Enum.map(value, &redact_list_item/1)
    end
  end

  def redact(value) when is_tuple(value) do
    redact_tuple(value)
  end

  def redact(value), do: value

  defp redact_tuple({key, value}) do
    if Policy.sensitive_key?(key) or Policy.sensitive_header?(key) do
      {key, Policy.redacted()}
    else
      {redact(key), redact(value)}
    end
  end

  defp redact_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&redact/1)
    |> List.to_tuple()
  end

  defp redact_list_item({key, value}) do
    if Policy.sensitive_key?(key) or Policy.sensitive_header?(key) do
      {key, Policy.redacted()}
    else
      {redact(key), redact(value)}
    end
  end

  defp redact_list_item(value), do: redact(value)

  defp printable_charlist_to_string(value) do
    if Enum.all?(value, &is_integer/1) do
      value
      |> List.to_string()
      |> printable_string()
    else
      :error
    end
  rescue
    ArgumentError -> :error
    FunctionClauseError -> :error
    Protocol.UndefinedError -> :error
    UnicodeConversionError -> :error
  end

  defp printable_string(text) do
    if String.printable?(text), do: {:ok, text}, else: :error
  end

  defp redact_uri_userinfo(nil), do: nil
  defp redact_uri_userinfo(""), do: ""
  defp redact_uri_userinfo(_userinfo), do: Policy.redacted()

  defp redact_uri_authority(authority) when is_binary(authority) do
    authority
    |> Text.redact()
    |> then(&Regex.replace(~r/^[^@]+@/, &1, Policy.redacted() <> "@"))
  end

  defp redact_uri_authority(authority), do: authority
end
