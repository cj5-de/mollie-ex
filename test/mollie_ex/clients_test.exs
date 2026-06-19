defmodule MollieEx.ClientsTest do
  use ExUnit.Case, async: false

  alias MollieEx.ClientResource
  alias MollieEx.Clients
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.TestSupport
  alias MollieEx.Types.Link

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_clients_secret"
  @oauth_token "access_clients_secret"
  @organization_token "org_clients_secret"

  test "lists clients with pagination and embed options" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/clients"

      assert URI.decode_query(conn.query_string) == %{
               "embed" => "organization,onboarding,capabilities",
               "from" => "org_00000001",
               "limit" => "2"
             }

      assert header(conn, "authorization") == "Bearer dynamic_clients_secret"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "clients/list_success.json", 200)
    end)

    assert {:ok, %MollieList{} = client_list} =
             Clients.list(token_provider_client(),
               embed: "organization,onboarding,capabilities",
               from: "org_00000001",
               limit: 2
             )

    assert client_list.count == 2

    assert [
             %ClientResource{id: "org_12345678"} = first_client,
             %ClientResource{id: "org_87654321"}
           ] = client_list.data

    assert first_client.resource == "client"
    assert first_client.organization_created_at == "2023-04-06T13:10:19+00:00"
    assert first_client.commission == %{"count" => 3}
    assert first_client.embedded["organization"]["name"] == "Example Client"
    assert first_client.raw["unexpectedFutureField"] == true

    assert %Link{href: "https://api.mollie.com/v2/clients/org_12345678"} =
             first_client.links["self"]

    assert %Link{href: "https://api.mollie.com/v2/clients"} = client_list.links["self"]

    assert %Link{href: "https://api.mollie.com/v2/clients?from=org_87654321&limit=2"} =
             client_list.links["next"]
  end

  test "gets a client with path encoding and embed option" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/clients/org_123%2F456"
      assert URI.decode_query(conn.query_string) == %{"embed" => "organization,onboarding"}
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "clients/get_success.json", 200)
    end)

    assert {:ok, %ClientResource{} = client_resource} =
             Clients.get(organization_client(), "org_123/456", embed: "organization,onboarding")

    assert client_resource.id == "org_12345678"
    assert client_resource.commission == %{"count" => 3}
    assert client_resource.embedded["onboarding"]["status"] == "completed"

    assert %Link{href: "https://api.mollie.com/v2/clients/org_12345678"} =
             client_resource.links["self"]

    assert client_resource.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "rejects unsupported auth modes and invalid input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"resource" => "client", "id" => "org_12345678"})
    end)

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Clients.list(api_key_client())

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Clients.get(api_key_client(), "org_12345678")

    assert {:error, %Error{reason: :invalid_client_id}} =
             Clients.get(organization_client(), "")

    assert {:error, %Error{reason: {:invalid_option, :from}}} =
             Clients.list(organization_client(), from: "")

    assert {:error, %Error{reason: {:invalid_option, :limit}}} =
             Clients.list(organization_client(), limit: 251)

    assert {:error, %Error{reason: {:invalid_option, :embed}}} =
             Clients.get(organization_client(), "org_12345678", embed: 123)

    assert {:error, %Error{reason: {:unsupported_option, :testmode}}} =
             Clients.list(organization_client(), testmode: false)

    assert {:error, %Error{reason: {:unsupported_option, :profile_id}}} =
             Clients.get(organization_client(), "org_12345678", profile_id: "pfl_123")

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             Clients.list(organization_client(), idempotency_key: "read-123")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Clients.get(organization_client(), "org_12345678", unknown: true)

    assert {:error, %Error{reason: :invalid_options}} =
             Clients.get(organization_client(), "org_12345678", :not_options)

    assert {:error, %Error{reason: :invalid_client}} = Clients.list(:not_a_client)

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Clients.list(oauth_client())

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Clients.get(oauth_client(), "org_12345678")

    refute_receive :request_sent, 10
  end

  test "returns decode errors for invalid client list items" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"clients" => [%{"resource" => "client"}]},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{type: :decode, reason: :invalid_client_response}} =
             Clients.list(organization_client())
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

  def fetch_token, do: "dynamic_clients_secret"

  defp organization_client do
    TestSupport.client(__MODULE__, organization_token: @organization_token)
  end
end
