defmodule MollieEx.Resources.RequestRunner do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.{Request, Response, Telemetry, Transport}
  alias MollieEx.Resources.ListDecoder

  @type decode_result :: {:ok, term()} | {:error, Error.t()}
  @type decoder :: (Response.t() -> decode_result())
  @type item_decoder :: (Response.t() -> decode_result())

  @spec decode(Client.t(), Request.t(), keyword(), decoder()) :: decode_result()
  def decode(%Client{} = client, %Request{} = request, transport_opts, decoder)
      when is_list(transport_opts) and is_function(decoder, 1) do
    run(client, request, transport_opts, decoder)
  end

  @spec decode_list(Client.t(), Request.t(), keyword(), String.t(), atom(), item_decoder()) ::
          decode_result()
  def decode_list(
        %Client{} = client,
        %Request{} = request,
        transport_opts,
        embedded_key,
        operation,
        item_decoder
      )
      when is_list(transport_opts) and is_binary(embedded_key) and is_atom(operation) and
             is_function(item_decoder, 1) do
    decode(client, request, transport_opts, fn %Response{} = response ->
      ListDecoder.from_response(response, embedded_key, operation, item_decoder)
    end)
  end

  @spec expect_empty(Client.t(), Request.t(), keyword(), non_neg_integer(), term(), atom()) ::
          decode_result()
  def expect_empty(
        %Client{} = client,
        %Request{} = request,
        transport_opts,
        expected_status,
        success_value,
        invalid_reason
      )
      when is_list(transport_opts) and is_integer(expected_status) and is_atom(invalid_reason) do
    decode(client, request, transport_opts, fn %Response{} = response ->
      decode_empty_response(response, request, expected_status, success_value, invalid_reason)
    end)
  end

  defp run(%Client{} = client, %Request{} = request, transport_opts, decoder) do
    start_time = Telemetry.start(client, request)
    transport_opts = Keyword.put(transport_opts, :telemetry, false)

    case Transport.request(client, request, transport_opts) do
      {:ok, %Response{} = response} ->
        result = decoder.(response)
        emit_decoded_result(client, request, response, result, start_time)
        result

      {:error, %Error{} = error} = result ->
        Telemetry.emit_result(client, request, result, start_time)
        {:error, error}
    end
  end

  defp emit_decoded_result(client, request, response, {:ok, _decoded}, start_time) do
    Telemetry.emit_result(client, request, {:ok, response}, start_time)
  end

  defp emit_decoded_result(client, request, _response, {:error, %Error{} = error}, start_time) do
    Telemetry.emit_result(client, request, {:error, error}, start_time)
  end

  defp decode_empty_response(
         %Response{status: expected_status, body: nil},
         _request,
         expected_status,
         success_value,
         _invalid_reason
       ) do
    {:ok, success_value}
  end

  defp decode_empty_response(
         %Response{} = response,
         %Request{} = request,
         _expected_status,
         _success_value,
         invalid_reason
       ) do
    {:error,
     Error.exception(
       type: :decode,
       status: response.status,
       headers: response.headers,
       raw: response.raw,
       reason: invalid_reason,
       operation: request.operation
     )}
  end
end
