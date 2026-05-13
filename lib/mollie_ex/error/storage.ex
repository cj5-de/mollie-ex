defmodule MollieEx.Error.Storage do
  @moduledoc false

  alias MollieEx.Error.Credentials

  @safe_link_keys MapSet.new(["docs", "documentation"])
  @safe_link_value_keys MapSet.new(["href", "templated", "title", "type"])

  @doc false
  def sanitize_attrs(attrs) do
    attrs
    |> redact_attr(:message, &redact_message/1)
    |> redact_attr(:status, &redact_metadata_value/1)
    |> redact_attr(:title, &redact_metadata_value/1)
    |> redact_attr(:detail, &redact_metadata_value/1)
    |> redact_attr(:field, &redact_metadata_value/1)
    |> redact_attr(:reason, &redact_reason/1)
    |> redact_attr(:method, &redact_metadata_value/1)
    |> redact_attr(:path, &redact_path/1)
    |> redact_attr(:operation, &redact_metadata_value/1)
    |> redact_attr(:request_id, &redact_metadata_value/1)
    |> redact_attr(:idempotency_key_fingerprint, &Credentials.idempotency_key_fingerprint/1)
    |> redact_attr(:links, &redact_links/1)
    |> redact_attr(:headers, &redact_headers/1)
    |> redact_attr(:body, &redact_body/1)
    |> redact_attr(:raw, &redact_raw/1)
    |> redact_attr(:source, &redact_source/1)
  end

  @doc false
  def redact_message(nil), do: nil

  def redact_message(message) when is_binary(message) do
    Credentials.redact_text(message)
  end

  def redact_message(message) when is_list(message) do
    case safe_iodata_to_binary(message) do
      {:ok, message} ->
        Credentials.redact_text(message)

      :error ->
        message
        |> redact_term()
        |> safe_inspect_text()
        |> Credentials.redact_text()
    end
  end

  def redact_message(message) do
    message
    |> redact_term()
    |> safe_inspect_text()
    |> Credentials.redact_text()
  end

  @doc false
  def safe_iodata_to_binary(value) do
    {:ok, IO.iodata_to_binary(value)}
  rescue
    ArgumentError -> :error
    FunctionClauseError -> :error
    UnicodeConversionError -> :error
  end

  @doc false
  def safe_inspect_text(value) when is_binary(value), do: value
  def safe_inspect_text(%module{}), do: "%#{inspect(module)}{}"

  def safe_inspect_text(value) do
    inspect(value)
  rescue
    Protocol.UndefinedError -> inspect_message_path(value)
  end

  @doc false
  def redact_term(value), do: redact_term(value, :opaque_structs)

  defp redact_term(value, mode), do: redact_term(value, mode, :default)

  defp redact_attr(attrs, key, fun) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> Map.put(attrs, key, fun.(value))
      :error -> attrs
    end
  end

  defp redact_reason(reason) when is_atom(reason), do: Credentials.redact_atom(reason)
  defp redact_reason(reason), do: redact_metadata_value(reason)

  defp redact_metadata_value(value) when is_binary(value), do: Credentials.redact_text(value)
  defp redact_metadata_value(value) when is_atom(value), do: Credentials.redact_atom(value)

  defp redact_metadata_value(value) when is_list(value) do
    case safe_iodata_to_binary(value) do
      {:ok, value} ->
        Credentials.redact_text(value)

      :error ->
        redact_term(value)
    end
  end

  defp redact_metadata_value(%module{}), do: "%#{inspect(module)}{}"
  defp redact_metadata_value(value), do: redact_term(value)

  defp redact_headers(nil), do: nil

  defp redact_headers(headers) when is_map(headers) do
    Map.new(headers, &redact_header/1)
  end

  defp redact_headers(headers) when is_list(headers) do
    Enum.map(headers, fn
      {key, value} -> redact_header({key, value})
      value -> redact_term(value)
    end)
  end

  defp redact_headers(headers), do: redact_term(headers)

  defp redact_header({key, value}) do
    if Credentials.sensitive_header?(key) or Credentials.sensitive_key?(key) do
      {key, Credentials.redacted()}
    else
      {redact_term(key), redact_term(value)}
    end
  end

  defp redact_body(_body), do: nil

  defp redact_raw(raw), do: redact_term(raw, :preserve_structs)

  defp redact_links(nil), do: nil

  defp redact_links(%URI{} = links), do: redact_term(links)

  defp redact_links(links) when is_map(links) do
    links
    |> Enum.reduce(%{}, fn {key, value}, sanitized ->
      if safe_link_key?(key) do
        Map.put(sanitized, key, redact_link_value(value))
      else
        sanitized
      end
    end)
    |> empty_map_to_nil()
  end

  defp redact_links(links) when is_list(links) do
    links
    |> Enum.reduce([], fn
      {key, value}, sanitized ->
        if safe_link_key?(key) do
          [{key, redact_link_value(value)} | sanitized]
        else
          sanitized
        end

      _value, sanitized ->
        sanitized
    end)
    |> Enum.reverse()
    |> empty_list_to_nil()
  end

  defp redact_links(_links), do: nil

  defp redact_link_value(%URI{} = value), do: redact_term(value)

  defp redact_link_value(value) when is_map(value) do
    value
    |> Enum.reduce(%{}, fn {key, field_value}, sanitized ->
      if safe_link_value_key?(key) do
        Map.put(sanitized, key, redact_link_scalar(field_value))
      else
        sanitized
      end
    end)
    |> empty_map_to_nil()
  end

  defp redact_link_value(value), do: redact_link_scalar(value)

  defp redact_link_scalar(nil), do: nil
  defp redact_link_scalar(value) when is_binary(value), do: Credentials.redact_text(value)
  defp redact_link_scalar(value) when is_boolean(value), do: value
  defp redact_link_scalar(value) when is_number(value), do: value
  defp redact_link_scalar(%URI{} = value), do: redact_term(value)
  defp redact_link_scalar(_value), do: nil

  defp safe_link_key?(key) do
    case Credentials.normalize_key(key) do
      nil -> false
      key -> MapSet.member?(@safe_link_keys, key)
    end
  end

  defp safe_link_value_key?(key) do
    case Credentials.normalize_key(key) do
      nil -> false
      key -> MapSet.member?(@safe_link_value_keys, key)
    end
  end

  defp redact_source(nil), do: nil
  defp redact_source(%module{}), do: "%#{inspect(module)}{}"
  defp redact_source(source) when is_binary(source), do: Credentials.redact_text(source)

  defp redact_source(source) do
    source
    |> redact_term()
    |> safe_inspect_text()
    |> Credentials.redact_text()
  end

  defp redact_path(%URI{} = path), do: redact_term(path)
  defp redact_path(%module{}), do: "%#{inspect(module)}{}"

  defp redact_path(path) when is_list(path) do
    case safe_iodata_to_binary(path) do
      {:ok, path} ->
        Credentials.redact_text(path)

      :error ->
        redact_term(path)
    end
  end

  defp redact_path(path), do: redact_term(path)

  defp redact_term(nil, _mode, _context), do: nil

  defp redact_term(value, _mode, _context) when is_binary(value) do
    Credentials.redact_binary_preserving_bytes(value)
  end

  defp redact_term(value, _mode, _context) when is_atom(value), do: Credentials.redact_atom(value)

  defp redact_term(%URI{} = value, mode, context) do
    %URI{
      value
      | scheme: redact_term(value.scheme, mode, context),
        authority: redact_uri_authority(value.authority),
        userinfo: redact_uri_userinfo(value.userinfo),
        host: redact_term(value.host, mode, context),
        port: redact_term(value.port, mode, context),
        path: redact_term(value.path, mode, context),
        query: redact_term(value.query, mode, context),
        fragment: redact_term(value.fragment, mode, context)
    }
  end

  defp redact_term(%MapSet{} = value, mode, context) do
    value
    |> MapSet.to_list()
    |> Enum.map(&redact_term(&1, mode, context))
    |> MapSet.new()
  end

  defp redact_term(%{__exception__: true, __struct__: module}, _mode, _context),
    do: "%#{inspect(module)}{}"

  defp redact_term(%module{}, :opaque_structs, _context), do: "%#{inspect(module)}{}"

  defp redact_term(%module{} = value, :preserve_structs, context) do
    context = if request_struct?(module), do: :request, else: context

    value
    |> Map.from_struct()
    |> redact_term(:preserve_structs, context)
  end

  defp redact_term(value, mode, context) when is_map(value) do
    Map.new(value, &redact_key_value(&1, mode, context))
  end

  defp redact_term(value, mode, context) when is_list(value) do
    case redact_printable_charlist(value) do
      {:redacted, value} -> value
      :container -> Enum.map(value, &redact_list_item(&1, mode, context))
    end
  end

  defp redact_term(value, mode, context) when is_tuple(value) do
    redact_tuple(value, mode, context)
  end

  defp redact_term(value, _mode, _context), do: value

  defp redact_tuple({key, value}, mode, context),
    do: redact_key_value({key, value}, mode, context)

  defp redact_tuple(value, mode, context) do
    value
    |> Tuple.to_list()
    |> Enum.map(&redact_term(&1, mode, context))
    |> List.to_tuple()
  end

  defp redact_list_item({key, value}, mode, context) do
    redact_key_value({key, value}, mode, context)
  end

  defp redact_list_item(value, mode, context), do: redact_term(value, mode, context)

  defp redact_key_value({key, value}, mode, context) do
    if Credentials.sensitive_key?(key) or Credentials.sensitive_header?(key) do
      {key, Credentials.redacted()}
    else
      redact_non_sensitive_key_value({key, value}, mode, context)
    end
  end

  defp redact_non_sensitive_key_value({key, value}, mode, :request) do
    if request_body_key?(key) do
      {redact_term(key, mode, :request), nil}
    else
      {redact_term(key, mode, :request), redact_term(value, mode, :request)}
    end
  end

  defp redact_non_sensitive_key_value({key, value}, mode, context) do
    value_context = if request_context?(key, value), do: :request, else: context

    {redact_term(key, mode, context), redact_term(value, mode, value_context)}
  end

  defp request_context?(key, value) do
    Credentials.normalize_key(key) == "request" and request_payload?(value)
  end

  defp request_payload?(value) when is_map(value) do
    request_body_container?(value) and request_metadata_container?(value)
  end

  defp request_payload?(value) when is_list(value) do
    Keyword.keyword?(value) and request_body_container?(value) and
      request_metadata_container?(value)
  end

  defp request_payload?(_value), do: false

  defp request_body_container?(value) do
    contains_normalized_key?(value, ["body", "request_body"])
  end

  defp request_metadata_container?(value) do
    contains_normalized_key?(value, ["method", "url", "uri", "path", "headers"])
  end

  defp contains_normalized_key?(value, keys) when is_map(value) do
    Enum.any?(value, fn {key, _value} -> Credentials.normalize_key(key) in keys end)
  end

  defp contains_normalized_key?(value, keys) when is_list(value) do
    Enum.any?(value, fn {key, _value} -> Credentials.normalize_key(key) in keys end)
  end

  defp request_body_key?(key), do: Credentials.normalize_key(key) in ["body", "request_body"]

  defp request_struct?(module) do
    module
    |> Module.split()
    |> List.last()
    |> Kernel.==("Request")
  rescue
    ArgumentError -> false
  end

  defp redact_printable_charlist(value) do
    if Enum.all?(value, &is_integer/1) do
      value
      |> List.to_string()
      |> redact_printable_charlist_text()
    else
      :container
    end
  rescue
    ArgumentError -> :container
    FunctionClauseError -> :container
    Protocol.UndefinedError -> :container
    UnicodeConversionError -> :container
  end

  defp redact_printable_charlist_text(text) do
    if String.printable?(text) do
      redacted = Credentials.redact_text(text)

      if redacted == text do
        :container
      else
        {:redacted, String.to_charlist(redacted)}
      end
    else
      :container
    end
  end

  defp redact_uri_userinfo(nil), do: nil
  defp redact_uri_userinfo(""), do: ""
  defp redact_uri_userinfo(_userinfo), do: Credentials.redacted()

  defp redact_uri_authority(authority) when is_binary(authority) do
    authority = Credentials.redact_binary_preserving_bytes(authority)

    if String.valid?(authority) do
      Regex.replace(~r/^[^@]+@/, authority, Credentials.redacted() <> "@")
    else
      authority
    end
  end

  defp redact_uri_authority(authority), do: authority

  defp empty_map_to_nil(map) when map == %{}, do: nil
  defp empty_map_to_nil(map), do: map

  defp empty_list_to_nil([]), do: nil
  defp empty_list_to_nil(list), do: list

  defp inspect_message_path(%module{}), do: "%#{inspect(module)}{}"
  defp inspect_message_path(path), do: inspect(path)
end
