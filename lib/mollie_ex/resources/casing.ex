defmodule MollieEx.Resources.Casing do
  @moduledoc false

  @spec to_mollie(term()) :: term()
  def to_mollie(value) when is_list(value), do: Enum.map(value, &to_mollie/1)
  def to_mollie(%_struct{} = value), do: value

  def to_mollie(%{} = value) do
    Map.new(value, fn {key, item} -> {to_mollie_key(key), to_mollie(item)} end)
  end

  def to_mollie(value), do: value

  @spec to_mollie_body(map(), [String.t()]) :: map()
  def to_mollie_body(params, structured_keys) when is_map(params) and is_list(structured_keys) do
    Map.new(params, fn {key, value} ->
      mollie_key = to_mollie_key(key)
      {mollie_key, to_mollie_body_value(mollie_key, value, structured_keys)}
    end)
  end

  @doc false
  @spec to_mollie_key(term()) :: term()
  def to_mollie_key(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> camelize()
  end

  def to_mollie_key(key) when is_binary(key) do
    if String.contains?(key, "_") do
      camelize(key)
    else
      key
    end
  end

  def to_mollie_key(key), do: key

  defp to_mollie_body_value(key, value, structured_keys) do
    if key in structured_keys, do: to_mollie(value), else: value
  end

  defp camelize(key) do
    key
    |> String.split("_")
    |> camelize_parts()
  end

  defp camelize_parts([]), do: ""

  defp camelize_parts([first | rest]) do
    first <> Enum.map_join(rest, &capitalize_part/1)
  end

  defp capitalize_part(<<>>), do: <<>>

  defp capitalize_part(<<first::utf8, rest::binary>>) do
    String.upcase(<<first::utf8>>) <> rest
  end
end
