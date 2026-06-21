defmodule MollieEx.SettlementsTest do
  use ExUnit.Case, async: false

  alias MollieEx.Capture
  alias MollieEx.Chargeback
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Payment
  alias MollieEx.Refund
  alias MollieEx.Settlement
  alias MollieEx.Settlements
  alias MollieEx.TestSupport
  alias MollieEx.Types.Link

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_settlements_secret"
  @oauth_token "access_settlements_secret"
  @organization_token "org_settlements_secret"

  test "lists settlements with pagination and filter options" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/settlements"

      assert URI.decode_query(conn.query_string) == %{
               "balanceId" => "bal_3kUf4yU2nT",
               "currencies" => "EUR,GBP",
               "from" => "stl_start",
               "limit" => "2",
               "month" => "04",
               "year" => "2024"
             }

      assert header(conn, "authorization") == "Bearer #{@oauth_token}"
      assert header(conn, "accept") == "application/hal+json"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "settlements/list_success.json", 200)
    end)

    assert {:ok, %MollieList{} = settlement_list} =
             Settlements.list(oauth_client(),
               balance_id: "bal_3kUf4yU2nT",
               currencies: "EUR,GBP",
               from: "stl_start",
               limit: 2,
               month: "04",
               year: "2024"
             )

    assert settlement_list.count == 2

    assert [
             %Settlement{id: "stl_jDk30akdN"} = paid_settlement,
             %Settlement{id: "stl_5B8cwPMGnU"} = pending_settlement
           ] = settlement_list.data

    assert paid_settlement.resource == "settlement"
    assert paid_settlement.reference == "1234567.2404.03"
    assert paid_settlement.amount.value == "39.75"
    assert paid_settlement.balance_id == "bal_3kUf4yU2nT"
    assert paid_settlement.invoice_id == "inv_FrvewDA3Pr"
    assert paid_settlement.raw["unexpectedFutureField"] == true
    assert Settlement.paid_out?(paid_settlement)
    assert Settlement.pending?(pending_settlement)

    assert %Link{href: "https://api.mollie.com/v2/settlements/stl_jDk30akdN"} =
             paid_settlement.links["self"]

    assert %Link{href: "https://api.mollie.com/v2/settlements?from=stl_start&limit=2"} =
             settlement_list.links["self"]

    assert %Link{href: "https://api.mollie.com/v2/settlements?from=stl_5B8cwPMGnU&limit=2"} =
             settlement_list.links["next"]
  end

  test "gets a settlement by bank reference with path encoding" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/settlements/1234567.2404%2F03"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert header(conn, "accept") == "application/hal+json"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "settlements/get_success.json", 200)
    end)

    assert {:ok, %Settlement{} = settlement} =
             Settlements.get(organization_client([]), "1234567.2404/03")

    assert settlement.id == "stl_jDk30akdN"
    assert settlement.reference == "1234567.2404.03"
    assert settlement.created_at == "2024-04-05T08:30:00.0Z"
    assert settlement.settled_at == "2024-04-06T09:41:44.0Z"
    assert settlement.periods["2024"]["04"]["revenue"] |> hd() |> Map.get("method") == "ideal"
    assert settlement.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "gets the open settlement" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/settlements/open"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer dynamic_settlements_secret"
      assert header(conn, "accept") == "application/hal+json"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "settlements/get_success.json", 200)
    end)

    assert {:ok, %Settlement{id: "stl_jDk30akdN"}} =
             Settlements.open(token_provider_client())
  end

  test "gets the next settlement" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/settlements/next"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert header(conn, "accept") == "application/hal+json"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "settlements/get_success.json", 200)
    end)

    assert {:ok, %Settlement{id: "stl_jDk30akdN"}} =
             Settlements.next(organization_client([]))
  end

  test "lists settlement payments with pagination, sort, and profile options" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/settlements/stl_jDk30akdN/payments"

      assert URI.decode_query(conn.query_string) == %{
               "from" => "tr_start",
               "limit" => "1",
               "profileId" => "pfl_123",
               "sort" => "asc"
             }

      assert header(conn, "authorization") == "Bearer #{@oauth_token}"
      assert header(conn, "accept") == "application/hal+json"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "settlements/list_payments_success.json", 200)
    end)

    assert {:ok, %MollieList{} = payment_list} =
             Settlements.list_payments(oauth_client(), "stl_jDk30akdN",
               from: "tr_start",
               limit: 1,
               profile_id: "pfl_123",
               sort: :asc
             )

    assert payment_list.count == 1
    assert [%Payment{id: "tr_stl_123"} = payment] = payment_list.data
    assert payment.description == "Settlement payment"
    assert payment.amount.value == "75.00"
    assert payment.raw["unexpectedFutureField"] == %{"visible" => true}

    assert %Link{
             href:
               "https://api.mollie.com/v2/settlements/stl_jDk30akdN/payments?from=tr_next&limit=1"
           } = payment_list.links["next"]
  end

  test "lists settlement captures with pagination and embed options" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/settlements/stl_jDk30akdN/captures"

      assert URI.decode_query(conn.query_string) == %{
               "embed" => "payment",
               "from" => "cpt_start",
               "limit" => "1"
             }

      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert header(conn, "accept") == "application/hal+json"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "settlements/list_captures_success.json", 200)
    end)

    assert {:ok, %MollieList{} = capture_list} =
             Settlements.list_captures(organization_client([]), "stl_jDk30akdN",
               embed: "payment",
               from: "cpt_start",
               limit: 1
             )

    assert capture_list.count == 1
    assert [%Capture{id: "cpt_stl_123"} = capture] = capture_list.data
    assert capture.description == "Settlement capture"
    assert capture.settlement_id == "stl_jDk30akdN"
    assert capture.amount.value == "10.00"
  end

  test "lists settlement refunds with pagination and embed options" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/settlements/stl_jDk30akdN/refunds"

      assert URI.decode_query(conn.query_string) == %{
               "embed" => "payment",
               "from" => "re_start",
               "limit" => "1"
             }

      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert header(conn, "accept") == "application/hal+json"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "settlements/list_refunds_success.json", 200)
    end)

    assert {:ok, %MollieList{} = refund_list} =
             Settlements.list_refunds(organization_client([]), "stl_jDk30akdN",
               embed: "payment",
               from: "re_start",
               limit: 1
             )

    assert refund_list.count == 1
    assert [%Refund{id: "re_stl_123"} = refund] = refund_list.data
    assert refund.description == "Settlement refund"
    assert refund.status == "queued"
    assert refund.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "lists settlement chargebacks with pagination, embed, and testmode options" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/settlements/stl_jDk30akdN/chargebacks"

      assert URI.decode_query(conn.query_string) == %{
               "embed" => "payment",
               "from" => "chb_start",
               "limit" => "1",
               "testmode" => "true"
             }

      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert header(conn, "accept") == "application/hal+json"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "settlements/list_chargebacks_success.json", 200)
    end)

    assert {:ok, %MollieList{} = chargeback_list} =
             Settlements.list_chargebacks(organization_client([]), "stl_jDk30akdN",
               embed: "payment",
               from: "chb_start",
               limit: 1,
               testmode: true
             )

    assert chargeback_list.count == 1
    assert [%Chargeback{id: "chb_stl_123"} = chargeback] = chargeback_list.data
    assert chargeback.reason["code"] == "AC01"
    assert chargeback.settlement_id == "stl_jDk30akdN"
    assert chargeback.amount.value == "10.00"
  end

  test "encodes settlement IDs for subresource paths" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/settlements/1234567.2404%2F03/refunds"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "settlements/list_refunds_success.json", 200)
    end)

    assert {:ok, %MollieList{count: 1}} =
             Settlements.list_refunds(organization_client([]), "1234567.2404/03")
  end

  test "rejects API-key clients and invalid input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"count" => 0, "_embedded" => %{"settlements" => []}, "_links" => %{}})
    end)

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Settlements.list(api_key_client())

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Settlements.get(api_key_client(), "stl_jDk30akdN")

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Settlements.open(api_key_client())

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Settlements.next(api_key_client())

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Settlements.list_payments(api_key_client(), "stl_jDk30akdN")

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Settlements.list_captures(api_key_client(), "stl_jDk30akdN")

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Settlements.list_refunds(api_key_client(), "stl_jDk30akdN")

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Settlements.list_chargebacks(api_key_client(), "stl_jDk30akdN")

    assert {:error, %Error{reason: :invalid_settlement_id}} =
             Settlements.get(oauth_client(), "")

    assert {:error, %Error{reason: :invalid_settlement_id}} =
             Settlements.list_payments(oauth_client(), "")

    assert {:error, %Error{reason: :invalid_settlement_id}} =
             Settlements.list_captures(oauth_client(), "")

    assert {:error, %Error{reason: :invalid_settlement_id}} =
             Settlements.list_refunds(oauth_client(), "")

    assert {:error, %Error{reason: :invalid_settlement_id}} =
             Settlements.list_chargebacks(oauth_client(), "")

    assert {:error, %Error{reason: {:invalid_option, :from}}} =
             Settlements.list(oauth_client(), from: "")

    assert {:error, %Error{reason: {:invalid_option, :limit}}} =
             Settlements.list(oauth_client(), limit: 251)

    assert {:error, %Error{reason: {:invalid_option, :balance_id}}} =
             Settlements.list(oauth_client(), balance_id: "")

    assert {:error, %Error{reason: {:invalid_option, :year}}} =
             Settlements.list(oauth_client(), year: "")

    assert {:error, %Error{reason: {:invalid_option, :month}}} =
             Settlements.list(oauth_client(), month: "")

    assert {:error, %Error{reason: {:invalid_option, :currencies}}} =
             Settlements.list(oauth_client(), currencies: "")

    assert {:error, %Error{reason: {:invalid_option, :from}}} =
             Settlements.list_captures(oauth_client(), "stl_jDk30akdN", from: "")

    assert {:error, %Error{reason: {:invalid_option, :limit}}} =
             Settlements.list_refunds(oauth_client(), "stl_jDk30akdN", limit: 0)

    assert {:error, %Error{reason: {:invalid_option, :sort}}} =
             Settlements.list_payments(oauth_client(), "stl_jDk30akdN", sort: "newest")

    assert {:error, %Error{reason: {:invalid_option, :embed}}} =
             Settlements.list_captures(oauth_client(), "stl_jDk30akdN", embed: "")

    assert {:error, %Error{reason: {:invalid_option, :embed}}} =
             Settlements.list_refunds(oauth_client(), "stl_jDk30akdN", embed: "")

    assert {:error, %Error{reason: {:invalid_option, :embed}}} =
             Settlements.list_chargebacks(oauth_client(), "stl_jDk30akdN", embed: "")

    assert {:error, %Error{reason: :missing_profile_id}} =
             Settlements.list_payments(oauth_client(), "stl_jDk30akdN")

    assert {:error, %Error{reason: {:unsupported_option, :testmode}}} =
             Settlements.list(oauth_client(), testmode: true)

    assert {:error, %Error{reason: {:unsupported_option, :testmode}}} =
             Settlements.list_payments(oauth_client(), "stl_jDk30akdN", testmode: true)

    assert {:error, %Error{reason: {:unsupported_option, :testmode}}} =
             Settlements.list_captures(oauth_client(), "stl_jDk30akdN", testmode: true)

    assert {:error, %Error{reason: {:unsupported_option, :testmode}}} =
             Settlements.list_refunds(oauth_client(), "stl_jDk30akdN", testmode: true)

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             Settlements.get(oauth_client(), "stl_jDk30akdN", idempotency_key: "read-123")

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             Settlements.open(oauth_client(), idempotency_key: "read-123")

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             Settlements.next(oauth_client(), idempotency_key: "read-123")

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             Settlements.list_payments(oauth_client(), "stl_jDk30akdN",
               idempotency_key: "read-123"
             )

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             Settlements.list_captures(oauth_client(), "stl_jDk30akdN",
               idempotency_key: "read-123"
             )

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             Settlements.list_refunds(oauth_client(), "stl_jDk30akdN",
               idempotency_key: "read-123"
             )

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             Settlements.list_chargebacks(oauth_client(), "stl_jDk30akdN",
               idempotency_key: "read-123"
             )

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Settlements.get(oauth_client(), "stl_jDk30akdN", unknown: true)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Settlements.list_refunds(oauth_client(), "stl_jDk30akdN", unknown: true)

    assert {:error, %Error{reason: :invalid_options}} =
             Settlements.open(oauth_client(), :not_options)

    assert {:error, %Error{reason: :invalid_options}} =
             Settlements.get(oauth_client(), "stl_jDk30akdN", :not_options)

    assert {:error, %Error{reason: :invalid_options}} =
             Settlements.list_chargebacks(oauth_client(), "stl_jDk30akdN", :not_options)

    assert {:error, %Error{reason: :invalid_client}} = Settlements.list(:not_a_client)

    assert {:error, %Error{reason: :invalid_client}} =
             Settlements.list_payments(:not_a_client, "stl_jDk30akdN")

    refute_receive :request_sent, 10
  end

  test "returns API errors for settlements" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{
        "status" => 404,
        "title" => "Not Found",
        "detail" => "No settlement exists with this ID."
      })
    end)

    assert {:error, %Error{} = error} =
             Settlements.get(organization_client(max_retries: 0), "stl_missing")

    assert error.type == :not_found
    assert error.status == 404
    assert error.operation == :settlements_get
  end

  test "returns API errors for settlement list filters" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{
        "status" => 400,
        "title" => "Bad Request",
        "detail" => "The from value is not a valid ID."
      })
    end)

    assert {:error, %Error{} = error} =
             Settlements.list(organization_client(max_retries: 0), from: "bad")

    assert error.type == :api_error
    assert error.status == 400
    assert error.operation == :settlements_list
  end

  test "returns API errors for settlement subresource lists" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{
        "status" => 404,
        "title" => "Not Found",
        "detail" => "No settlement exists with this ID."
      })
    end)

    assert {:error, %Error{} = error} =
             Settlements.list_captures(organization_client(max_retries: 0), "stl_missing")

    assert error.type == :not_found
    assert error.status == 404
    assert error.operation == :settlements_list_captures
  end

  test "returns timeout errors for settlements" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Error{} = error} =
             Settlements.list(organization_client(max_retries: 0))

    assert error.type == :timeout
    assert error.operation == :settlements_list
  end

  test "returns timeout errors for settlement subresource lists" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Error{} = error} =
             Settlements.list_refunds(organization_client(max_retries: 0), "stl_jDk30akdN")

    assert error.type == :timeout
    assert error.operation == :settlements_list_refunds
  end

  test "retries read requests without idempotency keys" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/settlements"
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/settlements"
      assert header(conn, "idempotency-key") == nil

      fixture_response(conn, "settlements/list_success.json", 200)
    end)

    assert {:ok, %MollieList{count: 2}} =
             Settlements.list(organization_client(max_retries: 1))
  end

  test "retries settlement subresource reads without idempotency keys" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/settlements/stl_jDk30akdN/refunds"
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/settlements/stl_jDk30akdN/refunds"
      assert header(conn, "idempotency-key") == nil

      fixture_response(conn, "settlements/list_refunds_success.json", 200)
    end)

    assert {:ok, %MollieList{count: 1}} =
             Settlements.list_refunds(organization_client(max_retries: 1), "stl_jDk30akdN")
  end

  test "returns decode errors for malformed JSON responses" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.send_resp(200, "{")
    end)

    assert {:error, %Error{} = error} =
             Settlements.next(organization_client([]))

    assert error.type == :decode
    assert error.status == 200
    assert error.operation == :settlements_next
  end

  test "returns decode errors for malformed JSON settlement subresource responses" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.send_resp(200, "{")
    end)

    assert {:error, %Error{} = error} =
             Settlements.list_chargebacks(organization_client([]), "stl_jDk30akdN")

    assert error.type == :decode
    assert error.status == 200
    assert error.operation == :settlements_list_chargebacks
  end

  test "returns decode errors for invalid settlement response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "settlement"})
    end)

    assert {:error, %Error{} = error} =
             Settlements.get(organization_client([]), "stl_jDk30akdN")

    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_settlement_response
    assert error.operation == :settlements_get
    assert error.raw == %{"resource" => "settlement"}
  end

  test "returns decode errors for invalid settlement list shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"settlements" => %{}},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{type: :decode, reason: :invalid_list_response}} =
             Settlements.list(oauth_client())
  end

  test "returns decode errors for invalid settlement list items" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"settlements" => [%{"resource" => "settlement"}]},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{type: :decode, reason: :invalid_settlement_response}} =
             Settlements.list(oauth_client())
  end

  test "returns decode errors for invalid settlement subresource list shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"refunds" => %{}},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{type: :decode, reason: :invalid_list_response}} =
             Settlements.list_refunds(oauth_client(), "stl_jDk30akdN")
  end

  test "returns decode errors for invalid settlement subresource list items" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"payments" => [%{"resource" => "payment"}]},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{type: :decode, reason: :invalid_payment_response}} =
             Settlements.list_payments(oauth_client(), "stl_jDk30akdN", profile_id: "pfl_123")
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

  def fetch_token, do: "dynamic_settlements_secret"

  defp organization_client(opts) do
    opts
    |> Keyword.put(:organization_token, @organization_token)
    |> then(&TestSupport.client(__MODULE__, &1))
  end
end
