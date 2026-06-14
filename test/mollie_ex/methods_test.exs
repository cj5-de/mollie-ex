defmodule MollieEx.MethodsTest do
  use ExUnit.Case, async: false

  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Method
  alias MollieEx.Methods
  alias MollieEx.TestSupport
  alias MollieEx.Types.{Link, Money}

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_methods_secret"

  test "lists enabled payment methods" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/methods"

      assert URI.decode_query(conn.query_string) == %{
               "amount[currency]" => "EUR",
               "amount[value]" => "10.00"
             }

      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert_empty_body(conn)

      fixture_response(conn, "methods/list_success.json", 200)
    end)

    assert {:ok, %MollieList{} = method_list} =
             Methods.list(client(), amount: %{currency: "EUR", value: "10.00"})

    assert method_list.count == 2

    assert [
             %Method{id: "ideal", description: "iDEAL"} = ideal,
             %Method{id: "creditcard", description: "Credit card"}
           ] = method_list.data

    assert ideal.minimum_amount == %Money{
             currency: "EUR",
             value: "0.01",
             raw: %{"currency" => "EUR", "value" => "0.01"}
           }

    assert [%{"id" => "ideal_INGBNL2A"}] = ideal.issuers
    assert ideal.raw["unexpectedFutureField"] == true
    assert %Link{href: "https://api.mollie.com/v2/methods"} = method_list.links["self"]
  end

  test "lists all payment methods" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/methods/all"
      assert URI.decode_query(conn.query_string) == %{"include" => "issuers"}
      assert_empty_body(conn)

      fixture_response(conn, "methods/list_success.json", 200)
    end)

    assert {:ok, %MollieList{data: [%Method{id: "ideal"} | _methods]}} =
             Methods.all(client(), include: "issuers")
  end

  test "gets a payment method with query filters" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/methods/ideal"

      assert URI.decode_query(conn.query_string) == %{
               "currency" => "EUR",
               "include" => "issuers",
               "locale" => "nl_NL",
               "sequenceType" => "first"
             }

      assert_empty_body(conn)

      fixture_response(conn, "methods/get_success.json", 200)
    end)

    assert {:ok, %Method{} = method} =
             Methods.get(client(), "ideal",
               currency: "EUR",
               include: "issuers",
               locale: "nl_NL",
               sequence_type: "first"
             )

    assert method.id == "ideal"

    assert method.maximum_amount == %Money{
             currency: "EUR",
             value: "50000.00",
             raw: %{"currency" => "EUR", "value" => "50000.00"}
           }

    assert %Link{href: "https://api.mollie.com/v2/methods/ideal"} = method.links["self"]
    assert method.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "adds profile and testmode for OAuth method requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert URI.decode_query(conn.query_string) == %{
               "profileId" => "pfl_123",
               "testmode" => "false"
             }

      fixture_response(conn, "methods/list_success.json", 200)
    end)

    client =
      TestSupport.client(__MODULE__,
        oauth_token: "access_test_secret",
        profile_id: "pfl_123",
        testmode: true
      )

    assert {:ok, %MollieList{}} = Methods.list(client, testmode: false)
  end

  test "rejects API-key scoped fields and invalid input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "ideal"})
    end)

    assert {:error, %Error{reason: :unsupported_profile_id}} =
             Methods.list(client(), profile_id: "pfl_123")

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Methods.all(client(), testmode: true)

    assert {:error, %Error{reason: :invalid_method_id}} = Methods.get(client(), "")

    assert {:error, %Error{reason: {:invalid_option, :amount}}} =
             Methods.list(client(), amount: %{currency: "EUR"})

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Methods.get(client(), "ideal", unknown: true)

    assert {:error, %Error{reason: :invalid_client}} = Methods.list(:not_a_client)

    refute_receive :request_sent, 10
  end

  test "requires profile_id for bearer-token method requests" do
    assert {:error, %Error{reason: :missing_profile_id}} =
             Methods.get(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               "ideal"
             )
  end

  defp client do
    TestSupport.client(__MODULE__, api_key: @api_key)
  end
end
