defmodule MollieEx.HTTP.FinchAdapterTest do
  use ExUnit.Case, async: true

  alias Finch.Pool.Manager, as: FinchPoolManager
  alias MollieEx.Client
  alias MollieEx.HTTP.FinchAdapter

  @api_key "test_finch_secret"

  test "adds default Finch connection options" do
    client = client(connect_timeout: 1_234)

    options = FinchAdapter.put_options([method: :get], client, 5_678)

    assert Keyword.fetch!(options, :connect_options) == [timeout: 1_234]
    assert is_function(Keyword.fetch!(options, :finch_request), 4)
    refute Keyword.has_key?(options, :finch)
    refute Keyword.has_key?(options, :plug)
  end

  test "uses caller supplied Finch instances without Req connect options" do
    finch_name = :"#{__MODULE__}.Finch.#{System.unique_integer([:positive])}"
    client = client(finch_name: finch_name)

    options = FinchAdapter.put_options([method: :get], client, 5_678)

    assert Keyword.fetch!(options, :finch) == finch_name
    assert is_function(Keyword.fetch!(options, :finch_request), 4)
    refute Keyword.has_key?(options, :connect_options)
    refute Keyword.has_key?(options, :plug)
  end

  test "uses Req.Test plug instead of Finch options" do
    client = client(transport: {:req_test, __MODULE__}, finch_name: __MODULE__)

    options = FinchAdapter.put_options([method: :get], client, 5_678)

    assert Keyword.fetch!(options, :plug) == {Req.Test, __MODULE__}
    refute Keyword.has_key?(options, :finch_request)
    refute Keyword.has_key?(options, :finch)
    refute Keyword.has_key?(options, :connect_options)
  end

  test "skips pool startup for Req.Test and default Finch clients" do
    assert :ok = FinchAdapter.ensure_pool(client())
    assert :ok = FinchAdapter.ensure_pool(client(transport: {:req_test, __MODULE__}))
  end

  test "checks custom Finch supervisors without starting destination pools" do
    finch_name = :"#{__MODULE__}.LazyFinch.#{System.unique_integer([:positive])}"

    start_supervised!(
      {Finch,
       name: finch_name,
       pools: %{
         :default => [size: 1, count: 2]
       }}
    )

    client = client(finch_name: finch_name)
    pool = Finch.Pool.new(client.base_url)

    assert FinchPoolManager.get_pool_supervisor(finch_name, pool) == :not_found
    assert :ok = FinchAdapter.ensure_pool(client)
    assert FinchPoolManager.get_pool_supervisor(finch_name, pool) == :not_found
  end

  test "maps missing custom Finch supervisors to transport errors" do
    finch_name = :"#{__MODULE__}.MissingFinch.#{System.unique_integer([:positive])}"

    assert {:error, %Req.TransportError{reason: :finch_not_started}} =
             FinchAdapter.ensure_pool(client(finch_name: finch_name))
  end

  test "maps malformed Finch names to transport errors" do
    client = struct!(client(), finch_name: "MyApp.MollieFinch")

    assert {:error, %Req.TransportError{reason: :finch_not_started}} =
             FinchAdapter.ensure_pool(client)
  end

  test "request function maps missing Finch supervisors to transport errors" do
    finch_name = :"#{__MODULE__}.RequestMissingFinch.#{System.unique_integer([:positive])}"
    request_fun = FinchAdapter.request_fun(100)

    {_req, error} =
      request_fun.(
        Req.new(),
        Finch.build(:get, "http://127.0.0.1:9/v2/payments/tr_123"),
        finch_name,
        []
      )

    assert %Req.TransportError{reason: :finch_not_started} = error
  end

  defp client(opts \\ []) do
    [api_key: @api_key]
    |> Keyword.merge(opts)
    |> Client.new!()
  end
end
