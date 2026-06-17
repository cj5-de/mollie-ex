defmodule MollieEx.BalancesTest do
  use ExUnit.Case, async: false

  alias MollieEx.Balance
  alias MollieEx.Balances
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.TestSupport
  alias MollieEx.Types.Link

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_balances_secret"
  @oauth_token "access_balances_secret"
  @organization_token "org_balances_secret"

  test "lists balances with pagination, currency, and testmode options" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/balances"

      assert URI.decode_query(conn.query_string) == %{
               "currency" => "EUR",
               "from" => "bal_start",
               "limit" => "2",
               "testmode" => "true"
             }

      assert header(conn, "authorization") == "Bearer #{@oauth_token}"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "balances/list_success.json", 200)
    end)

    assert {:ok, %MollieList{} = balance_list} =
             Balances.list(oauth_client(),
               currency: "EUR",
               from: "bal_start",
               limit: 2,
               testmode: true
             )

    assert balance_list.count == 2

    assert [
             %Balance{id: "bal_gVMhHKqSSRYJyPsuoPNFH"} = primary_balance,
             %Balance{id: "bal_gVMhHKqSSRYJyPsuoPABC"}
           ] = balance_list.data

    assert primary_balance.resource == "balance"
    assert primary_balance.description == "Primary EUR balance"
    assert primary_balance.available_amount.value == "100.00"
    assert primary_balance.pending_amount.value == "15.00"
    assert primary_balance.transfer_threshold.value == "40.00"
    assert primary_balance.transfer_destination["type"] == "bank-account"
    assert primary_balance.raw["unexpectedFutureField"] == true

    assert %Link{href: "https://api.mollie.com/v2/balances/bal_gVMhHKqSSRYJyPsuoPNFH"} =
             primary_balance.links["self"]

    assert %Link{href: "https://api.mollie.com/v2/balances?currency=EUR&from=bal_start&limit=2"} =
             balance_list.links["self"]

    assert %Link{
             href: "https://api.mollie.com/v2/balances?from=bal_gVMhHKqSSRYJyPsuoPABC&limit=2"
           } =
             balance_list.links["next"]
  end

  test "gets a balance with path encoding and client-level testmode" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/balances/bal_123%2F456"
      assert URI.decode_query(conn.query_string) == %{"testmode" => "true"}
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "balances/get_success.json", 200)
    end)

    assert {:ok, %Balance{} = balance} =
             Balances.get(organization_client(testmode: true), "bal_123/456")

    assert balance.id == "bal_gVMhHKqSSRYJyPsuoPNFH"
    assert balance.available_amount.currency == "EUR"
    assert balance.raw["unexpectedFutureField"] == %{"visible" => true}

    assert %Link{href: "https://docs.mollie.com/reference/v2/balances-api/get-balance"} =
             balance.links["documentation"]
  end

  test "gets the primary balance" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/balances/primary"
      assert URI.decode_query(conn.query_string) == %{"testmode" => "false"}
      assert header(conn, "authorization") == "Bearer dynamic_balances_secret"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "balances/get_success.json", 200)
    end)

    assert {:ok, %Balance{id: "bal_gVMhHKqSSRYJyPsuoPNFH"}} =
             Balances.primary(token_provider_client(), testmode: false)
  end

  test "rejects API-key clients and invalid input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"count" => 0, "_embedded" => %{"balances" => []}, "_links" => %{}})
    end)

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Balances.list(api_key_client())

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Balances.get(api_key_client(), "bal_12345678")

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Balances.primary(api_key_client())

    assert {:error, %Error{reason: :invalid_balance_id}} =
             Balances.get(oauth_client(), "")

    assert {:error, %Error{reason: {:invalid_option, :currency}}} =
             Balances.list(oauth_client(), currency: "")

    assert {:error, %Error{reason: {:invalid_option, :from}}} =
             Balances.list(oauth_client(), from: "")

    assert {:error, %Error{reason: {:invalid_option, :limit}}} =
             Balances.list(oauth_client(), limit: 251)

    assert {:error, %Error{reason: :invalid_testmode}} =
             Balances.get(oauth_client(), "bal_12345678", testmode: "yes")

    assert {:error, %Error{reason: {:unsupported_option, :profile_id}}} =
             Balances.list(oauth_client(), profile_id: "pfl_123")

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             Balances.primary(oauth_client(), idempotency_key: "read-123")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Balances.get(oauth_client(), "bal_12345678", unknown: true)

    assert {:error, %Error{reason: :invalid_options}} =
             Balances.primary(oauth_client(), :not_options)

    assert {:error, %Error{reason: :invalid_client}} = Balances.list(:not_a_client)

    refute_receive :request_sent, 10
  end

  test "returns API errors for balances" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{
        "status" => 404,
        "title" => "Not Found",
        "detail" => "No balance exists with this ID.",
        "_links" => %{"documentation" => %{"href" => "https://docs.mollie.com/"}}
      })
    end)

    assert {:error, %Error{} = error} =
             Balances.get(organization_client(max_retries: 0), "bal_missing")

    assert error.type == :not_found
    assert error.status == 404
    assert error.raw["detail"] == "No balance exists with this ID."
  end

  test "returns timeout errors for balances" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Error{} = error} =
             Balances.list(organization_client(max_retries: 0))

    assert error.type == :timeout
    assert error.operation == :balances_list
  end

  test "retries read requests without idempotency keys" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/balances"
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/balances"
      assert header(conn, "idempotency-key") == nil

      fixture_response(conn, "balances/list_success.json", 200)
    end)

    assert {:ok, %MollieList{count: 2}} =
             Balances.list(organization_client(max_retries: 1))
  end

  test "returns decode errors for malformed JSON responses" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.send_resp(200, "{")
    end)

    assert {:error, %Error{} = error} =
             Balances.primary(organization_client([]))

    assert error.type == :decode
    assert error.status == 200
    assert error.operation == :balances_primary
  end

  test "returns decode errors for invalid balance response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "balance"})
    end)

    assert {:error, %Error{} = error} =
             Balances.get(organization_client([]), "bal_12345678")

    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_balance_response
    assert error.operation == :balances_get
    assert error.raw == %{"resource" => "balance"}
  end

  test "returns decode errors for invalid balance list items" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"balances" => [%{"resource" => "balance"}]},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{type: :decode, reason: :invalid_balance_response}} =
             Balances.list(oauth_client())
  end

  defp api_key_client do
    TestSupport.client(__MODULE__, api_key: @api_key)
  end

  defp oauth_client do
    TestSupport.client(__MODULE__, oauth_token: @oauth_token)
  end

  defp token_provider_client do
    TestSupport.client(__MODULE__, token_provider: {__MODULE__, :fetch_token, []})
  end

  def fetch_token, do: "dynamic_balances_secret"

  defp organization_client(opts) do
    opts
    |> Keyword.put(:organization_token, @organization_token)
    |> then(&TestSupport.client(__MODULE__, &1))
  end
end
