defmodule MollieEx.SalesInvoicesTest do
  use ExUnit.Case, async: false

  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.SalesInvoice
  alias MollieEx.SalesInvoices
  alias MollieEx.TestSupport
  alias MollieEx.Types.Link

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_sales_invoices_secret"
  @oauth_token "access_sales_invoices_secret"
  @organization_token "org_sales_invoices_secret"

  test "creates a sales invoice with camelCased body and caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/sales-invoices"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert header(conn, "idempotency-key") == "sales-invoice-123"
      assert_json_body(conn, expected_create_body())

      fixture_response(conn, "sales_invoices/get_success.json", 201)
    end)

    assert {:ok, %SalesInvoice{} = sales_invoice} =
             SalesInvoices.create(api_key_client(), create_params(),
               idempotency_key: "sales-invoice-123"
             )

    assert sales_invoice.id == "invoice_4Y0eZitmBnQ6IDoMqZQKh"
    assert sales_invoice.status == "draft"
    assert SalesInvoice.draft?(sales_invoice)
  end

  test "adds profile_id and testmode for OAuth create requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(
        conn,
        Map.merge(expected_minimal_create_body(), %{
          "profileId" => "pfl_override",
          "testmode" => false
        })
      )

      fixture_response(conn, "sales_invoices/get_success.json", 201)
    end)

    client =
      TestSupport.client(__MODULE__,
        oauth_token: @oauth_token,
        profile_id: "pfl_client",
        testmode: true
      )

    assert {:ok, %SalesInvoice{id: "invoice_4Y0eZitmBnQ6IDoMqZQKh"}} =
             SalesInvoices.create(client, minimal_create_params(),
               profile_id: "pfl_override",
               testmode: false
             )
  end

  test "lists sales invoices with pagination and OAuth testmode query params" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/sales-invoices"

      assert URI.decode_query(conn.query_string) == %{
               "from" => "invoice_start",
               "limit" => "2",
               "testmode" => "true"
             }

      assert header(conn, "authorization") == "Bearer #{@oauth_token}"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "sales_invoices/list_success.json", 200)
    end)

    assert {:ok, %MollieList{} = invoice_list} =
             SalesInvoices.list(oauth_client(), from: "invoice_start", limit: 2, testmode: true)

    assert invoice_list.count == 2

    assert [
             %SalesInvoice{id: "invoice_4Y0eZitmBnQ6IDoMqZQKh"} = draft_invoice,
             %SalesInvoice{id: "invoice_lTzWJ4BfKu2MNm7Avx9Te"} = paid_invoice
           ] = invoice_list.data

    assert draft_invoice.resource == "sales-invoice"
    assert draft_invoice.amount_due.value == "107.69"

    assert draft_invoice.lines |> hd() |> Map.get("description") ==
             "LEGO 4440 Forest Police Station"

    assert draft_invoice.raw["unexpectedFutureField"] == true
    assert SalesInvoice.draft?(draft_invoice)
    assert SalesInvoice.paid?(paid_invoice)

    assert %Link{
             href: "https://api.mollie.com/v2/sales-invoices/invoice_4Y0eZitmBnQ6IDoMqZQKh"
           } = draft_invoice.links["self"]

    assert %Link{href: "https://api.mollie.com/v2/sales-invoices?from=invoice_start&limit=2"} =
             invoice_list.links["self"]
  end

  test "gets a sales invoice with path encoding and client-level testmode" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/sales-invoices/invoice_2024%2F10000"
      assert URI.decode_query(conn.query_string) == %{"testmode" => "true"}
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "sales_invoices/get_success.json", 200)
    end)

    assert {:ok, %SalesInvoice{} = sales_invoice} =
             SalesInvoices.get(organization_client(testmode: true), "invoice_2024/10000")

    assert sales_invoice.id == "invoice_4Y0eZitmBnQ6IDoMqZQKh"
    assert sales_invoice.profile_id == "pfl_QkEhN94Ba"
    assert sales_invoice.total_amount.value == "107.69"
    assert sales_invoice.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "updates a sales invoice with camelCased body and caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v2/sales-invoices/invoice_4Y0eZitmBnQ6IDoMqZQKh"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert header(conn, "idempotency-key") == "sales-invoice-update-123"
      assert_json_body(conn, expected_update_body())

      fixture_response(conn, "sales_invoices/get_success.json", 200)
    end)

    assert {:ok, %SalesInvoice{id: "invoice_4Y0eZitmBnQ6IDoMqZQKh"}} =
             SalesInvoices.update(
               api_key_client(),
               "invoice_4Y0eZitmBnQ6IDoMqZQKh",
               update_params(),
               idempotency_key: "sales-invoice-update-123"
             )
  end

  test "adds testmode for OAuth update requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert_json_body(conn, %{"memo" => "Updated memo", "testmode" => false})
      fixture_response(conn, "sales_invoices/get_success.json", 200)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: @oauth_token, testmode: true)

    assert {:ok, %SalesInvoice{id: "invoice_4Y0eZitmBnQ6IDoMqZQKh"}} =
             SalesInvoices.update(
               client,
               "invoice_4Y0eZitmBnQ6IDoMqZQKh",
               %{memo: "Updated memo"},
               testmode: false
             )
  end

  test "deletes a sales invoice and returns no content" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v2/sales-invoices/invoice_4Y0eZitmBnQ6IDoMqZQKh"
      assert conn.query_string == ""
      assert header(conn, "idempotency-key") == "sales-invoice-delete-123"
      assert_empty_body(conn)

      no_content_response(conn)
    end)

    assert {:ok, :no_content} =
             SalesInvoices.delete(api_key_client(), "invoice_4Y0eZitmBnQ6IDoMqZQKh",
               idempotency_key: "sales-invoice-delete-123"
             )
  end

  test "sends testmode in the body for OAuth delete requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v2/sales-invoices/invoice_4Y0eZitmBnQ6IDoMqZQKh"
      assert conn.query_string == ""
      assert_json_body(conn, %{"testmode" => false})

      no_content_response(conn)
    end)

    client = TestSupport.client(__MODULE__, oauth_token: @oauth_token, testmode: true)

    assert {:ok, :no_content} =
             SalesInvoices.delete(client, "invoice_4Y0eZitmBnQ6IDoMqZQKh", testmode: false)
  end

  test "rejects invalid input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"resource" => "sales-invoice", "id" => "invoice_123"})
    end)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             SalesInvoices.create(api_key_client(), create_params(), testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             SalesInvoices.create(api_key_client(), Map.put(create_params(), :testmode, true))

    assert {:error, %Error{reason: :unsupported_profile_id}} =
             SalesInvoices.create(api_key_client(), create_params(), profile_id: "pfl_123")

    assert {:error, %Error{reason: :unsupported_profile_id}} =
             SalesInvoices.create(
               api_key_client(),
               Map.put(create_params(), :profile_id, "pfl_123")
             )

    assert {:error, %Error{reason: :unsupported_testmode}} =
             SalesInvoices.list(api_key_client(), testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             SalesInvoices.get(api_key_client(), "invoice_123", testmode: true)

    assert {:error, %Error{reason: :unsupported_testmode}} =
             SalesInvoices.update(api_key_client(), "invoice_123", update_params(),
               testmode: true
             )

    assert {:error, %Error{reason: :unsupported_testmode}} =
             SalesInvoices.update(
               api_key_client(),
               "invoice_123",
               Map.put(update_params(), :testmode, true)
             )

    assert {:error, %Error{reason: :unsupported_profile_id}} =
             SalesInvoices.update(
               api_key_client(),
               "invoice_123",
               Map.put(update_params(), :profile_id, "pfl_123")
             )

    assert {:error, %Error{reason: :unsupported_testmode}} =
             SalesInvoices.delete(api_key_client(), "invoice_123", testmode: true)

    assert {:error, %Error{reason: :missing_profile_id}} =
             SalesInvoices.create(
               TestSupport.client(__MODULE__, oauth_token: @oauth_token),
               create_params()
             )

    assert {:error, %Error{reason: :invalid_sales_invoice_id}} =
             SalesInvoices.get(oauth_client(), "")

    assert {:error, %Error{reason: :invalid_sales_invoice_id}} =
             SalesInvoices.update(oauth_client(), "", update_params())

    assert {:error, %Error{reason: :invalid_sales_invoice_id}} =
             SalesInvoices.delete(oauth_client(), "")

    assert {:error, %Error{reason: :invalid_sales_invoice_params}} =
             SalesInvoices.create(oauth_client(), :not_params)

    assert {:error, %Error{reason: :missing_status}} =
             SalesInvoices.create(oauth_client(), Map.delete(create_params(), :status))

    assert {:error, %Error{reason: :missing_recipient_identifier}} =
             SalesInvoices.create(
               oauth_client(),
               Map.delete(create_params(), :recipient_identifier)
             )

    assert {:error, %Error{reason: :missing_recipient}} =
             SalesInvoices.create(oauth_client(), Map.delete(create_params(), :recipient))

    assert {:error, %Error{reason: :missing_lines}} =
             SalesInvoices.create(oauth_client(), Map.delete(create_params(), :lines))

    assert {:error, %Error{reason: :invalid_sales_invoice_params}} =
             SalesInvoices.update(oauth_client(), "invoice_123", %{})

    assert {:error, %Error{reason: :invalid_sales_invoice_params}} =
             SalesInvoices.update(oauth_client(), "invoice_123", %{testmode: false})

    assert {:error, %Error{reason: {:invalid_option, :from}}} =
             SalesInvoices.list(oauth_client(), from: "")

    assert {:error, %Error{reason: {:invalid_option, :limit}}} =
             SalesInvoices.list(oauth_client(), limit: 0)

    assert {:error, %Error{reason: :invalid_testmode}} =
             SalesInvoices.update(oauth_client(), "invoice_123", update_params(), testmode: "yes")

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             SalesInvoices.list(oauth_client(), idempotency_key: "read-123")

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             SalesInvoices.get(oauth_client(), "invoice_123", idempotency_key: "read-123")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             SalesInvoices.create(oauth_client(), create_params(), unknown: true)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             SalesInvoices.update(oauth_client(), "invoice_123", update_params(), unknown: true)

    assert {:error, %Error{reason: :invalid_options}} =
             SalesInvoices.get(oauth_client(), "invoice_123", :not_options)

    assert {:error, %Error{reason: :invalid_options}} =
             SalesInvoices.update(oauth_client(), "invoice_123", update_params(), :not_options)

    assert {:error, %Error{reason: :invalid_sales_invoice_params}} =
             SalesInvoices.update(oauth_client(), "invoice_123", :not_params)

    assert {:error, %Error{reason: :invalid_client}} = SalesInvoices.list(:not_a_client)

    assert {:error, %Error{reason: :invalid_client}} =
             SalesInvoices.create(:not_a_client, create_params())

    assert {:error, %Error{reason: :invalid_client}} =
             SalesInvoices.get(:not_a_client, "invoice_123")

    assert {:error, %Error{reason: :invalid_client}} =
             SalesInvoices.update(:not_a_client, "invoice_123", update_params())

    assert {:error, %Error{reason: :invalid_client}} =
             SalesInvoices.delete(:not_a_client, "invoice_123")

    refute_receive :request_sent, 10
  end

  test "does not retry sales invoice create without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    assert {:error, %Error{type: :server_error, status: 503}} =
             SalesInvoices.create(api_key_client(max_retries: 1), create_params())
  end

  test "retries sales invoice writes with caller idempotency keys" do
    for {operation, idempotency_key} <- [
          {:create, "sales-invoice-create-123"},
          {:update, "sales-invoice-update-123"},
          {:delete, "sales-invoice-delete-123"}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        assert header(conn, "idempotency-key") == idempotency_key

        conn
        |> Plug.Conn.put_status(503)
        |> Req.Test.json(%{"status" => 503})
      end)

      Req.Test.expect(__MODULE__, fn conn ->
        assert header(conn, "idempotency-key") == idempotency_key
        sales_invoice_response(operation, conn)
      end)

      assert {:ok, _result} =
               call_operation(operation, api_key_client(max_retries: 1), idempotency_key)
    end
  end

  test "retries safe sales invoice reads without idempotency keys" do
    for operation <- [:list, :get] do
      Req.Test.expect(__MODULE__, fn conn ->
        assert header(conn, "idempotency-key") == nil

        conn
        |> Plug.Conn.put_status(503)
        |> Req.Test.json(%{"status" => 503})
      end)

      Req.Test.expect(__MODULE__, fn conn ->
        assert header(conn, "idempotency-key") == nil
        sales_invoice_response(operation, conn)
      end)

      assert {:ok, _result} = call_operation(operation, oauth_client(max_retries: 1), nil)
    end
  end

  test "returns API errors for sales invoice calls" do
    cases = [
      {:create, 422, :validation},
      {:list, 400, :api_error},
      {:get, 404, :not_found},
      {:update, 422, :validation},
      {:delete, 404, :not_found}
    ]

    for {operation, status, type} <- cases do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(status)
        |> Req.Test.json(%{
          "status" => status,
          "title" => "Sales invoice error",
          "detail" => "Sales invoice request failed."
        })
      end)

      assert {:error, %Error{} = error} =
               call_operation(operation, api_key_client(max_retries: 0), nil)

      assert error.type == type
      assert error.status == status
      assert error.raw["title"] == "Sales invoice error"
    end
  end

  test "returns timeout errors for sales invoice calls" do
    for {operation, expected_operation} <- [
          {:create, :sales_invoices_create},
          {:list, :sales_invoices_list},
          {:get, :sales_invoices_get},
          {:update, :sales_invoices_update},
          {:delete, :sales_invoices_delete}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, %Error{} = error} =
               call_operation(operation, api_key_client(max_retries: 0), nil)

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

    assert {:error, %Error{} = error} =
             SalesInvoices.get(api_key_client(), "invoice_4Y0eZitmBnQ6IDoMqZQKh")

    assert error.type == :decode
    assert error.status == 200
    assert error.operation == :sales_invoices_get
  end

  test "returns decode errors for invalid sales invoice response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "sales-invoice"})
    end)

    assert {:error, %Error{} = error} =
             SalesInvoices.get(api_key_client(), "invoice_4Y0eZitmBnQ6IDoMqZQKh")

    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_sales_invoice_response
    assert error.operation == :sales_invoices_get
    assert error.raw == %{"resource" => "sales-invoice"}
  end

  test "returns decode errors for invalid sales invoice list shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"sales_invoices" => %{}},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{type: :decode, reason: :invalid_list_response}} =
             SalesInvoices.list(oauth_client())
  end

  test "returns decode errors for invalid sales invoice list items" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"sales_invoices" => [%{"resource" => "sales-invoice"}]},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{type: :decode, reason: :invalid_sales_invoice_response}} =
             SalesInvoices.list(oauth_client())
  end

  defp call_operation(:create, client, nil), do: SalesInvoices.create(client, create_params())

  defp call_operation(:create, client, idempotency_key),
    do: SalesInvoices.create(client, create_params(), idempotency_key: idempotency_key)

  defp call_operation(:list, client, _idempotency_key), do: SalesInvoices.list(client)

  defp call_operation(:get, client, _idempotency_key),
    do: SalesInvoices.get(client, "invoice_4Y0eZitmBnQ6IDoMqZQKh")

  defp call_operation(:update, client, nil),
    do: SalesInvoices.update(client, "invoice_4Y0eZitmBnQ6IDoMqZQKh", update_params())

  defp call_operation(:update, client, idempotency_key) do
    SalesInvoices.update(client, "invoice_4Y0eZitmBnQ6IDoMqZQKh", update_params(),
      idempotency_key: idempotency_key
    )
  end

  defp call_operation(:delete, client, nil),
    do: SalesInvoices.delete(client, "invoice_4Y0eZitmBnQ6IDoMqZQKh")

  defp call_operation(:delete, client, idempotency_key) do
    SalesInvoices.delete(client, "invoice_4Y0eZitmBnQ6IDoMqZQKh",
      idempotency_key: idempotency_key
    )
  end

  defp sales_invoice_response(:create, conn),
    do: fixture_response(conn, "sales_invoices/get_success.json", 201)

  defp sales_invoice_response(:list, conn),
    do: fixture_response(conn, "sales_invoices/list_success.json", 200)

  defp sales_invoice_response(:get, conn),
    do: fixture_response(conn, "sales_invoices/get_success.json", 200)

  defp sales_invoice_response(:update, conn),
    do: fixture_response(conn, "sales_invoices/get_success.json", 200)

  defp sales_invoice_response(:delete, conn), do: no_content_response(conn)

  defp create_params do
    %{
      currency: "EUR",
      status: "draft",
      vat_scheme: "standard",
      vat_mode: "exclusive",
      memo: "Order #123",
      metadata: %{"order_id" => "123"},
      payment_term: "30 days",
      payment_details: %{method: "banktransfer", amount: %{value: "107.69", currency: "EUR"}},
      email_details: %{
        subject: "Invoice for order #123",
        body: "Please find your invoice attached."
      },
      recipient_identifier: "recipient-123",
      recipient: %{
        type: "consumer",
        given_name: "Given",
        family_name: "Family",
        email: "given.family@example.org",
        street_and_number: "Street 1",
        postal_code: "1000 AA",
        city: "Amsterdam",
        country: "NL",
        locale: "nl_NL"
      },
      lines: [
        %{
          description: "LEGO 4440 Forest Police Station",
          quantity: 1,
          vat_rate: "21",
          unit_price: %{value: "89.00", currency: "EUR"},
          discount: nil
        }
      ],
      webhook_url: "https://example.org/webhooks/sales-invoice",
      discount: %{type: "percentage", percentage: "10"},
      is_e_invoice: false
    }
  end

  defp minimal_create_params do
    %{
      status: "draft",
      recipient_identifier: "recipient-123",
      recipient: %{type: "consumer", given_name: "Given", family_name: "Family"},
      lines: [
        %{
          description: "LEGO 4440 Forest Police Station",
          quantity: 1,
          vat_rate: "21",
          unit_price: %{value: "89.00", currency: "EUR"}
        }
      ]
    }
  end

  defp update_params do
    %{
      status: "issued",
      memo: "Updated memo",
      payment_term: "14 days",
      email_details: %{subject: "Updated invoice"},
      recipient_identifier: "recipient-123",
      recipient: %{type: "consumer", given_name: "Updated"},
      lines: [
        %{
          description: "Updated line",
          quantity: 2,
          vat_rate: "21",
          unit_price: %{value: "50.00", currency: "EUR"}
        }
      ],
      discount: %{type: "percentage", percentage: "5"},
      is_e_invoice: false
    }
  end

  defp expected_create_body do
    %{
      "currency" => "EUR",
      "status" => "draft",
      "vatScheme" => "standard",
      "vatMode" => "exclusive",
      "memo" => "Order #123",
      "metadata" => %{"order_id" => "123"},
      "paymentTerm" => "30 days",
      "paymentDetails" => %{
        "method" => "banktransfer",
        "amount" => %{"value" => "107.69", "currency" => "EUR"}
      },
      "emailDetails" => %{
        "subject" => "Invoice for order #123",
        "body" => "Please find your invoice attached."
      },
      "recipientIdentifier" => "recipient-123",
      "recipient" => %{
        "type" => "consumer",
        "givenName" => "Given",
        "familyName" => "Family",
        "email" => "given.family@example.org",
        "streetAndNumber" => "Street 1",
        "postalCode" => "1000 AA",
        "city" => "Amsterdam",
        "country" => "NL",
        "locale" => "nl_NL"
      },
      "lines" => [
        %{
          "description" => "LEGO 4440 Forest Police Station",
          "quantity" => 1,
          "vatRate" => "21",
          "unitPrice" => %{"value" => "89.00", "currency" => "EUR"},
          "discount" => nil
        }
      ],
      "webhookUrl" => "https://example.org/webhooks/sales-invoice",
      "discount" => %{"type" => "percentage", "percentage" => "10"},
      "isEInvoice" => false
    }
  end

  defp expected_minimal_create_body do
    %{
      "status" => "draft",
      "recipientIdentifier" => "recipient-123",
      "recipient" => %{"type" => "consumer", "givenName" => "Given", "familyName" => "Family"},
      "lines" => [
        %{
          "description" => "LEGO 4440 Forest Police Station",
          "quantity" => 1,
          "vatRate" => "21",
          "unitPrice" => %{"value" => "89.00", "currency" => "EUR"}
        }
      ]
    }
  end

  defp expected_update_body do
    %{
      "status" => "issued",
      "memo" => "Updated memo",
      "paymentTerm" => "14 days",
      "emailDetails" => %{"subject" => "Updated invoice"},
      "recipientIdentifier" => "recipient-123",
      "recipient" => %{"type" => "consumer", "givenName" => "Updated"},
      "lines" => [
        %{
          "description" => "Updated line",
          "quantity" => 2,
          "vatRate" => "21",
          "unitPrice" => %{"value" => "50.00", "currency" => "EUR"}
        }
      ],
      "discount" => %{"type" => "percentage", "percentage" => "5"},
      "isEInvoice" => false
    }
  end

  defp api_key_client(opts \\ []) do
    opts
    |> Keyword.put(:api_key, @api_key)
    |> then(&TestSupport.client(__MODULE__, &1))
  end

  defp oauth_client(opts \\ []) do
    opts
    |> Keyword.put(:profile_id, "pfl_QkEhN94Ba")
    |> Keyword.put(:oauth_token, @oauth_token)
    |> then(&TestSupport.client(__MODULE__, &1))
  end

  defp organization_client(opts) do
    opts
    |> Keyword.put(:organization_token, @organization_token)
    |> then(&TestSupport.client(__MODULE__, &1))
  end
end
