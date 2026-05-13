defmodule MollieEx.Error do
  @moduledoc """
  Error returned by MollieEx public API functions.

  Ordinary SDK calls return errors in result tuples:

      {:error, %MollieEx.Error{}}

  Bang functions may raise this exception directly once those functions exist.
  """

  alias MollieEx.Error.Presentation
  alias MollieEx.Error.Storage

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
    %__MODULE__{type: :unexpected, message: Storage.redact_message(message)}
  end

  def exception(attrs) when is_list(attrs) do
    if attrs_list?(attrs) do
      attrs
      |> Map.new()
      |> exception_from_attrs()
    else
      case Storage.redact_message(attrs) do
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
    case Storage.redact_message(message) do
      nil ->
        %__MODULE__{type: :unexpected}

      message ->
        %__MODULE__{type: :unexpected, message: message}
    end
  end

  @impl Exception
  def message(%__MODULE__{} = error), do: Presentation.message(error)

  defp attrs_list?(attrs) do
    Keyword.keyword?(attrs)
  end

  defp exception_from_attrs(attrs) do
    attrs
    |> normalize_attrs()
    |> normalize_type()
    |> Map.put_new(:type, :unexpected)
    |> Storage.sanitize_attrs()
    |> then(&struct!(__MODULE__, &1))
  end

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
end

defimpl Inspect, for: MollieEx.Error do
  def inspect(error, _opts) do
    safe_error =
      error
      |> Map.from_struct()
      |> Map.delete(:idempotency_key_fingerprint)
      |> MollieEx.Error.exception()

    MollieEx.Error.Presentation.inspect_error(safe_error)
  end
end
