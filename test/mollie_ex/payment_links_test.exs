defmodule MollieEx.PaymentLinksTest do
  use ExUnit.Case, async: false

  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.PaymentLink
  alias MollieEx.PaymentLinks
  alias MollieEx.TestSupport
  alias MollieEx.Types.{Link, Money}

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_payment_links_secret"
  @payment_link_fixture Path.expand("../fixtures/mollie/payment_links/get_success.json", __DIR__)
  @payment_link_list_fixture Path.expand(
                               "../fixtures/mollie/payment_links/list_success.json",
                               __DIR__
                             )

  test "creates a payment link with camelCased body and caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/payment-links"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert header(conn, "idempotency-key") == "payment-link-123"

      assert_json_body(conn, %{
        "description" => "Order #123",
        "amount" => %{"currency" => "EUR", "value" => "10.00"},
        "minimumAmount" => %{"currency" => "EUR", "value" => "5.00"},
        "redirectUrl" => "https://example.com/checkout/return",
        "allowedMethods" => ["ideal", "creditcard"],
        "applicationFee" => %{
          "amount" => %{"currency" => "EUR", "value" => "1.00"},
          "description" => "Platform fee"
        }
      })

      payment_link_fixture_response(conn, 201)
    end)

    assert {:ok, %PaymentLink{} = payment_link} =
             PaymentLinks.create(client(), create_params(), idempotency_key: "payment-link-123")

    assert payment_link.id == "pl_123"
    assert payment_link.description == "Order #123"
    refute PaymentLink.paid?(payment_link)

    assert PaymentLink.checkout_url(payment_link) ==
             "https://payment-links.mollie.com/payment/pl_123"

    assert payment_link.amount == %Money{
             currency: "EUR",
             value: "10.00",
             raw: %{"currency" => "EUR", "value" => "10.00"}
           }

    assert %Link{href: "https://api.mollie.com/v2/payment-links/pl_123"} =
             payment_link.links["self"]

    assert payment_link.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "adds profile_id and testmode for OAuth create requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "description" => "Order #123",
        "amount" => %{"currency" => "EUR", "value" => "10.00"},
        "profileId" => "pfl_override",
        "testmode" => false
      })

      payment_link_fixture_response(conn, 201)
    end)

    client =
      TestSupport.client(__MODULE__,
        oauth_token: "access_test_secret",
        profile_id: "pfl_client",
        testmode: true
      )

    assert {:ok, %PaymentLink{id: "pl_123"}} =
             PaymentLinks.create(
               client,
               %{description: "Order #123", amount: %{currency: "EUR", value: "10.00"}},
               profile_id: "pfl_override",
               testmode: false
             )
  end

  test "honors params-level profile_id and testmode for OAuth create requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{
        "description" => "Order #123",
        "amount" => %{"currency" => "EUR", "value" => "10.00"},
        "profileId" => "pfl_params",
        "testmode" => false
      })

      payment_link_fixture_response(conn, 201)
    end)

    client =
      TestSupport.client(__MODULE__,
        oauth_token: "access_test_secret",
        profile_id: "pfl_client",
        testmode: true
      )

    params =
      create_params()
      |> Map.take([:description, :amount])
      |> Map.put(:profile_id, "pfl_params")
      |> Map.put(:testmode, false)

    assert {:ok, %PaymentLink{id: "pl_123"}} = PaymentLinks.create(client, params)
  end

  test "retrieves a payment link with OAuth testmode query param" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/payment-links/pl_123"
      assert URI.decode_query(conn.query_string) == %{"testmode" => "false"}
      assert_empty_body(conn)

      payment_link_fixture_response(conn, 200)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %PaymentLink{id: "pl_123"}} =
             PaymentLinks.get(client, "pl_123", testmode: false)
  end

  test "lists payment links with pagination and OAuth testmode query params" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/payment-links"

      assert URI.decode_query(conn.query_string) == %{
               "from" => "pl_from",
               "limit" => "1",
               "testmode" => "false"
             }

      assert_empty_body(conn)

      payment_link_list_fixture_response(conn, 200)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: "access_test_secret", testmode: true)

    assert {:ok, %MollieList{} = payment_link_list} =
             PaymentLinks.list(client, from: "pl_from", limit: 1, testmode: false)

    assert payment_link_list.count == 1
    assert [%PaymentLink{id: "pl_list_123", description: "Order #123"}] = payment_link_list.data

    assert %Link{href: "https://api.mollie.com/v2/payment-links?from=pl_next&limit=1"} =
             payment_link_list.links["next"]
  end

  test "rejects scoped fields for API-key payment link requests before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "pl_123"})
    end)

    assert {:error, %Error{reason: :unsupported_profile_id}} =
             PaymentLinks.create(client(), create_params(), profile_id: "pfl_123")

    assert {:error, %Error{reason: :unsupported_profile_id}} =
             PaymentLinks.create(client(), Map.put(create_params(), :profile_id, "pfl_123"))

    assert {:error, %Error{reason: :unsupported_testmode}} =
             PaymentLinks.create(client(), create_params(), testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             PaymentLinks.create(client(), Map.put(create_params(), :testmode, true))

    assert {:error, %Error{reason: :unsupported_testmode}} =
             PaymentLinks.get(client(), "pl_123", testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             PaymentLinks.list(client(), testmode: true)

    refute_receive :request_sent, 10
  end

  test "does not retry payment link create without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    assert {:error, %Error{type: :server_error, status: 503}} =
             PaymentLinks.create(client(max_retries: 1), create_params())
  end

  test "retries payment link create with the same caller idempotency key and body" do
    expected_body = %{
      "description" => "Order #123",
      "amount" => %{"currency" => "EUR", "value" => "10.00"},
      "minimumAmount" => %{"currency" => "EUR", "value" => "5.00"},
      "redirectUrl" => "https://example.com/checkout/return",
      "allowedMethods" => ["ideal", "creditcard"],
      "applicationFee" => %{
        "amount" => %{"currency" => "EUR", "value" => "1.00"},
        "description" => "Platform fee"
      }
    }

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "payment-link-123"
      assert_json_body(conn, expected_body)

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "payment-link-123"
      assert_json_body(conn, expected_body)
      payment_link_fixture_response(conn, 201)
    end)

    assert {:ok, %PaymentLink{id: "pl_123"}} =
             PaymentLinks.create(
               client(max_retries: 1),
               create_params(),
               idempotency_key: "payment-link-123"
             )
  end

  test "retries safe payment link get and list requests without idempotency key" do
    for operation <- [:get, :list] do
      Req.Test.expect(__MODULE__, fn conn ->
        assert header(conn, "idempotency-key") == nil

        conn
        |> Plug.Conn.put_status(503)
        |> Req.Test.json(%{"status" => 503})
      end)

      Req.Test.expect(__MODULE__, fn conn ->
        assert header(conn, "idempotency-key") == nil
        payment_link_response(operation, conn)
      end)

      assert {:ok, _result} = call_operation(operation, client(max_retries: 1))
    end
  end

  test "returns API errors for payment link calls" do
    cases = [
      {:create, 422, :validation},
      {:get, 404, :not_found},
      {:list, 429, :rate_limited}
    ]

    for {operation, status, type} <- cases do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(status)
        |> Req.Test.json(%{
          "status" => status,
          "title" => "Payment link error",
          "_links" => %{"documentation" => %{"href" => "https://docs.mollie.com/"}}
        })
      end)

      assert {:error, %Error{} = error} = call_operation(operation, client(max_retries: 0))
      assert error.type == type
      assert error.status == status
      assert error.raw["title"] == "Payment link error"
    end
  end

  test "returns timeout errors for payment link calls" do
    for {operation, expected_operation} <- [
          {:create, :payment_links_create},
          {:get, :payment_links_get},
          {:list, :payment_links_list}
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

    assert {:error, %Error{} = error} = PaymentLinks.get(client(), "pl_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.operation == :payment_links_get
  end

  test "returns decode errors for invalid payment link response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "payment-link"})
    end)

    assert {:error, %Error{} = error} = PaymentLinks.get(client(), "pl_123")
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_payment_link_response
    assert error.operation == :payment_links_get
    assert error.raw == %{"resource" => "payment-link"}
  end

  test "returns decode errors for invalid payment link list response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"payment_links" => %{}},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{} = error} = PaymentLinks.list(client())
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_list_response
    assert error.operation == :payment_links_list
  end

  test "returns decode errors for invalid embedded payment link list items" do
    invalid_payment_link = %{"resource" => "payment-link"}

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"payment_links" => [invalid_payment_link]},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{} = error} = PaymentLinks.list(client())
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_payment_link_response
    assert error.operation == :payment_links_list
    assert error.raw == invalid_payment_link
  end

  test "rejects invalid local inputs before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "pl_123"})
    end)

    assert {:error, %Error{reason: :invalid_client}} =
             PaymentLinks.create("bad", create_params())

    assert {:error, %Error{reason: :invalid_payment_link_params}} =
             PaymentLinks.create(client(), "bad")

    assert {:error, %Error{reason: :missing_description}} =
             PaymentLinks.create(client(), %{amount: %{currency: "EUR", value: "10.00"}})

    assert {:error, %Error{reason: :invalid_payment_link_id}} =
             PaymentLinks.get(client(), "")

    assert {:error, %Error{reason: :invalid_options}} =
             PaymentLinks.get(client(), "pl_123", "bad")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             PaymentLinks.list(client(), unknown: true)

    assert {:error, %Error{reason: {:invalid_option, :from}}} =
             PaymentLinks.list(client(), from: "")

    assert {:error, %Error{reason: {:invalid_option, :limit}}} =
             PaymentLinks.list(client(), limit: 251)

    assert {:error, %Error{reason: :missing_profile_id}} =
             PaymentLinks.create(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               create_params()
             )

    assert {:error, %Error{reason: :invalid_profile_id}} =
             PaymentLinks.create(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               create_params(),
               profile_id: ""
             )

    assert {:error, %Error{reason: :invalid_testmode}} =
             PaymentLinks.get(
               TestSupport.client(__MODULE__, oauth_token: "access_test_secret"),
               "pl_123",
               testmode: "true"
             )

    refute_receive :request_sent, 10
  end

  test "emits safe request telemetry for successful payment link calls" do
    prefix = [:mollie_payment_links_test_success]
    attach_telemetry(prefix, [[:request, :start], [:request, :stop]])

    Req.Test.expect(__MODULE__, fn conn ->
      payment_link_fixture_response(conn, 201)
    end)

    assert {:ok, %PaymentLink{}} =
             PaymentLinks.create(
               client(telemetry_prefix: prefix),
               create_params(),
               idempotency_key: "payment-link-123"
             )

    assert_success_telemetry(
      prefix,
      :payment_links_create,
      "POST",
      "/payment-links",
      201,
      [@api_key, "pl_123", "authorization"]
    )

    Req.Test.expect(__MODULE__, fn conn ->
      payment_link_fixture_response(conn, 200)
    end)

    assert {:ok, %PaymentLink{}} = PaymentLinks.get(client(telemetry_prefix: prefix), "pl_123")

    assert_success_telemetry(
      prefix,
      :payment_links_get,
      "GET",
      "/payment-links/{paymentLinkId}",
      200,
      [@api_key, "pl_123", "authorization"]
    )

    Req.Test.expect(__MODULE__, fn conn ->
      payment_link_list_fixture_response(conn, 200)
    end)

    assert {:ok, %MollieList{}} = PaymentLinks.list(client(telemetry_prefix: prefix))

    assert_success_telemetry(
      prefix,
      :payment_links_list,
      "GET",
      "/payment-links",
      200,
      [@api_key, "pl_123", "authorization"]
    )
  end

  test "emits safe decode exception and rate limit telemetry" do
    prefix = [:mollie_payment_links_test_errors]

    attach_telemetry(prefix, [
      [:request, :start],
      [:request, :stop],
      [:request, :exception],
      [:decode, :exception],
      [:rate_limit]
    ])

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "payment-link"})
    end)

    assert {:error, %Error{type: :decode}} =
             PaymentLinks.get(client(telemetry_prefix: prefix), "pl_123")

    decode_event = prefix ++ [:decode, :exception]
    request_exception_event = prefix ++ [:request, :exception]

    assert_receive {:telemetry, ^decode_event, %{duration: _duration}, decode_metadata}
    assert decode_metadata.error_type == :decode
    assert decode_metadata.reason == :invalid_payment_link_response
    assert decode_metadata.path_template == "/payment-links/{paymentLinkId}"

    assert_receive {:telemetry, ^request_exception_event, %{duration: _duration},
                    exception_metadata}

    assert exception_metadata.error_type == :decode

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(429)
      |> Req.Test.json(%{"status" => 429, "title" => "Too Many Requests"})
    end)

    assert {:error, %Error{type: :rate_limited}} =
             PaymentLinks.get(client(telemetry_prefix: prefix, max_retries: 0), "pl_123")

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

  defp call_operation(:create, client), do: PaymentLinks.create(client, create_params())
  defp call_operation(:get, client), do: PaymentLinks.get(client, "pl_123")
  defp call_operation(:list, client), do: PaymentLinks.list(client)

  defp client(opts \\ []) do
    [api_key: @api_key]
    |> Keyword.merge(opts)
    |> then(&TestSupport.client(__MODULE__, &1))
  end

  defp create_params do
    %{
      description: "Order #123",
      amount: %{currency: "EUR", value: "10.00"},
      minimum_amount: %{currency: "EUR", value: "5.00"},
      redirect_url: "https://example.com/checkout/return",
      allowed_methods: ["ideal", "creditcard"],
      application_fee: %{
        amount: %{currency: "EUR", value: "1.00"},
        description: "Platform fee"
      }
    }
  end

  defp payment_link_response(:list, conn), do: payment_link_list_fixture_response(conn, 200)
  defp payment_link_response(_operation, conn), do: payment_link_fixture_response(conn, 200)

  defp payment_link_fixture_response(conn, status),
    do: fixture_response(conn, @payment_link_fixture, status)

  defp payment_link_list_fixture_response(conn, status) do
    fixture_response(conn, @payment_link_list_fixture, status)
  end
end
