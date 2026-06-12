defmodule MollieEx.Resources.ListDecoder do
  @moduledoc false

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.List
  alias MollieEx.Types.Link

  @type item_decoder :: (Response.t() -> {:ok, term()} | {:error, Error.t()})

  @spec from_response(Response.t(), String.t(), atom(), item_decoder()) ::
          {:ok, List.t()} | {:error, Error.t()}
  def from_response(%Response{body: %{} = body} = response, embedded_key, operation, item_decoder)
      when is_binary(embedded_key) and is_atom(operation) and is_function(item_decoder, 1) do
    with {:ok, count} <- count(body, response, operation),
         {:ok, embedded} <- embedded(body, response, operation),
         {:ok, links} <- links(body, response, operation),
         {:ok, items} <- embedded_items(embedded, embedded_key, response, operation),
         {:ok, data} <- decode_items(items, response, item_decoder) do
      {:ok, %List{data: data, count: count, links: links, raw: body}}
    end
  end

  def from_response(%Response{} = response, _embedded_key, operation, _item_decoder),
    do: invalid_response_error(response, operation)

  defp count(%{"count" => count}, _response, _operation)
       when is_integer(count) and count >= 0 do
    {:ok, count}
  end

  defp count(_body, response, operation), do: invalid_response_error(response, operation)

  defp embedded(%{"_embedded" => embedded}, _response, _operation) when is_map(embedded) do
    {:ok, embedded}
  end

  defp embedded(_body, response, operation), do: invalid_response_error(response, operation)

  defp links(%{"_links" => links}, _response, _operation) when is_map(links) do
    {:ok, Map.new(links, fn {rel, link} -> {rel, Link.from(link)} end)}
  end

  defp links(_body, response, operation), do: invalid_response_error(response, operation)

  defp embedded_items(embedded, embedded_key, response, operation) do
    case Map.get(embedded, embedded_key, []) do
      items when is_list(items) -> {:ok, items}
      _items -> invalid_response_error(response, operation)
    end
  end

  defp decode_items(items, %Response{} = response, item_decoder) do
    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, decoded_items} ->
      item_response = %Response{response | body: item, raw: item}

      case item_decoder.(item_response) do
        {:ok, decoded_item} -> {:cont, {:ok, [decoded_item | decoded_items]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, decoded_items} -> {:ok, Enum.reverse(decoded_items)}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp invalid_response_error(%Response{} = response, operation) do
    {:error,
     Error.exception(
       type: :decode,
       status: response.status,
       headers: response.headers,
       raw: response.raw,
       reason: :invalid_list_response,
       operation: operation
     )}
  end
end
