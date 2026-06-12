defmodule MollieEx.HTTP.Idempotency do
  @moduledoc false

  alias MollieEx.Error
  alias MollieEx.HTTP.Request

  @spec validate_request(Request.t()) :: :ok | {:error, Error.t()}
  def validate_request(%Request{idempotency_policy: :required} = request) do
    case key_status(request.idempotency_key) do
      :valid -> :ok
      :missing -> missing_key_error(request)
      :invalid -> invalid_key_error(request)
    end
  end

  def validate_request(%Request{idempotency_policy: :optional, idempotency_key: key} = request)
      when is_binary(key) do
    case key_status(key) do
      :valid -> :ok
      :missing -> :ok
      :invalid -> invalid_key_error(request)
    end
  end

  def validate_request(%Request{}), do: :ok

  @spec valid_key?(term()) :: boolean()
  def valid_key?(key) when is_binary(key), do: key_status(key) == :valid
  def valid_key?(_key), do: false

  @spec reject_custom_headers([{term(), term()}]) :: [{term(), term()}]
  def reject_custom_headers(headers) do
    Enum.reject(headers, fn {name, _value} -> key_header?(name) end)
  end

  @spec put_header([{String.t(), String.t()}], Request.t()) :: [{String.t(), String.t()}]
  def put_header(headers, %Request{idempotency_policy: policy, idempotency_key: key})
      when policy in [:optional, :required] and is_binary(key) do
    key = String.trim(key)

    if key == "" do
      headers
    else
      [{"idempotency-key", key} | headers]
    end
  end

  def put_header(headers, %Request{}), do: headers

  defp key_status(key) when is_binary(key) do
    cond do
      not String.valid?(key) or contains_header_unsafe_byte?(key) -> :invalid
      String.trim(key) == "" -> :missing
      true -> :valid
    end
  end

  defp key_status(_key), do: :missing

  defp missing_key_error(%Request{} = request) do
    {:error,
     Error.exception(
       type: :configuration,
       reason: :missing_idempotency_key,
       method: request.method,
       path: request.path,
       operation: request.operation
     )}
  end

  defp invalid_key_error(%Request{} = request) do
    {:error,
     Error.exception(
       type: :configuration,
       reason: :invalid_idempotency_key,
       method: request.method,
       path: request.path,
       operation: request.operation,
       idempotency_key_fingerprint: request.idempotency_key
     )}
  end

  defp contains_header_unsafe_byte?(<<>>), do: false

  defp contains_header_unsafe_byte?(<<byte, _rest::binary>>)
       when byte < 32 or byte > 126,
       do: true

  defp contains_header_unsafe_byte?(<<_byte, rest::binary>>),
    do: contains_header_unsafe_byte?(rest)

  defp key_header?(name) when is_binary(name),
    do: String.downcase(name) == "idempotency-key"

  defp key_header?(name) when is_atom(name) do
    name
    |> Atom.to_string()
    |> String.replace("_", "-")
    |> String.downcase()
    |> Kernel.==("idempotency-key")
  end

  defp key_header?(_name), do: false
end
