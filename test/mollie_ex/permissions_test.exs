defmodule MollieEx.PermissionsTest do
  use ExUnit.Case, async: false

  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Permission
  alias MollieEx.Permissions
  alias MollieEx.TestSupport
  alias MollieEx.Types.Link

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_permissions_secret"
  @oauth_token "access_permissions_secret"
  @organization_token "org_permissions_secret"

  test "lists permissions for the current access token" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/permissions"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@oauth_token}"
      assert_empty_body(conn)

      fixture_response(conn, "permissions/list_success.json", 200)
    end)

    assert {:ok, %MollieList{} = permission_list} = Permissions.list(oauth_client())

    assert permission_list.count == 2

    assert [
             %Permission{id: "payments.read", description: "View your payments", granted: true} =
               read_permission,
             %Permission{id: "payments.write", granted: false}
           ] = permission_list.data

    assert read_permission.raw["unexpectedFutureField"] == true
    assert %Link{href: "https://api.mollie.com/v2/permissions"} = permission_list.links["self"]
  end

  test "gets a permission with testmode query for bearer clients" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/permissions/payments.read"
      assert URI.decode_query(conn.query_string) == %{"testmode" => "false"}
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert_empty_body(conn)

      fixture_response(conn, "permissions/get_success.json", 200)
    end)

    client =
      TestSupport.client(__MODULE__,
        organization_token: @organization_token,
        testmode: true
      )

    assert {:ok, %Permission{} = permission} =
             Permissions.get(client, "payments.read", testmode: false)

    assert permission.id == "payments.read"
    assert permission.granted == true

    assert %Link{href: "https://api.mollie.com/v2/permissions/payments.read"} =
             permission.links["self"]

    assert permission.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "rejects API-key clients and invalid input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "payments.read"})
    end)

    assert {:error, %Error{reason: :unsupported_auth_mode}} = Permissions.list(api_key_client())

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Permissions.get(api_key_client(), "payments.read")

    assert {:error, %Error{reason: :invalid_permission_id}} =
             Permissions.get(oauth_client(), "")

    assert {:error, %Error{reason: {:unsupported_option, :testmode}}} =
             Permissions.list(oauth_client(), testmode: false)

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Permissions.get(oauth_client(), "payments.read", unknown: true)

    assert {:error, %Error{reason: :invalid_options}} =
             Permissions.get(oauth_client(), "payments.read", :not_options)

    assert {:error, %Error{reason: :invalid_client}} = Permissions.list(:not_a_client)

    refute_receive :request_sent, 10
  end

  test "returns decode errors for invalid permission list items" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"permissions" => [%{"resource" => "permission"}]},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{type: :decode, reason: :invalid_permission_response}} =
             Permissions.list(oauth_client())
  end

  defp api_key_client do
    TestSupport.client(__MODULE__, api_key: @api_key)
  end

  defp oauth_client do
    TestSupport.client(__MODULE__, oauth_token: @oauth_token)
  end
end
