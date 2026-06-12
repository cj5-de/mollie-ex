defmodule MollieEx.HTTP.Telemetry do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.{Request, Response}

  @spec start(Client.t(), Request.t()) :: integer()
  def start(%Client{} = client, %Request{} = request) do
    start_time = System.monotonic_time()

    execute(client, [:request, :start], %{system_time: System.system_time()}, request)

    start_time
  end

  @spec emit_result(
          Client.t(),
          Request.t(),
          {:ok, Response.t()} | {:error, Error.t()},
          integer()
        ) :: :ok
  def emit_result(client, request, {:ok, %Response{} = response}, start_time) do
    execute(
      client,
      [:request, :stop],
      duration_measurements(start_time),
      request,
      status: response.status
    )
  end

  def emit_result(client, request, {:error, %Error{type: :decode} = error}, start_time) do
    metadata = error_metadata(error)

    execute(
      client,
      [:decode, :exception],
      duration_measurements(start_time),
      request,
      metadata
    )

    execute(
      client,
      [:request, :exception],
      duration_measurements(start_time),
      request,
      metadata
    )
  end

  def emit_result(client, request, {:error, %Error{status: status} = error}, start_time)
      when is_integer(status) do
    metadata = error_metadata(error)

    execute(
      client,
      [:request, :stop],
      duration_measurements(start_time),
      request,
      metadata
    )

    if status == 429 do
      execute(
        client,
        [:rate_limit],
        duration_measurements(start_time),
        request,
        metadata
      )
    end

    :ok
  end

  def emit_result(client, request, {:error, %Error{} = error}, start_time) do
    execute(
      client,
      [:request, :exception],
      duration_measurements(start_time),
      request,
      error_metadata(error)
    )
  end

  defp duration_measurements(start_time), do: %{duration: System.monotonic_time() - start_time}

  defp error_metadata(%Error{} = error) do
    [
      status: error.status,
      error_type: error.type,
      reason: safe_reason(error.reason)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp safe_reason(reason) when is_atom(reason), do: reason
  defp safe_reason(_reason), do: nil

  defp execute(client, event, measurements, request, extra_metadata \\ []) do
    :telemetry.execute(
      client.telemetry_prefix ++ event,
      measurements,
      metadata(request, extra_metadata)
    )
  end

  defp metadata(%Request{} = request, extra_metadata) do
    [
      operation: request.operation,
      method: method_name(request.method),
      path_template: request.path_template || request.path,
      testmode: request.testmode
    ]
    |> Keyword.merge(extra_metadata)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp method_name(method) when is_atom(method) do
    method
    |> Atom.to_string()
    |> String.upcase()
  end

  defp method_name(method) when is_binary(method), do: String.upcase(method)
  defp method_name(method), do: inspect(method)
end
