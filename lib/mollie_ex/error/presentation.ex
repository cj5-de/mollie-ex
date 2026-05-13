defmodule MollieEx.Error.Presentation do
  @moduledoc false

  alias MollieEx.Error.Credentials
  alias MollieEx.Error.Storage

  @doc false
  def message(%{message: message}) when is_binary(message) and message != "" do
    Credentials.redact_text(message)
  end

  def message(error) do
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

  @doc false
  def inspect_error(error) do
    fields =
      [
        type: error.type,
        message: error.message,
        status: error.status,
        title: error.title,
        detail: error.detail,
        field: error.field,
        reason: error.reason,
        method: error.method,
        path: error.path,
        operation: error.operation,
        request_id: error.request_id,
        links: error.links
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)

    "#MollieEx.Error<#{fields_text(fields)}>"
  end

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
    Credentials.redact_text(value)
  end

  defp safe_metadata_text(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> Credentials.redact_text()
  end

  defp safe_metadata_text(value) when is_number(value) do
    value
    |> to_string()
    |> Credentials.redact_text()
  end

  defp safe_metadata_text(value) when is_list(value) do
    case Storage.safe_iodata_to_binary(value) do
      {:ok, value} ->
        Credentials.redact_text(value)

      :error ->
        value
        |> Storage.redact_term()
        |> Storage.safe_inspect_text()
        |> Credentials.redact_text()
    end
  end

  defp safe_metadata_text(%module{}), do: "%#{inspect(module)}{}"

  defp safe_metadata_text(value) do
    value
    |> Storage.redact_term()
    |> Storage.safe_inspect_text()
    |> Credentials.redact_text()
  end

  defp format_message_path(path) do
    path
    |> Storage.redact_term()
    |> safe_path_to_string()
    |> Credentials.redact_text()
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

  defp fields_text(fields) do
    Enum.map_join(fields, ", ", fn {key, value} ->
      "#{key}: #{Kernel.inspect(value)}"
    end)
  end
end
