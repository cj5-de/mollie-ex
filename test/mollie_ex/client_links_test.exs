defmodule MollieEx.ClientLinksTest do
  use ExUnit.Case, async: false

  alias MollieEx.ClientLink
  alias MollieEx.ClientLinks
  alias MollieEx.Error
  alias MollieEx.TestSupport
  alias MollieEx.Types.Link

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_client_links_secret"
  @oauth_token "access_client_links_secret"
  @organization_token "org_client_links_secret"

  test "creates a client link with camelCased body and caller idempotency key" do
    expected_body = expected_create_body()

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/client-links"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer dynamic_client_links_secret"
      assert header(conn, "idempotency-key") == "client-link-123"
      assert_json_body(conn, expected_body)

      fixture_response(conn, "client_links/create_success.json", 201)
    end)

    assert {:ok, %ClientLink{} = client_link} =
             ClientLinks.create(token_provider_client(), create_params(),
               idempotency_key: "client-link-123"
             )

    assert client_link.id == "cl_vZCnNQsV2UtfXxYifWKWH"
    assert client_link.resource == "client-link"
    assert client_link.raw["unexpectedFutureField"] == true

    assert %Link{href: "https://my.mollie.com/dashboard/client-link/cl_vZCnNQsV2UtfXxYifWKWH"} =
             client_link.links["clientLink"]
  end

  test "rejects unsupported auth modes and invalid input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"resource" => "client-link", "id" => "cl_123"})
    end)

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             ClientLinks.create(api_key_client(), create_params())

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             ClientLinks.create(oauth_client(), create_params())

    assert {:error, %Error{reason: :invalid_client_link_params}} =
             ClientLinks.create(organization_client([]), :not_params)

    assert {:error, %Error{reason: :invalid_options}} =
             ClientLinks.create(organization_client([]), create_params(), :not_options)

    assert {:error, %Error{reason: {:unsupported_option, :testmode}}} =
             ClientLinks.create(organization_client([]), create_params(), testmode: false)

    assert {:error, %Error{reason: :missing_owner}} =
             ClientLinks.create(organization_client([]), Map.delete(create_params(), :owner))

    assert {:error, %Error{reason: :missing_name}} =
             ClientLinks.create(organization_client([]), Map.delete(create_params(), :name))

    assert {:error, %Error{reason: :missing_address}} =
             ClientLinks.create(organization_client([]), Map.delete(create_params(), :address))

    assert {:error, %Error{reason: :invalid_client}} =
             ClientLinks.create(:not_a_client, create_params())

    refute_receive :request_sent, 10
  end

  test "returns API errors for client link create" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(422)
      |> Req.Test.json(%{
        "status" => 422,
        "title" => "Unprocessable Entity",
        "detail" => "The owner field is missing.",
        "_links" => %{"documentation" => %{"href" => "https://docs.mollie.com/"}}
      })
    end)

    assert {:error, %Error{} = error} =
             ClientLinks.create(organization_client(max_retries: 0), create_params())

    assert error.type == :validation
    assert error.status == 422
    assert error.raw["detail"] == "The owner field is missing."
  end

  test "returns timeout errors for client link create" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Error{} = error} =
             ClientLinks.create(organization_client(max_retries: 0), create_params())

    assert error.type == :timeout
    assert error.operation == :client_links_create
  end

  test "does not retry client link create without idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == nil

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    assert {:error, %Error{type: :server_error, status: 503}} =
             ClientLinks.create(organization_client(max_retries: 1), create_params())
  end

  test "retries client link create with the same caller idempotency key and body" do
    expected_body = expected_create_body()

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "client-link-123"
      assert_json_body(conn, expected_body)

      conn
      |> Plug.Conn.put_status(503)
      |> Req.Test.json(%{"status" => 503})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert header(conn, "idempotency-key") == "client-link-123"
      assert_json_body(conn, expected_body)
      fixture_response(conn, "client_links/create_success.json", 201)
    end)

    assert {:ok, %ClientLink{id: "cl_vZCnNQsV2UtfXxYifWKWH"}} =
             ClientLinks.create(
               organization_client(max_retries: 1),
               create_params(),
               idempotency_key: "client-link-123"
             )
  end

  test "returns decode errors for malformed JSON responses" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.send_resp(201, "{")
    end)

    assert {:error, %Error{} = error} =
             ClientLinks.create(organization_client([]), create_params())

    assert error.type == :decode
    assert error.status == 201
    assert error.operation == :client_links_create
  end

  test "returns decode errors for invalid client link response shapes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "client-link"})
    end)

    assert {:error, %Error{} = error} =
             ClientLinks.create(organization_client([]), create_params())

    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_client_link_response
    assert error.operation == :client_links_create
    assert error.raw == %{"resource" => "client-link"}
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

  def fetch_token, do: "dynamic_client_links_secret"

  defp organization_client(opts) do
    opts
    |> Keyword.put(:organization_token, @organization_token)
    |> then(&TestSupport.client(__MODULE__, &1))
  end

  defp create_params do
    %{
      owner: %{
        email: "merchant@example.test",
        given_name: "Ada",
        family_name: "Lovelace",
        locale: "en_US"
      },
      name: "Example Client",
      address: %{
        street_and_number: "Keizersgracht 313",
        postal_code: "1016 EE",
        city: "Amsterdam",
        country: "NL"
      },
      registration_number: "30204462",
      vat_number: "NL123456789B01",
      legal_entity: "private_limited_company",
      registration_office: "NL",
      incorporation_date: "2024-02-24"
    }
  end

  defp expected_create_body do
    %{
      "owner" => %{
        "email" => "merchant@example.test",
        "givenName" => "Ada",
        "familyName" => "Lovelace",
        "locale" => "en_US"
      },
      "name" => "Example Client",
      "address" => %{
        "streetAndNumber" => "Keizersgracht 313",
        "postalCode" => "1016 EE",
        "city" => "Amsterdam",
        "country" => "NL"
      },
      "registrationNumber" => "30204462",
      "vatNumber" => "NL123456789B01",
      "legalEntity" => "private_limited_company",
      "registrationOffice" => "NL",
      "incorporationDate" => "2024-02-24"
    }
  end
end
