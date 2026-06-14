defmodule MollieEx.TestSupport do
  @moduledoc false

  import ExUnit.Assertions

  alias MollieEx.Client

  @fixtures_root Path.expand("../../fixtures/mollie", __DIR__)

  @spec client(module(), keyword()) :: Client.t()
  def client(test_module, opts) when is_atom(test_module) and is_list(opts) do
    opts
    |> Keyword.put(:transport, {:req_test, test_module})
    |> Client.new!()
  end

  @spec fixture_path(Path.t()) :: Path.t()
  def fixture_path(path) when is_binary(path) do
    if Path.type(path) == :absolute, do: path, else: Path.expand(path, @fixtures_root)
  end

  @spec json_body(Plug.Conn.t()) :: map()
  def json_body(conn) do
    conn
    |> Req.Test.raw_body()
    |> IO.iodata_to_binary()
    |> Jason.decode!()
  end

  @spec assert_json_body(Plug.Conn.t(), map()) :: true
  def assert_json_body(conn, expected) do
    assert json_body(conn) == expected
  end

  @spec assert_empty_body(Plug.Conn.t()) :: true
  def assert_empty_body(conn) do
    assert conn |> Req.Test.raw_body() |> IO.iodata_to_binary() == ""
  end

  @spec header(Plug.Conn.t(), String.t()) :: String.t() | nil
  def header(conn, name) do
    conn.req_headers
    |> List.keyfind(name, 0)
    |> case do
      {^name, value} -> value
      nil -> nil
    end
  end

  @spec fixture_response(Plug.Conn.t(), Path.t(), non_neg_integer()) :: Plug.Conn.t()
  def fixture_response(conn, fixture, status) do
    conn
    |> Plug.Conn.put_resp_header("content-type", "application/hal+json")
    |> Plug.Conn.send_resp(status, fixture |> fixture_path() |> File.read!())
  end

  @spec empty_response(Plug.Conn.t(), non_neg_integer()) :: Plug.Conn.t()
  def empty_response(conn, status), do: Plug.Conn.send_resp(conn, status, "")

  @spec no_content_response(Plug.Conn.t()) :: Plug.Conn.t()
  def no_content_response(conn), do: empty_response(conn, 204)

  def attach_telemetry(prefix, suffixes) when is_list(prefix) and is_list(suffixes) do
    handler_id = {__MODULE__, self(), make_ref()}
    events = Enum.map(suffixes, &(prefix ++ &1))

    :telemetry.attach_many(
      handler_id,
      events,
      &__MODULE__.handle_telemetry/4,
      self()
    )

    ExUnit.Callbacks.on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  def handle_telemetry(event, measurements, metadata, test_pid) do
    send(test_pid, {:telemetry, event, measurements, metadata})
  end

  def assert_success_telemetry(
        prefix,
        operation,
        method,
        path_template,
        status,
        redacted_terms
      ) do
    start_event = prefix ++ [:request, :start]
    stop_event = prefix ++ [:request, :stop]

    assert_receive {:telemetry, ^start_event, %{system_time: system_time}, start_metadata}
    assert is_integer(system_time)
    assert start_metadata.operation == operation
    assert start_metadata.method == method
    assert start_metadata.path_template == path_template

    assert_receive {:telemetry, ^stop_event, %{duration: duration}, stop_metadata}
    assert is_integer(duration)
    assert stop_metadata.status == status
    assert stop_metadata.operation == operation

    telemetry_text = inspect([start_metadata, stop_metadata])

    Enum.each(redacted_terms, fn term ->
      refute telemetry_text =~ term
    end)
  end
end
