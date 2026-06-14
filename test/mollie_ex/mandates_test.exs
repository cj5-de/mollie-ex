defmodule MollieEx.MandatesTest do
  use ExUnit.Case, async: false

  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Mandate
  alias MollieEx.Mandates
  alias MollieEx.TestSupport
  alias MollieEx.Types.Link

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_mandates_secret"

  test "creates a mandate with camelCased body and caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/customers/cst_123/mandates"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert header(conn, "idempotency-key") == "mandate-123"

      assert_json_body(conn, %{
        "consumerAccount" => "NL55INGB0000000000",
        "consumerName" => "Example Customer",
        "mandateReference" => "EXAMPLE-CORP-MD13804",
        "method" => "directdebit",
        "signatureDate" => "2026-06-14"
      })

      fixture_response(conn, "mandates/get_success.json", 201)
    end)

    assert {:ok, %Mandate{} = mandate} =
             Mandates.create(client(), "cst_123", mandate_params(),
               idempotency_key: "mandate-123"
             )

    assert mandate.id == "mdt_123"
    assert mandate.customer_id == "cst_123"
    assert mandate.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "adds testmode for OAuth create requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "consumerAccount" => "NL55INGB0000000000",
        "consumerName" => "Example Customer",
        "mandateReference" => "EXAMPLE-CORP-MD13804",
        "method" => "directdebit",
        "signatureDate" => "2026-06-14",
        "testmode" => false
      })

      fixture_response(conn, "mandates/get_success.json", 201)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %Mandate{id: "mdt_123"}} =
             Mandates.create(client, "cst_123", mandate_params(), testmode: false)
  end

  test "gets a mandate with OAuth testmode query param" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/customers/cst_123/mandates/mdt_123"
      assert URI.decode_query(conn.query_string) == %{"testmode" => "true"}
      assert_empty_body(conn)

      fixture_response(conn, "mandates/get_success.json", 200)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %Mandate{id: "mdt_123"}} = Mandates.get(client, "cst_123", "mdt_123")
  end

  test "lists mandates with pagination and scopes" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/customers/cst_123/mandates"
      query = URI.query_decoder(conn.query_string) |> Enum.to_list()

      assert {"from", "mdt_001"} in query
      assert {"limit", "5"} in query
      assert {"scopes", "customer-not-present"} in query
      assert {"scopes", "customer-present"} in query
      assert {"sort", "asc"} in query
      refute Enum.any?(query, fn {key, _value} -> key == "scopes[]" end)

      assert_empty_body(conn)

      fixture_response(conn, "mandates/list_success.json", 200)
    end)

    assert {:ok, %MollieList{} = mandate_list} =
             Mandates.list(client(), "cst_123",
               from: "mdt_001",
               limit: 5,
               scopes: ["customer-not-present", "customer-present"],
               sort: :asc
             )

    assert mandate_list.count == 1
    assert [%Mandate{id: "mdt_list_123", customer_id: "cst_123"}] = mandate_list.data

    assert %Link{href: "https://api.mollie.com/v2/customers/cst_123/mandates"} =
             mandate_list.links["self"]
  end

  test "revokes a mandate with caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v2/customers/cst_123/mandates/mdt_123"
      assert conn.query_string == ""
      assert header(conn, "idempotency-key") == "mandate-revoke-123"
      assert_empty_body(conn)

      no_content_response(conn)
    end)

    assert {:ok, :no_content} =
             Mandates.revoke(client(), "cst_123", "mdt_123",
               idempotency_key: "mandate-revoke-123"
             )
  end

  test "sends testmode in the body for OAuth revoke requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{"testmode" => false})
      no_content_response(conn)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, :no_content} = Mandates.revoke(client, "cst_123", "mdt_123", testmode: false)
  end

  test "rejects invalid mandate options and input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "mdt_123"})
    end)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Mandates.create(client(), "cst_123", mandate_params(), testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Mandates.get(client(), "cst_123", "mdt_123", testmode: true)

    assert {:error, %Error{reason: {:invalid_option, :scopes}}} =
             Mandates.list(client(), "cst_123", scopes: [])

    assert {:error, %Error{reason: :invalid_customer_id}} =
             Mandates.list(client(), "", [])

    assert {:error, %Error{reason: :invalid_mandate_id}} =
             Mandates.revoke(client(), "cst_123", "")

    assert {:error, %Error{reason: :invalid_client}} =
             Mandates.get(:not_a_client, "cst_123", "mdt_123")

    refute_receive :request_sent, 10
  end

  defp client do
    TestSupport.client(__MODULE__, api_key: @api_key)
  end

  defp mandate_params do
    %{
      method: "directdebit",
      consumer_name: "Example Customer",
      consumer_account: "NL55INGB0000000000",
      signature_date: "2026-06-14",
      mandate_reference: "EXAMPLE-CORP-MD13804"
    }
  end
end
