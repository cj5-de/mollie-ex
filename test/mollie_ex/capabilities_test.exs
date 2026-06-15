defmodule MollieEx.CapabilitiesTest do
  use ExUnit.Case, async: false

  alias MollieEx.Capabilities
  alias MollieEx.Capability
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.TestSupport
  alias MollieEx.Types.Link

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_capabilities_secret"
  @oauth_token "access_capabilities_secret"
  @organization_token "org_capabilities_secret"

  test "lists capabilities for the current organization" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/capabilities"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@oauth_token}"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "capabilities/list_success.json", 200)
    end)

    assert {:ok, %MollieList{} = capability_list} = Capabilities.list(oauth_client())

    assert capability_list.count == 2

    assert [
             %Capability{name: "payments", status: "pending"} = payments,
             %Capability{name: "capital", status: "disabled"} = capital
           ] = capability_list.data

    assert payments.status_reason == "onboarding-information-needed"
    assert payments.organization_id == "org_12345678"
    assert [%{"id" => "legal-representatives"} | _requirements] = payments.requirements
    assert Capability.pending?(payments)
    refute Capability.enabled?(payments)
    refute Capability.disabled?(payments)

    assert Capability.disabled?(capital)

    assert %Link{href: "https://api.mollie.com/v2/capabilities/payments"} =
             payments.links["self"]

    assert %Link{href: "https://api.mollie.com/v2/capabilities"} =
             capability_list.links["self"]

    assert payments.raw["unexpectedFutureField"] == true
  end

  test "lists capabilities with an organization token" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/capabilities"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert_empty_body(conn)

      fixture_response(conn, "capabilities/list_success.json", 200)
    end)

    assert {:ok, %MollieList{}} = Capabilities.list(organization_client())
  end

  test "rejects API-key clients and invalid input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)

      Req.Test.json(conn, %{"count" => 0, "_embedded" => %{"capabilities" => []}, "_links" => %{}})
    end)

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Capabilities.list(api_key_client())

    assert {:error, %Error{reason: {:unsupported_option, :testmode}}} =
             Capabilities.list(oauth_client(), testmode: false)

    assert {:error, %Error{reason: {:unsupported_option, :profile_id}}} =
             Capabilities.list(oauth_client(), profile_id: "pfl_123")

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             Capabilities.list(oauth_client(), idempotency_key: "read-123")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Capabilities.list(oauth_client(), unknown: true)

    assert {:error, %Error{reason: :invalid_options}} =
             Capabilities.list(oauth_client(), :not_options)

    assert {:error, %Error{reason: :invalid_client}} = Capabilities.list(:not_a_client)

    refute_receive :request_sent, 10
  end

  test "returns decode errors for invalid capability list items" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "count" => 1,
        "_embedded" => %{"capabilities" => [%{"resource" => "capability"}]},
        "_links" => %{}
      })
    end)

    assert {:error, %Error{type: :decode, reason: :invalid_capability_response}} =
             Capabilities.list(oauth_client())
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
