defmodule MollieEx.ProfilesTest do
  use ExUnit.Case, async: false

  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Profile
  alias MollieEx.Profiles
  alias MollieEx.TestSupport
  alias MollieEx.Types.Link

  import MollieEx.TestSupport, except: [client: 2]

  setup {Req.Test, :verify_on_exit!}

  @api_key "test_profiles_secret"
  @organization_token "org_profiles_secret"

  test "creates a profile with camelCased body and caller idempotency key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/profiles"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@organization_token}"
      assert header(conn, "idempotency-key") == "profile-123"

      assert_json_body(conn, %{
        "businessCategory" => "OTHER_MERCHANDISE",
        "countriesOfActivity" => ["NL", "BE"],
        "description" => "Example products",
        "email" => "info@example.test",
        "name" => "Example webshop",
        "phone" => "+31208202070",
        "website" => "https://example.test"
      })

      fixture_response(conn, "profiles/get_success.json", 201)
    end)

    assert {:ok, %Profile{} = profile} =
             Profiles.create(bearer_client(), profile_params(), idempotency_key: "profile-123")

    assert profile.id == "pfl_123"
    assert profile.countries_of_activity == ["NL", "BE"]
    assert profile.raw["unexpectedFutureField"] == true
  end

  test "lists profiles with pagination" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/profiles"
      assert URI.decode_query(conn.query_string) == %{"from" => "pfl_001", "limit" => "5"}
      assert_empty_body(conn)

      fixture_response(conn, "profiles/list_success.json", 200)
    end)

    assert {:ok, %MollieList{} = profile_list} =
             Profiles.list(bearer_client(), from: "pfl_001", limit: 5)

    assert profile_list.count == 1
    assert [%Profile{id: "pfl_list_123"}] = profile_list.data
    assert %Link{href: "https://api.mollie.com/v2/profiles"} = profile_list.links["self"]
  end

  test "gets a profile with testmode query for bearer clients" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/profiles/pfl_123"
      assert URI.decode_query(conn.query_string) == %{"testmode" => "false"}
      assert_empty_body(conn)

      fixture_response(conn, "profiles/get_success.json", 200)
    end)

    client =
      TestSupport.client(__MODULE__, organization_token: @organization_token, testmode: true)

    assert {:ok, %Profile{id: "pfl_123"}} = Profiles.get(client, "pfl_123", testmode: false)
  end

  test "gets current profile with API-key client" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/profiles/me"
      assert conn.query_string == ""
      assert header(conn, "authorization") == "Bearer #{@api_key}"
      assert_empty_body(conn)

      fixture_response(conn, "profiles/get_success.json", 200)
    end)

    assert {:ok, %Profile{id: "pfl_123"}} = Profiles.current(api_key_client())
  end

  test "updates and deletes profiles with bearer clients" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v2/profiles/pfl_123"
      assert header(conn, "idempotency-key") == "profile-update-123"

      assert_json_body(conn, %{
        "countriesOfActivity" => ["NL"],
        "description" => "Updated products",
        "name" => "Updated webshop"
      })

      fixture_response(conn, "profiles/get_success.json", 200)
    end)

    assert {:ok, %Profile{id: "pfl_123"}} =
             Profiles.update(
               bearer_client(),
               "pfl_123",
               %{
                 name: "Updated webshop",
                 description: "Updated products",
                 countries_of_activity: ["NL"]
               },
               idempotency_key: "profile-update-123"
             )

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v2/profiles/pfl_123"
      assert header(conn, "idempotency-key") == "profile-delete-123"
      assert_empty_body(conn)

      no_content_response(conn)
    end)

    assert {:ok, :no_content} =
             Profiles.delete(bearer_client(), "pfl_123", idempotency_key: "profile-delete-123")
  end

  test "enforces profile auth modes and validates input before sending" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :request_sent)
      Req.Test.json(conn, %{"id" => "pfl_123"})
    end)

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Profiles.create(api_key_client(), profile_params())

    assert {:error, %Error{reason: :unsupported_auth_mode}} = Profiles.list(api_key_client())

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Profiles.get(api_key_client(), "pfl_123")

    assert {:error, %Error{reason: :unsupported_auth_mode}} =
             Profiles.current(bearer_client())

    assert {:error, %Error{reason: :invalid_profile_id}} =
             Profiles.update(bearer_client(), "", %{})

    assert {:error, %Error{reason: {:unsupported_option, :testmode}}} =
             Profiles.delete(bearer_client(), "pfl_123", testmode: true)

    assert {:error, %Error{reason: :invalid_client}} = Profiles.list(:not_a_client)

    refute_receive :request_sent, 10
  end

  defp api_key_client do
    TestSupport.client(__MODULE__, api_key: @api_key)
  end

  defp bearer_client do
    TestSupport.client(__MODULE__, organization_token: @organization_token)
  end

  defp profile_params do
    %{
      name: "Example webshop",
      website: "https://example.test",
      email: "info@example.test",
      phone: "+31208202070",
      description: "Example products",
      countries_of_activity: ["NL", "BE"],
      business_category: "OTHER_MERCHANDISE"
    }
  end
end
