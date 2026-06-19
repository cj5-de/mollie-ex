defmodule MollieEx.BalanceTransfersTest do
  use ExUnit.Case, async: false

  alias MollieEx.BalanceTransfer
  alias MollieEx.BalanceTransfers
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.TestSupport
  alias MollieEx.Types.Link

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_balance_transfers_secret"
  @oauth_token "access_balance_transfers_secret"
  @organization_token "org_balance_transfers_secret"

  test "lists balance transfers with pagination, sort, and testmode options" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/connect/balance-transfers"

      assert URI.decode_query(conn.query_string) == %{
               "from" => "cbt_start",
               "limit" => "2",
               "sort" => "asc",
               "testmode" => "true"
             }

      assert header(conn, "authorization") == "Bearer #{@oauth_token}"
      assert header(conn, "accept") == "application/hal+json"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "balance_transfers/list_success.json", 200)
    end)

    assert {:ok, %MollieList{} = transfer_list} =
             BalanceTransfers.list(oauth_client(),
               from: "cbt_start",
               limit: 2,
               sort: :asc,
               testmode: true
             )

    assert transfer_list.count == 2

    assert [
             %BalanceTransfer{id: "cbt_4KgGJJSZpH"} = first_transfer,
             %BalanceTransfer{id: "cbt_8KhHNOSdpL"} = second_transfer
           ] = transfer_list.data

    assert first_transfer.resource == "connect-balance-transfer"
    assert first_transfer.amount.value == "100.00"
    assert first_transfer.source["id"] == "org_12345678"
    assert first_transfer.destination["id"] == "org_87654321"
    assert first_transfer.raw["unexpectedFutureField"] == true
    assert second_transfer.category == "purchase"

    assert %Link{href: "https://api.mollie.com/v2/connect/balance-transfers/cbt_4KgGJJSZpH"} =
             first_transfer.links["self"]

    assert %Link{
             href:
               "https://api.mollie.com/v2/connect/balance-transfers?from=cbt_start&limit=2&sort=asc"
           } = transfer_list.links["self"]

    assert %Link{
             href:
               "https://api.mollie.com/v2/connect/balance-transfers?from=cbt_8KhHNOSdpL&limit=2"
           } = transfer_list.links["next"]
  end

  test "gets a balance transfer with path encoding and client-level testmode" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/connect/balance-transfers/cbt_123%2F456"
      assert URI.decode_query(conn.query_string) == %{"testmode" => "true"}
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert header(conn, "accept") == "application/hal+json"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "balance_transfers/get_success.json", 200)
    end)

    assert {:ok, %BalanceTransfer{} = transfer} =
             BalanceTransfers.get(organization_client(testmode: true), "cbt_123/456")

    assert transfer.id == "cbt_4KgGJJSZpH"
    assert transfer.status == "created"
    assert transfer.status_reason["code"] == "request_created"
    assert transfer.metadata["reference"] == "transfer-123"
    assert transfer.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "creates a balance transfer with camelCased body and caller idempotency key" do
    expected_body = expected_create_body()

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/connect/balance-transfers"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert header(conn, "accept") == "application/hal+json"
      assert header(conn, "idempotency-key") == "balance-transfer-123"
      assert_json_body(conn, expected_body)

      fixture_response(conn, "balance_transfers/get_success.json", 201)
    end)

    assert {:ok, %BalanceTransfer{} = transfer} =
             BalanceTransfers.create(organization_client([]), create_params(),
               idempotency_key: "balance-transfer-123",
               testmode: true
             )

    assert transfer.id == "cbt_4KgGJJSZpH"
    assert transfer.amount.currency == "EUR"
    assert transfer.source["description"] == "Transfer from Organization A"
    assert transfer.destination["description"] == "Transfer to Organization B"
  end

  test "rejects API-key clients and invalid input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"resource" => "connect-balance-transfer", "id" => "cbt_123"})
    end)

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             BalanceTransfers.list(api_key_client())

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             BalanceTransfers.get(api_key_client(), "cbt_12345678")

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             BalanceTransfers.create(api_key_client(), create_params())

    assert {:error, %Error{reason: :invalid_balance_transfer_id}} =
             BalanceTransfers.get(oauth_client(), "")

    assert {:error, %Error{reason: :invalid_balance_transfer_params}} =
             BalanceTransfers.create(oauth_client(), :not_params)

    assert {:error, %Error{reason: :missing_amount}} =
             BalanceTransfers.create(oauth_client(), Map.delete(create_params(), :amount))

    assert {:error, %Error{reason: :missing_source}} =
             BalanceTransfers.create(oauth_client(), Map.delete(create_params(), :source))

    assert {:error, %Error{reason: :missing_destination}} =
             BalanceTransfers.create(oauth_client(), Map.delete(create_params(), :destination))

    assert {:error, %Error{reason: :missing_description}} =
             BalanceTransfers.create(oauth_client(), Map.delete(create_params(), :description))

    assert {:error, %Error{reason: {:invalid_option, :from}}} =
             BalanceTransfers.list(oauth_client(), from: "")

    assert {:error, %Error{reason: {:invalid_option, :limit}}} =
             BalanceTransfers.list(oauth_client(), limit: 0)

    assert {:error, %Error{reason: {:invalid_option, :sort}}} =
             BalanceTransfers.list(oauth_client(), sort: "newest")

    assert {:error, %Error{reason: :invalid_testmode}} =
             BalanceTransfers.create(oauth_client(), create_params(), testmode: "yes")

    assert {:error, %Error{reason: {:unsupported_option, :profile_id}}} =
             BalanceTransfers.list(oauth_client(), profile_id: "pfl_123")

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             BalanceTransfers.get(oauth_client(), "cbt_12345678", idempotency_key: "read-123")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             BalanceTransfers.create(oauth_client(), create_params(), unknown: true)

    assert {:error, %Error{reason: :invalid_options}} =
             BalanceTransfers.get(oauth_client(), "cbt_12345678", :not_options)

    assert {:error, %Error{reason: :invalid_client}} =
             BalanceTransfers.list(:not_a_client)

    refute_receive :request_sent, 10
  end

  test "returns API errors for balance transfer get" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{
        "status" => 404,
        "title" => "Not Found",
        "detail" => "No balance transfer exists with this ID."
      })
    end)

    assert {:error, %Error{} = error} =
             BalanceTransfers.get(organization_client(max_retries: 0), "cbt_missing")

    assert error.type == :not_found
    assert error.status == 404
    assert error.operation == :balance_transfers_get
  end

  test "returns API errors for balance transfer create" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(422)
      |> Req.Test.json(%{
        "status" => 422,
        "title" => "Unprocessable Entity",
        "detail" => "The source is not allowed."
      })
    end)

    assert {:error, %Error{} = error} =
             BalanceTransfers.create(organization_client(max_retries: 0), create_params())

    assert error.type == :validation
    assert error.status == 422
    assert error.operation == :balance_transfers_create
  end

  test "returns timeout errors for balance transfers" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Error{} = error} =
             BalanceTransfers.list(organization_client(max_retries: 0))

    assert error.type == :timeout
    assert error.operation == :balance_transfers_list
  end

  test "retries read requests without idempotency keys" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/connect/balance-transfers"
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/connect/balance-transfers"
      assert header(conn, "idempotency-key") == nil

      fixture_response(conn, "balance_transfers/list_success.json", 200)
    end)

    assert {:ok, %MollieList{count: 2}} =
             BalanceTransfers.list(organization_client(max_retries: 1))
  end

  test "does not retry create without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    assert {:error, %Error{type: :server_error, status: 503}} =
             BalanceTransfers.create(organization_client(max_retries: 1), create_params())
  end

  test "retries create with the same caller idempotency key and body" do
    expected_body = expected_create_body(testmode: false)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "balance-transfer-123"
      assert_json_body(conn, expected_body)

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "balance-transfer-123"
      assert_json_body(conn, expected_body)
      fixture_response(conn, "balance_transfers/get_success.json", 201)
    end)

    assert {:ok, %BalanceTransfer{id: "cbt_4KgGJJSZpH"}} =
             BalanceTransfers.create(
               organization_client(max_retries: 1),
               create_params(),
               idempotency_key: "balance-transfer-123",
               testmode: false
             )
  end

  test "returns decode errors for malformed JSON responses" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.send_resp(200, "{")
    end)

    assert {:error, %Error{} = error} =
             BalanceTransfers.get(organization_client([]), "cbt_12345678")

    assert error.type == :decode
    assert error.status == 200
    assert error.operation == :balance_transfers_get
  end

  test "returns decode errors for invalid balance transfer response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "connect-balance-transfer"})
    end)

    assert {:error, %Error{} = error} =
             BalanceTransfers.get(organization_client([]), "cbt_12345678")

    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_balance_transfer_response
    assert error.operation == :balance_transfers_get
    assert error.raw == %{"resource" => "connect-balance-transfer"}
  end

  test "returns decode errors for invalid balance transfer list items" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{
          "connect_balance_transfers" => [%{"resource" => "connect-balance-transfer"}]
        },
        "_links" => %{}
      })
    end)

    assert {:error, %Error{type: :decode, reason: :invalid_balance_transfer_response}} =
             BalanceTransfers.list(oauth_client())
  end

  defp api_key_client do
    TestSupport.client(__MODULE__, api_key: @api_key)
  end

  defp oauth_client do
    TestSupport.client(__MODULE__, oauth_token: @oauth_token)
  end

  defp organization_client(opts) do
    opts
    |> Keyword.put(:organization_token, @organization_token)
    |> then(&TestSupport.client(__MODULE__, &1))
  end

  defp create_params do
    %{
      amount: %{currency: "EUR", value: "100.00"},
      source: %{
        type: "organization",
        id: "org_12345678",
        description: "Transfer from Organization A"
      },
      destination: %{
        type: "organization",
        id: "org_87654321",
        description: "Transfer to Organization B"
      },
      description: "Transfer from balance A to balance B",
      category: "manual_correction",
      metadata: %{reference: "transfer-123"}
    }
  end

  defp expected_create_body(opts \\ []) do
    %{
      "amount" => %{"currency" => "EUR", "value" => "100.00"},
      "source" => %{
        "type" => "organization",
        "id" => "org_12345678",
        "description" => "Transfer from Organization A"
      },
      "destination" => %{
        "type" => "organization",
        "id" => "org_87654321",
        "description" => "Transfer to Organization B"
      },
      "description" => "Transfer from balance A to balance B",
      "category" => "manual_correction",
      "metadata" => %{"reference" => "transfer-123"},
      "testmode" => Keyword.get(opts, :testmode, true)
    }
  end
end
