defmodule MollieEx.OrganizationsTest do
  use ExUnit.Case, async: false

  alias MollieEx.Error
  alias MollieEx.Organization
  alias MollieEx.Organizations
  alias MollieEx.Partner
  alias MollieEx.TestSupport
  alias MollieEx.Types.Link

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_organizations_secret"
  @oauth_token "access_organizations_secret"
  @organization_token "org_organizations_secret"

  test "gets an organization with testmode query for bearer clients" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/organizations/org_12345678"
      assert URI.decode_query(conn.query_string) == %{"testmode" => "false"}
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert_empty_body(conn)

      fixture_response(conn, "organizations/get_success.json", 200)
    end)

    client =
      TestSupport.client(__MODULE__,
        organization_token: @organization_token,
        testmode: true
      )

    assert {:ok, %Organization{} = organization} =
             Organizations.get(client, "org_12345678", testmode: false)

    assert organization.id == "org_12345678"
    assert organization.registration_number == "30204462"
    assert organization.raw["unexpectedFutureField"] == true
  end

  test "gets the current organization" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/organizations/me"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@oauth_token}"
      assert_empty_body(conn)

      fixture_response(conn, "organizations/get_success.json", 200)
    end)

    assert {:ok, %Organization{} = organization} = Organizations.current(oauth_client())

    assert organization.id == "org_12345678"
    assert organization.name == "Mollie B.V."

    assert %Link{href: "https://api.mollie.com/v2/organizations/org_12345678"} =
             organization.links["self"]
  end

  test "gets partner status for the current organization" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/organizations/me/partner"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert_empty_body(conn)

      fixture_response(conn, "organizations/partner_status_success.json", 200)
    end)

    assert {:ok, %Partner{} = partner} = Organizations.partner_status(organization_client())

    assert partner.resource == "partner"
    assert partner.partner_type == "oauth"
    assert partner.is_commission_partner == true
    assert [%{"token" => "ua_123"}] = partner.user_agent_tokens
    assert partner.partner_contract_update_available == false
    assert partner.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "rejects API-key clients and invalid input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "org_12345678"})
    end)

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Organizations.get(api_key_client(), "org_12345678")

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Organizations.current(api_key_client())

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Organizations.partner_status(api_key_client())

    assert {:error, %Error{reason: :invalid_organization_id}} =
             Organizations.get(oauth_client(), "")

    assert {:error, %Error{reason: {:unsupported_option, :testmode}}} =
             Organizations.current(oauth_client(), testmode: false)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Organizations.partner_status(oauth_client(), unknown: true)

    assert {:error, %Error{reason: :invalid_options}} =
             Organizations.get(oauth_client(), "org_12345678", :not_options)

    assert {:error, %Error{reason: :invalid_client}} = Organizations.current(:not_a_client)

    refute_receive :request_sent, 10
  end

  defp api_key_client do
    TestSupport.client(__MODULE__, api_key: @api_key)
  end

  defp oauth_client do
    TestSupport.client(__MODULE__, oauth_token: @oauth_token)
  end

  defp organization_client do
    TestSupport.client(__MODULE__, organization_token: @organization_token)
  end
end
