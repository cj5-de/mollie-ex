defmodule MollieEx.Resources.RequestRunner do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.{Request, Response, Telemetry, Transport}
  alias MollieEx.Resources.ListDecoder

  @type decode_result :: {:ok, term()} | {:error, Error.t()}
  @type build_result :: {:ok, Request.t(), keyword()} | {:error, Error.t()}
  @type decoder_module :: module()
  @type decoder :: (Response.t() -> decode_result())
  @type item_decoder :: (Response.t() -> decode_result())

  @spec run_resource(build_result(), Client.t(), decoder_module(), atom()) :: decode_result()
  def run_resource(
        {:ok, %Request{} = request, transport_opts},
        %Client{} = client,
        decoder_module,
        operation
      )
      when is_list(transport_opts) and is_atom(decoder_module) and is_atom(operation) do
    decode_resource(client, request, transport_opts, decoder_module, operation)
  end

  def run_resource({:error, %Error{}} = error, %Client{}, decoder_module, operation)
      when is_atom(decoder_module) and is_atom(operation),
      do: error

  @spec run_resource_list(build_result(), Client.t(), String.t(), decoder_module(), atom()) ::
          decode_result()
  def run_resource_list(
        {:ok, %Request{} = request, transport_opts},
        %Client{} = client,
        embedded_key,
        decoder_module,
        operation
      )
      when is_list(transport_opts) and is_binary(embedded_key) and is_atom(decoder_module) and
             is_atom(operation) do
    decode_resource_list(client, request, transport_opts, embedded_key, decoder_module, operation)
  end

  def run_resource_list(
        {:error, %Error{}} = error,
        %Client{},
        embedded_key,
        decoder_module,
        operation
      )
      when is_binary(embedded_key) and is_atom(decoder_module) and is_atom(operation),
      do: error

  @spec run_no_content(build_result(), Client.t()) :: decode_result()
  def run_no_content({:ok, %Request{} = request, transport_opts}, %Client{} = client)
      when is_list(transport_opts) do
    expect_no_content(client, request, transport_opts)
  end

  def run_no_content({:error, %Error{}} = error, %Client{}), do: error

  @spec run_accepted(build_result(), Client.t()) :: decode_result()
  def run_accepted({:ok, %Request{} = request, transport_opts}, %Client{} = client)
      when is_list(transport_opts) do
    expect_accepted(client, request, transport_opts)
  end

  def run_accepted({:error, %Error{}} = error, %Client{}), do: error

  @spec decode(Client.t(), Request.t(), keyword(), decoder()) :: decode_result()
  def decode(%Client{} = client, %Request{} = request, transport_opts, decoder)
      when is_list(transport_opts) and is_function(decoder, 1) do
    run(client, request, transport_opts, decoder)
  end

  @spec decode_resource(Client.t(), Request.t(), keyword(), decoder_module(), atom()) ::
          decode_result()
  def decode_resource(
        %Client{} = client,
        %Request{} = request,
        transport_opts,
        decoder_module,
        operation
      )
      when is_list(transport_opts) and is_atom(decoder_module) and is_atom(operation) do
    decode(client, request, transport_opts, fn %Response{} = response ->
      decoder_module.from_response(response, operation)
    end)
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

  @spec decode_resource_list(
          Client.t(),
          Request.t(),
          keyword(),
          String.t(),
          decoder_module(),
          atom()
        ) :: decode_result()
  def decode_resource_list(
        %Client{} = client,
        %Request{} = request,
        transport_opts,
        embedded_key,
        decoder_module,
        operation
      )
      when is_list(transport_opts) and is_binary(embedded_key) and is_atom(decoder_module) and
             is_atom(operation) do
    decode_list(client, request, transport_opts, embedded_key, operation, fn %Response{} =
                                                                               response ->
      decoder_module.from_response(response, operation)
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

  @spec expect_no_content(Client.t(), Request.t(), keyword()) :: decode_result()
  def expect_no_content(%Client{} = client, %Request{} = request, transport_opts)
      when is_list(transport_opts) do
    expect_empty(client, request, transport_opts, 204, :no_content, :invalid_no_content_response)
  end

  @spec expect_accepted(Client.t(), Request.t(), keyword()) :: decode_result()
  def expect_accepted(%Client{} = client, %Request{} = request, transport_opts)
      when is_list(transport_opts) do
    expect_empty(client, request, transport_opts, 202, :accepted, :invalid_accepted_response)
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
