defmodule MollieEx.ChargebacksTest do
  use ExUnit.Case, async: false

  alias MollieEx.Chargeback
  alias MollieEx.Chargebacks
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.TestSupport
  alias MollieEx.Types.{Link, Money}

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_chargebacks_secret"
  @chargeback_fixture Path.expand("../fixtures/mollie/chargebacks/get_success.json", __DIR__)
  @chargeback_list_fixture Path.expand(
                             "../fixtures/mollie/chargebacks/list_success.json",
                             __DIR__
                           )

  test "retrieves a chargeback" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/payments/tr_123/chargebacks/chb_123"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert_empty_body(conn)

      chargeback_fixture_response(conn, 200)
    end)

    assert {:ok, %Chargeback{} = chargeback} =
             Chargebacks.get(client(), "tr_123", "chb_123")

    assert chargeback.id == "chb_123"
    assert chargeback.payment_id == "tr_123"

    assert chargeback.reason == %{
             "code" => "AC01",
             "description" => "Account identifier incorrect"
           }

    assert chargeback.amount == %Money{
             currency: "EUR",
             value: "10.00",
             raw: %{"currency" => "EUR", "value" => "10.00"}
           }

    assert chargeback.settlement_amount == %Money{
             currency: "EUR",
             value: "-10.00",
             raw: %{"currency" => "EUR", "value" => "-10.00"}
           }

    assert %Link{href: "https://api.mollie.com/v2/payments/tr_123"} =
             chargeback.links["payment"]

    assert chargeback.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "retrieves a chargeback with embed and OAuth testmode query params" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/payments/tr_123/chargebacks/chb_123"
      assert URI.decode_query(conn.query_string) == %{"embed" => "payment", "testmode" => "false"}
      assert_empty_body(conn)

      chargeback_fixture_response(conn, 200)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %Chargeback{id: "chb_123"}} =
             Chargebacks.get(client, "tr_123", "chb_123", embed: "payment", testmode: false)
  end

  test "lists chargebacks with pagination and embed options" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/payments/tr_123/chargebacks"

      assert URI.decode_query(conn.query_string) == %{
               "embed" => "payment",
               "from" => "chb_from",
               "limit" => "1"
             }

      assert_empty_body(conn)

      chargeback_list_fixture_response(conn, 200)
    end)

    assert {:ok, %MollieList{} = chargeback_list} =
             Chargebacks.list(client(), "tr_123", from: "chb_from", limit: 1, embed: "payment")

    assert chargeback_list.count == 1
    assert [%Chargeback{id: "chb_list_123", payment_id: "tr_123"}] = chargeback_list.data

    assert %Link{
             href: "https://api.mollie.com/v2/payments/tr_123/chargebacks?from=chb_next&limit=1"
           } = chargeback_list.links["next"]
  end

  test "adds testmode query param for OAuth list requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert URI.decode_query(conn.query_string) == %{"testmode" => "false"}
      chargeback_list_fixture_response(conn, 200)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %MollieList{}} = Chargebacks.list(client, "tr_123", testmode: false)
  end

  test "rejects testmode for API-key chargeback requests before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "chb_123"})
    end)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Chargebacks.get(client(), "tr_123", "chb_123", testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             Chargebacks.list(client(), "tr_123", testmode: true)

    refute_receive :request_sent, 10
  end

  test "retries safe chargeback get requests without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil
      chargeback_fixture_response(conn, 200)
    end)

    assert {:ok, %Chargeback{id: "chb_123"}} =
             Chargebacks.get(client(max_retries: 1), "tr_123", "chb_123")
  end

  test "returns API errors for chargeback calls" do
    cases = [
      {:get, 404, :not_found},
      {:list, 401, :authentication}
    ]

    for {operation, status, type} <- cases do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(status)
        |> Req.Test.json(%{
          "status" => status,
          "title" => "Chargeback error",
          "_links" => %{"documentation" => %{"href" => "https://docs.mollie.com/"}}
        })
      end)

      assert {:error, %Error{} = error} = call_operation(operation, client(max_retries: 0))
      assert error.type == type
      assert error.status == status
      assert error.raw["title"] == "Chargeback error"
    end
  end

  test "returns timeout errors for chargeback calls" do
    for {operation, expected_operation} <- [
          {:get, :chargebacks_get},
          {:list, :chargebacks_list}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, %Error{} = error} = call_operation(operation, client(max_retries: 0))
      assert error.type == :timeout
      assert error.operation == expected_operation
    end
  end

  test "returns decode errors for malformed JSON responses" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.send_resp(200, "{")
    end)

    assert {:error, %Error{} = error} = Chargebacks.get(client(), "tr_123", "chb_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.operation == :chargebacks_get
  end

  test "returns decode errors for invalid chargeback response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "chargeback"})
    end)

    assert {:error, %Error{} = error} = Chargebacks.get(client(), "tr_123", "chb_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_chargeback_response
    assert error.operation == :chargebacks_get
    assert error.raw == %{"resource" => "chargeback"}
  end

  test "returns decode errors for invalid chargeback list response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"count" => 1, "_embedded" => %{"chargebacks" => %{}}, "_links" => %{}})
    end)

    assert {:error, %Error{} = error} = Chargebacks.list(client(), "tr_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_list_response
    assert error.operation == :chargebacks_list
  end

  test "returns decode errors for invalid embedded chargeback list items" do
    invalid_chargeback = %{"resource" => "chargeback"}

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"chargebacks" => [invalid_chargeback]},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{} = error} = Chargebacks.list(client(), "tr_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_chargeback_response
    assert error.operation == :chargebacks_list
    assert error.raw == invalid_chargeback
  end

  test "rejects invalid local inputs before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "chb_123"})
    end)

    assert {:error, %Error{reason: :invalid_client}} =
             Chargebacks.get("bad", "tr_123", "chb_123")

    assert {:error, %Error{reason: :invalid_payment_id}} =
             Chargebacks.get(client(), "", "chb_123")

    assert {:error, %Error{reason: :invalid_chargeback_id}} =
             Chargebacks.get(client(), "tr_123", "")

    assert {:error, %Error{reason: :invalid_payment_id}} =
             Chargebacks.list(client(), "")

    assert {:error, %Error{reason: :invalid_options}} =
             Chargebacks.get(client(), "tr_123", "chb_123", "bad")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Chargebacks.get(client(), "tr_123", "chb_123", unknown: true)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Chargebacks.list(client(), "tr_123", unknown: true)

    assert {:error, %Error{reason: {:invalid_option, :embed}}} =
             Chargebacks.get(client(), "tr_123", "chb_123", embed: 123)

    assert {:error, %Error{reason: {:invalid_option, :from}}} =
             Chargebacks.list(client(), "tr_123", from: "")

    assert {:error, %Error{reason: {:invalid_option, :limit}}} =
             Chargebacks.list(client(), "tr_123", limit: 251)

    assert {:error, %Error{reason: :invalid_testmode}} =
             Chargebacks.get(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               "tr_123",
               "chb_123",
               testmode: "true"
             )

    assert {:error, %Error{reason: :invalid_testmode}} =
             Chargebacks.list(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               "tr_123",
               testmode: "true"
             )

    refute_receive :request_sent, 10
  end

  test "emits safe request telemetry for successful chargeback calls" do
    prefix = [:mollie_chargebacks_test_success]
    attach_telemetry(prefix, [[:request, :start], [:request, :stop]])

    Req.Test.expect(__MODULE__, fn conn ->
      chargeback_fixture_response(conn, 200)
    end)

    assert {:ok, %Chargeback{}} =
             Chargebacks.get(client(telemetry_prefix: prefix), "tr_123", "chb_123")

    assert_success_telemetry(
      prefix,
      :chargebacks_get,
      "GET",
      "/payments/{paymentId}/chargebacks/{chargebackId}",
      200,
      [@api_key, "chb_123", "authorization"]
    )

    Req.Test.expect(__MODULE__, fn conn ->
      chargeback_list_fixture_response(conn, 200)
    end)

    assert {:ok, %MollieList{}} =
             Chargebacks.list(client(telemetry_prefix: prefix), "tr_123")

    assert_success_telemetry(
      prefix,
      :chargebacks_list,
      "GET",
      "/payments/{paymentId}/chargebacks",
      200,
      [@api_key, "chb_123", "authorization"]
    )
  end

  test "emits safe decode exception and rate limit telemetry" do
    prefix = [:mollie_chargebacks_test_errors]

    attach_telemetry(prefix, [
      [:request, :start],
      [:request, :stop],
      [:request, :exception],
      [:decode, :exception],
      [:rate_limit]
    ])

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "chargeback"})
    end)

    assert {:error, %Error{type: :decode}} =
             Chargebacks.get(client(telemetry_prefix: prefix), "tr_123", "chb_123")

    decode_event = prefix ++ [:decode, :exception]
    request_exception_event = prefix ++ [:request, :exception]

    assert_receive {:telemetry, ^decode_event, %{duration: _duration}, decode_metadata}
    assert decode_metadata.error_type == :decode
    assert decode_metadata.reason == :invalid_chargeback_response
    assert decode_metadata.path_template == "/payments/{paymentId}/chargebacks/{chargebackId}"

    assert_receive {:telemetry, ^request_exception_event, %{duration: _duration},
                    exception_metadata}

    assert exception_metadata.error_type == :decode

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(429)
      |> Req.Test.json(%{"status" => 429, "title" => "Too Many Requests"})
    end)

    assert {:error, %Error{type: :rate_limited}} =
             Chargebacks.get(
               client(telemetry_prefix: prefix, max_retries: 0),
               "tr_123",
               "chb_123"
             )

    rate_limit_event = prefix ++ [:rate_limit]
    stop_event = prefix ++ [:request, :stop]

    assert_receive {:telemetry, ^stop_event, %{duration: _duration}, stop_metadata}
    assert stop_metadata.status == 429
    assert stop_metadata.error_type == :rate_limited

    assert_receive {:telemetry, ^rate_limit_event, %{duration: _duration}, rate_limit_metadata}
    assert rate_limit_metadata.status == 429
    assert rate_limit_metadata.error_type == :rate_limited

    telemetry_text =
      inspect([decode_metadata, exception_metadata, stop_metadata, rate_limit_metadata])

    refute telemetry_text =~ @api_key
    refute telemetry_text =~ "Too Many Requests"
    refute telemetry_text =~ "authorization"
  end

  defp call_operation(:get, client), do: Chargebacks.get(client, "tr_123", "chb_123")
  defp call_operation(:list, client), do: Chargebacks.list(client, "tr_123")

  defp client(opts \\ []) do
    [api_key: @api_key]
    |> Keyword.merge(opts)
    |> then(&TestSupport.client(__MODULE__, &1))
  end

  defp chargeback_fixture_response(conn, status),
    do: fixture_response(conn, @chargeback_fixture, status)

  defp chargeback_list_fixture_response(conn, status) do
    fixture_response(conn, @chargeback_list_fixture, status)
  end
end
