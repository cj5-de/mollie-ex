defmodule MollieEx.InvoicesTest do
  use ExUnit.Case, async: false

  alias MollieEx.Error
  alias MollieEx.Invoice
  alias MollieEx.Invoices
  alias MollieEx.List, as: MollieList
  alias MollieEx.TestSupport
  alias MollieEx.Types.Link

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_invoices_secret"
  @oauth_token "access_invoices_secret"
  @organization_token "org_invoices_secret"

  test "lists invoices with pagination and filter options" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/invoices"

      assert URI.decode_query(conn.query_string) == %{
               "from" => "inv_start",
               "limit" => "2",
               "reference" => "2024.10000",
               "sort" => "asc",
               "year" => "2024"
             }

      assert header(conn, "authorization") == "Bearer #{@oauth_token}"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "invoices/list_success.json", 200)
    end)

    assert {:ok, %MollieList{} = invoice_list} =
             Invoices.list(oauth_client(),
               from: "inv_start",
               limit: 2,
               reference: "2024.10000",
               sort: :asc,
               year: "2024"
             )

    assert invoice_list.count == 2

    assert [
             %Invoice{id: "inv_FrvewDA3Pr"} = paid_invoice,
             %Invoice{id: "inv_qVQkKkRq3p"} = overdue_invoice
           ] = invoice_list.data

    assert paid_invoice.resource == "invoice"
    assert paid_invoice.reference == "2024.10000"
    assert paid_invoice.vat_number == "NL123456789B01"
    assert paid_invoice.net_amount.value == "80.00"
    assert paid_invoice.vat_amount.value == "16.80"
    assert paid_invoice.gross_amount.value == "96.80"
    assert paid_invoice.lines |> hd() |> Map.get("description") == "Payments"
    assert paid_invoice.raw["unexpectedFutureField"] == true
    assert Invoice.paid?(paid_invoice)
    assert Invoice.overdue?(overdue_invoice)

    assert %Link{href: "https://api.mollie.com/v2/invoices/inv_FrvewDA3Pr"} =
             paid_invoice.links["self"]

    assert %Link{href: "https://api.mollie.com/v2/invoices?from=inv_start&limit=2"} =
             invoice_list.links["self"]

    assert %Link{href: "https://api.mollie.com/v2/invoices?from=inv_qVQkKkRq3p&limit=2"} =
             invoice_list.links["next"]
  end

  test "gets an invoice with path encoding" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/invoices/inv_2024%2F10000"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "invoices/get_success.json", 200)
    end)

    assert {:ok, %Invoice{} = invoice} =
             Invoices.get(organization_client([]), "inv_2024/10000")

    assert invoice.id == "inv_FrvewDA3Pr"
    assert invoice.reference == "2024.10000"
    assert invoice.issued_at == "2024-01-31"
    assert invoice.paid_at == "2024-02-14"
    assert invoice.due_at == "2024-02-14"
    assert invoice.raw["unexpectedFutureField"] == %{"visible" => true}

    assert %Link{href: "https://docs.mollie.com/reference/get-invoice"} =
             invoice.links["documentation"]
  end

  test "rejects API-key clients and invalid input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"count" => 0, "_embedded" => %{"invoices" => []}, "_links" => %{}})
    end)

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Invoices.list(api_key_client())

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Invoices.get(api_key_client(), "inv_FrvewDA3Pr")

    assert {:error, %Error{reason: :invalid_invoice_id}} =
             Invoices.get(oauth_client(), "")

    assert {:error, %Error{reason: {:invalid_option, :reference}}} =
             Invoices.list(oauth_client(), reference: "")

    assert {:error, %Error{reason: {:invalid_option, :year}}} =
             Invoices.list(oauth_client(), year: "")

    assert {:error, %Error{reason: {:invalid_option, :from}}} =
             Invoices.list(oauth_client(), from: "")

    assert {:error, %Error{reason: {:invalid_option, :limit}}} =
             Invoices.list(oauth_client(), limit: 0)

    assert {:error, %Error{reason: {:invalid_option, :sort}}} =
             Invoices.list(oauth_client(), sort: "newest")

    assert {:error, %Error{reason: {:unsupported_option, :testmode}}} =
             Invoices.list(oauth_client(), testmode: true)

    assert {:error, %Error{reason: {:unsupported_option, :testmode}}} =
             Invoices.get(oauth_client(), "inv_FrvewDA3Pr", testmode: true)

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             Invoices.list(oauth_client(), idempotency_key: "read-123")

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             Invoices.get(oauth_client(), "inv_FrvewDA3Pr", idempotency_key: "read-123")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Invoices.list(oauth_client(), unknown: true)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Invoices.get(oauth_client(), "inv_FrvewDA3Pr", unknown: true)

    assert {:error, %Error{reason: :invalid_options}} =
             Invoices.list(oauth_client(), :not_options)

    assert {:error, %Error{reason: :invalid_options}} =
             Invoices.get(oauth_client(), "inv_FrvewDA3Pr", :not_options)

    assert {:error, %Error{reason: :invalid_invoice_id}} =
             Invoices.get(oauth_client(), :not_an_id)

    assert {:error, %Error{reason: :invalid_client}} = Invoices.list(:not_a_client)

    assert {:error, %Error{reason: :invalid_client}} =
             Invoices.get(:not_a_client, "inv_FrvewDA3Pr")

    refute_receive :request_sent, 10
  end

  test "returns API errors for invoice list filters" do
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
             Invoices.list(organization_client(max_retries: 0), from: "bad")

    assert error.type == :api_error
    assert error.status == 400
    assert error.operation == :invoices_list
  end

  test "returns API errors for invoices" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{
        "status" => 404,
        "title" => "Not Found",
        "detail" => "No invoice exists with this ID."
      })
    end)

    assert {:error, %Error{} = error} =
             Invoices.get(organization_client(max_retries: 0), "inv_missing")

    assert error.type == :not_found
    assert error.status == 404
    assert error.operation == :invoices_get
  end

  test "returns timeout errors for invoices" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Error{} = error} =
             Invoices.list(organization_client(max_retries: 0))

    assert error.type == :timeout
    assert error.operation == :invoices_list
  end

  test "retries read requests without idempotency keys" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/invoices"
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/invoices"
      assert header(conn, "idempotency-key") == nil

      fixture_response(conn, "invoices/list_success.json", 200)
    end)

    assert {:ok, %MollieList{count: 2}} =
             Invoices.list(organization_client(max_retries: 1))
  end

  test "returns decode errors for malformed JSON responses" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.send_resp(200, "{")
    end)

    assert {:error, %Error{} = error} =
             Invoices.get(organization_client([]), "inv_FrvewDA3Pr")

    assert error.type == :decode
    assert error.status == 200
    assert error.operation == :invoices_get
  end

  test "returns decode errors for invalid invoice response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "invoice"})
    end)

    assert {:error, %Error{} = error} =
             Invoices.get(organization_client([]), "inv_FrvewDA3Pr")

    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_invoice_response
    assert error.operation == :invoices_get
    assert error.raw == %{"resource" => "invoice"}
  end

  test "returns decode errors for invalid invoice list shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"invoices" => %{}},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{type: :decode, reason: :invalid_list_response}} =
             Invoices.list(oauth_client())
  end

  test "returns decode errors for invalid invoice list items" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"invoices" => [%{"resource" => "invoice"}]},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{type: :decode, reason: :invalid_invoice_response}} =
             Invoices.list(oauth_client())
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
end
