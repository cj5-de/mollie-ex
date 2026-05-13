defmodule MollieEx.Error do
  @moduledoc """
  Error returned by MollieEx public API functions.

  Ordinary SDK calls return errors in result tuples:

      {:error, %MollieEx.Error{}}

  Bang functions may raise this exception directly once those functions exist.
  """

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

  @error_type_set MapSet.new(@error_types)
  @string_error_types Map.new(@error_types, &{Atom.to_string(&1), &1})

  @type error_type ::
          :api_error
          | :authentication
          | :authorization
          | :not_found
          | :gone
          | :validation
          | :rate_limited
          | :server_error
          | :timeout
          | :transport
          | :decode
          | :configuration
          | :unexpected

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t() | nil,
          status: non_neg_integer() | nil,
          title: String.t() | nil,
          detail: String.t() | nil,
          field: String.t() | nil,
          reason: term(),
          method: atom() | String.t() | nil,
          path: String.t() | nil,
          operation: atom() | nil,
          request_id: String.t() | nil,
          idempotency_key_fingerprint: String.t() | nil,
          links: term(),
          headers: map() | keyword() | [{term(), term()}] | nil,
          body: term(),
          raw: term(),
          source: term()
        }

  @enforce_keys [:type]
  @fields [
    :type,
    :message,
    :status,
    :title,
    :detail,
    :field,
    :reason,
    :method,
    :path,
    :operation,
    :request_id,
    :idempotency_key_fingerprint,
    :links,
    :headers,
    :body,
    :raw,
    :source
  ]

  @field_set MapSet.new(@fields)
  @string_fields Map.new(@fields, &{Atom.to_string(&1), &1})

  defexception [
    :type,
    :message,
    :status,
    :title,
    :detail,
    :field,
    :reason,
    :method,
    :path,
    :operation,
    :request_id,
    :idempotency_key_fingerprint,
    :links,
    :headers,
    :body,
    :raw,
    :source
  ]

  @impl Exception
  def exception(message) when is_binary(message) do
    %__MODULE__{type: :unexpected, message: redact_message(message)}
  end

  def exception(attrs) when is_list(attrs) do
    if attrs_list?(attrs) do
      attrs
      |> Map.new()
      |> exception_from_attrs()
    else
      case redact_message(attrs) do
        nil ->
          %__MODULE__{type: :unexpected}

        message ->
          %__MODULE__{type: :unexpected, message: message}
      end
    end
  end

  def exception(attrs) when is_map(attrs) do
    attrs
    |> exception_from_attrs()
  end

  def exception(message) do
    case redact_message(message) do
      nil ->
        %__MODULE__{type: :unexpected}

      message ->
        %__MODULE__{type: :unexpected, message: message}
    end
  end

  defp attrs_list?(attrs) do
    Keyword.keyword?(attrs)
  end

  defp exception_from_attrs(attrs) do
    attrs
    |> normalize_attrs()
    |> normalize_type()
    |> Map.put_new(:type, :unexpected)
    |> redact_attrs()
    |> then(&struct!(__MODULE__, &1))
  end

  @impl Exception
  def message(%__MODULE__{message: message}) when is_binary(message) and message != "" do
    Redaction.redact_text(message)
  end

  def message(%__MODULE__{} = error) do
    metadata =
      [
        status: error.status,
        title: error.title,
        detail: error.detail,
        field: error.field,
        reason: error.reason,
        method: error.method,
        path: error.path,
        operation: error.operation,
        request_id: error.request_id
      ]
      |> Enum.flat_map(&message_part/1)

    [type_message(error.type), metadata_message(metadata)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp redact_attrs(attrs) do
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
    |> redact_attr(:idempotency_key_fingerprint, &redact_metadata_value/1)
    |> redact_attr(:links, &redact_payload/1)
    |> redact_attr(:headers, &redact_headers/1)
    |> redact_attr(:body, &redact_payload/1)
    |> redact_attr(:raw, &redact_payload/1)
    |> redact_attr(:source, &redact_payload/1)
  end

  defp redact_attr(attrs, key, fun) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> Map.put(attrs, key, fun.(value))
      :error -> attrs
    end
  end

  defp redact_message(nil), do: nil

  defp redact_message(message) when is_binary(message) do
    Redaction.redact_text(message)
  end

  defp redact_message(message) when is_list(message) do
    case safe_iodata_to_binary(message) do
      {:ok, message} ->
        Redaction.redact_text(message)

      :error ->
        message
        |> Redaction.redact()
        |> safe_inspect_text()
        |> Redaction.redact_text()
    end
  end

  defp redact_message(message) do
    message
    |> Redaction.redact()
    |> safe_inspect_text()
    |> Redaction.redact_text()
  end

  defp safe_iodata_to_binary(value) do
    {:ok, IO.iodata_to_binary(value)}
  rescue
    ArgumentError -> :error
    FunctionClauseError -> :error
    UnicodeConversionError -> :error
  end

  defp safe_inspect_text(%module{}), do: "%#{inspect(module)}{}"

  defp safe_inspect_text(value) do
    inspect(value)
  rescue
    Protocol.UndefinedError -> inspect_message_path(value)
  end

  defp redact_reason(reason) when is_atom(reason), do: reason
  defp redact_reason(reason), do: redact_metadata_value(reason)

  defp redact_metadata_value(value) when is_binary(value), do: Redaction.redact_text(value)
  defp redact_metadata_value(value) when is_atom(value), do: value

  defp redact_metadata_value(value) when is_list(value) do
    case safe_iodata_to_binary(value) do
      {:ok, value} ->
        Redaction.redact_text(value)

      :error ->
        Redaction.redact(value)
    end
  end

  defp redact_metadata_value(%module{}), do: "%#{inspect(module)}{}"
  defp redact_metadata_value(value), do: Redaction.redact(value)

  defp redact_payload(value), do: Redaction.redact(value)

  defp redact_headers(headers) when is_map(headers) or is_list(headers) or is_nil(headers) do
    Redaction.redact_headers(headers)
  end

  defp redact_headers(headers), do: Redaction.redact(headers)

  defp redact_path(%URI{} = path), do: Redaction.redact(path)
  defp redact_path(%module{}), do: "%#{inspect(module)}{}"

  defp redact_path(path) when is_list(path) do
    case safe_iodata_to_binary(path) do
      {:ok, path} ->
        Redaction.redact_text(path)

      :error ->
        Redaction.redact(path)
    end
  end

  defp redact_path(path), do: Redaction.redact(path)

  defp normalize_attrs(attrs) do
    attrs =
      if Map.has_key?(attrs, :__struct__) do
        Map.delete(attrs, :__struct__)
      else
        attrs
      end

    Enum.reduce(attrs, %{}, fn {key, value}, normalized ->
      case normalize_attr_key(key) do
        {:ok, key} -> Map.put(normalized, key, value)
        :drop -> normalized
      end
    end)
  end

  defp normalize_attr_key(key) when is_atom(key) do
    if MapSet.member?(@field_set, key) do
      {:ok, key}
    else
      :drop
    end
  end

  defp normalize_attr_key(key) when is_binary(key) do
    case Map.fetch(@string_fields, key) do
      {:ok, key} -> {:ok, key}
      :error -> :drop
    end
  end

  defp normalize_attr_key(_key), do: :drop

  defp normalize_type(%{type: type} = attrs) do
    case normalize_type_value(type) do
      {:ok, type} -> Map.put(attrs, :type, type)
      :drop -> Map.delete(attrs, :type)
    end
  end

  defp normalize_type(attrs), do: attrs

  defp normalize_type_value(type) when is_atom(type) do
    if MapSet.member?(@error_type_set, type) do
      {:ok, type}
    else
      :drop
    end
  end

  defp normalize_type_value(type) when is_binary(type) do
    type =
      type
      |> String.trim()
      |> String.downcase()
      |> String.replace(~r/[-\s]+/, "_")

    case Map.fetch(@string_error_types, type) do
      {:ok, type} -> {:ok, type}
      :error -> :drop
    end
  end

  defp normalize_type_value(_type), do: :drop

  defp type_message(type) do
    type =
      type
      |> to_string()
      |> String.replace("_", " ")

    "MollieEx #{type} error"
  end

  defp metadata_message([]), do: nil

  defp metadata_message(parts) do
    "(" <> Enum.join(parts, ", ") <> ")"
  end

  defp message_part({_key, nil}), do: []
  defp message_part({_key, ""}), do: []

  defp message_part({:method, method}) do
    case safe_metadata_text(method) do
      nil ->
        []

      text ->
        text = if is_atom(method) or is_binary(method), do: String.upcase(text), else: text
        ["method: #{text}"]
    end
  end

  defp message_part({:path, path}) do
    ["path: #{format_message_path(path)}"]
  end

  defp message_part({:reason, reason}) when is_atom(reason) do
    ["reason: #{reason}"]
  end

  defp message_part({:reason, reason}) when is_binary(reason) do
    ["reason: #{Redaction.redact_text(reason)}"]
  end

  defp message_part({:reason, reason}) do
    case safe_metadata_text(reason) do
      nil -> []
      reason -> ["reason: #{reason}"]
    end
  end

  defp message_part({key, value})
       when key in [:status, :title, :detail, :field, :operation, :request_id] do
    case safe_metadata_text(value) do
      nil -> []
      value -> ["#{key}: #{value}"]
    end
  end

  defp message_part(_field), do: []

  defp safe_metadata_text(nil), do: nil
  defp safe_metadata_text(""), do: nil

  defp safe_metadata_text(value) when is_binary(value) do
    Redaction.redact_text(value)
  end

  defp safe_metadata_text(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> Redaction.redact_text()
  end

  defp safe_metadata_text(value) when is_number(value) do
    value
    |> to_string()
    |> Redaction.redact_text()
  end

  defp safe_metadata_text(value) when is_list(value) do
    case safe_iodata_to_binary(value) do
      {:ok, value} ->
        Redaction.redact_text(value)

      :error ->
        value
        |> Redaction.redact()
        |> safe_inspect_text()
        |> Redaction.redact_text()
    end
  end

  defp safe_metadata_text(%module{}), do: "%#{inspect(module)}{}"

  defp safe_metadata_text(value) do
    value
    |> Redaction.redact()
    |> safe_inspect_text()
    |> Redaction.redact_text()
  end

  defp format_message_path(path) do
    path
    |> Redaction.redact()
    |> safe_path_to_string()
    |> Redaction.redact_text()
  end

  defp safe_path_to_string(path) do
    to_string(path)
  rescue
    ArgumentError -> inspect_message_path(path)
    Protocol.UndefinedError -> inspect_message_path(path)
    UnicodeConversionError -> inspect_message_path(path)
  end

  defp inspect_message_path(%module{}), do: "%#{inspect(module)}{}"
  defp inspect_message_path(path), do: inspect(path)
end

defimpl Inspect, for: MollieEx.Error do
  alias MollieEx.Redaction

  def inspect(error, _opts) do
    fields =
      [
        type: error.type,
        message: redact_text(error.message),
        status: error.status,
        title: redact_text(error.title),
        detail: redact_text(error.detail),
        field: redact_text(error.field),
        reason: safe_value(error.reason),
        method: error.method,
        path: safe_path(error.path),
        operation: error.operation,
        request_id: error.request_id,
        idempotency_key_fingerprint: error.idempotency_key_fingerprint,
        links: safe_value(error.links)
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)

    "#MollieEx.Error<#{fields_text(fields)}>"
  end

  defp fields_text(fields) do
    Enum.map_join(fields, ", ", fn {key, value} ->
      "#{key}: #{Kernel.inspect(value)}"
    end)
  end

  defp redact_text(nil), do: nil
  defp redact_text(value) when is_binary(value), do: Redaction.redact_text(value)
  defp redact_text(value), do: Redaction.redact(value)

  defp safe_path(nil), do: nil
  defp safe_path(value) when is_binary(value), do: Redaction.redact_text(value)
  defp safe_path(%URI{} = value), do: Redaction.redact(value)
  defp safe_path(%module{}), do: "%#{inspect(module)}{}"
  defp safe_path(value), do: Redaction.redact(value)

  defp safe_value(nil), do: nil
  defp safe_value(value) when is_atom(value), do: value
  defp safe_value(value) when is_binary(value), do: Redaction.redact_text(value)
  defp safe_value(%module{}), do: "%#{inspect(module)}{}"
  defp safe_value(value), do: Redaction.redact(value)
end
