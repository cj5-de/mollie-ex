defmodule MollieEx.OnboardingTest do
  use ExUnit.Case, async: false

  alias MollieEx.Error
  alias MollieEx.Onboarding
  alias MollieEx.OnboardingStatus
  alias MollieEx.TestSupport
  alias MollieEx.Types.Link

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_onboarding_secret"
  @oauth_token "access_onboarding_secret"
  @organization_token "org_onboarding_secret"

  test "gets onboarding status for the current organization" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/onboarding/me"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@oauth_token}"
      assert header(conn, "idempotency-key") == nil
      assert_empty_body(conn)

      fixture_response(conn, "onboarding/get_success.json", 200)
    end)

    assert {:ok, %OnboardingStatus{} = status} = Onboarding.get(oauth_client())

    assert status.resource == "onboarding"
    assert status.name == "Mollie B.V."
    assert status.status == "completed"
    assert status.can_receive_payments == true
    assert status.can_receive_settlements == true
    assert status.signed_up_at == "2023-12-20T10:49:08.0Z"
    assert OnboardingStatus.completed?(status)
    refute OnboardingStatus.needs_data?(status)
    refute OnboardingStatus.in_review?(status)

    assert %Link{href: "https://api.mollie.com/v2/onboarding/me"} = status.links["self"]
    assert status.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "gets onboarding status with an organization token" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/onboarding/me"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert_empty_body(conn)

      fixture_response(conn, "onboarding/get_success.json", 200)
    end)

    assert {:ok, %OnboardingStatus{}} = Onboarding.get(organization_client())
  end

  test "rejects API-key clients and invalid input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"resource" => "onboarding"})
    end)

    assert {:error, %Error{reason: :unsupported_auth_mode}} = Onboarding.get(api_key_client())

    assert {:error, %Error{reason: {:unsupported_option, :testmode}}} =
             Onboarding.get(oauth_client(), testmode: false)

    assert {:error, %Error{reason: {:unsupported_option, :idempotency_key}}} =
             Onboarding.get(oauth_client(), idempotency_key: "read-123")

    assert {:error, %Error{reason: {:unsupported_option, :unknown}}} =
             Onboarding.get(oauth_client(), unknown: true)

    assert {:error, %Error{reason: :invalid_options}} =
             Onboarding.get(oauth_client(), :not_options)

    assert {:error, %Error{reason: :invalid_client}} = Onboarding.get(:not_a_client)

    refute_receive :request_sent, 10
  end

  test "returns decode errors for invalid onboarding responses" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"resource" => "organization"})
    end)

    assert {:error, %Error{type: :decode, reason: :invalid_onboarding_status_response}} =
             Onboarding.get(oauth_client())
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
