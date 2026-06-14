defmodule MollieEx.Resources.OptionsTest do
  use ExUnit.Case, async: true

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.Resources.Options

  @api_key "test_options_secret"
  @oauth_token "access_options_secret"

  describe "query/1" do
    test "builds query keywords from non-nil values" do
      query = Options.query(from: "tr_123", limit: nil, sort: "desc", testmode: false)

      assert query[:from] == "tr_123"
      assert query[:sort] == "desc"
      assert query[:testmode] == false
      refute Keyword.has_key?(query, :limit)
    end

    test "preserves existing put_query ordering semantics" do
      assert Options.query(from: "tr_123", limit: 10, sort: "asc") == [
               sort: "asc",
               limit: 10,
               from: "tr_123"
             ]
    end
  end

  describe "resource_path/1" do
    test "joins static path segments with a leading slash" do
      assert Options.resource_path(["payments"]) == "/payments"
    end

    test "joins nested resource path segments" do
      assert Options.resource_path(["payments", "tr_123", "refunds", "re_123"]) ==
               "/payments/tr_123/refunds/re_123"
    end

    test "encodes unsafe dynamic path segment characters" do
      assert Options.resource_path(["payments", "tr_123/with space", "refunds"]) ==
               "/payments/tr_123%2Fwith%20space/refunds"
    end
  end

  describe "validate_options/2" do
    test "accepts keyword options with only allowed keys" do
      assert :ok = Options.validate_options([from: "tr_123", limit: 10], [:from, :limit])
    end

    test "rejects non-keyword lists as invalid options" do
      assert {:error, %Error{reason: :invalid_options}} =
               Options.validate_options([:from, "tr_123"], [:from])
    end

    test "rejects the first unsupported option" do
      assert {:error, %Error{reason: {:unsupported_option, :extra}}} =
               Options.validate_options([from: "tr_123", extra: true], [:from])
    end
  end

  describe "param helpers" do
    test "fetch_param/2 returns the first present key, including nil values" do
      params = %{"profileId" => "pfl_string", profile_id: nil}

      assert Options.fetch_param(params, [:profile_id, "profileId"]) == {:ok, nil}
      assert Options.fetch_param(params, ["profileId", :profile_id]) == {:ok, "pfl_string"}
      assert Options.fetch_param(params, [:missing]) == :error
    end

    test "param_or_default/3 uses the default only when no key is present" do
      assert Options.param_or_default(%{testmode: nil}, [:testmode], true) == nil
      assert Options.param_or_default(%{}, [:testmode], true) == true
    end

    test "require_param/3 checks key presence only" do
      assert :ok = Options.require_param(%{"amount" => nil}, [:amount, "amount"], :missing_amount)

      assert {:error, %Error{reason: :missing_amount}} =
               Options.require_param(%{}, [:amount, "amount"], :missing_amount)
    end
  end

  describe "API-key scoped field rejection" do
    test "reject_profile_id/1 rejects all supported profile key shapes" do
      for params <- [
            %{profile_id: "pfl_123"},
            %{"profile_id" => "pfl_123"},
            %{"profileId" => nil}
          ] do
        assert {:error, %Error{reason: :unsupported_profile_id}} =
                 Options.reject_profile_id(params)
      end

      assert :ok = Options.reject_profile_id(%{})
    end

    test "reject_api_key_testmode/3 rejects opts and params testmode for API-key clients" do
      client = api_key_client()

      assert {:error, %Error{reason: :unsupported_testmode}} =
               Options.reject_api_key_testmode(client, %{}, testmode: false)

      assert {:error, %Error{reason: :unsupported_testmode}} =
               Options.reject_api_key_testmode(client, %{testmode: false}, [])

      assert {:error, %Error{reason: :unsupported_testmode}} =
               Options.reject_api_key_testmode(client, %{"testmode" => nil}, [])

      assert :ok =
               Options.reject_api_key_testmode(oauth_client(), %{testmode: false}, testmode: true)
    end

    test "reject_api_key_scoped_fields/2 preserves profile-before-testmode precedence" do
      client = api_key_client()

      assert {:error, %Error{reason: :unsupported_profile_id}} =
               Options.reject_api_key_scoped_fields(client,
                 profile_id: "pfl_123",
                 testmode: false
               )

      assert {:error, %Error{reason: :unsupported_testmode}} =
               Options.reject_api_key_scoped_fields(client, testmode: false)

      assert :ok =
               Options.reject_api_key_scoped_fields(oauth_client(),
                 profile_id: "pfl_123",
                 testmode: false
               )
    end

    test "reject_api_key_scoped_fields/3 preserves profile-before-testmode precedence" do
      client = api_key_client()

      assert {:error, %Error{reason: :unsupported_profile_id}} =
               Options.reject_api_key_scoped_fields(client, %{profile_id: nil}, testmode: false)

      assert {:error, %Error{reason: :unsupported_testmode}} =
               Options.reject_api_key_scoped_fields(client, %{"testmode" => nil}, [])

      assert :ok =
               Options.reject_api_key_scoped_fields(
                 oauth_client(),
                 %{profile_id: "pfl_123", testmode: false},
                 testmode: true
               )
    end
  end

  describe "effective profile and testmode helpers" do
    test "effective_profile_id/2 resolves opts before client default" do
      client = oauth_client(profile_id: "pfl_default")

      assert Options.effective_profile_id(client, profile_id: "pfl_override") ==
               {:ok, "pfl_override"}

      assert Options.effective_profile_id(client, []) == {:ok, "pfl_default"}

      assert {:error, %Error{reason: :missing_profile_id}} =
               Options.effective_profile_id(oauth_client(), [])

      assert {:error, %Error{reason: :invalid_profile_id}} =
               Options.effective_profile_id(client, profile_id: "")

      assert Options.effective_profile_id(api_key_client(), profile_id: "pfl_ignored") ==
               {:ok, nil}
    end

    test "effective_profile_id/3 resolves opts before params before client default" do
      client = oauth_client(profile_id: "pfl_default")

      assert Options.effective_profile_id(client, %{"profileId" => "pfl_params"},
               profile_id: "pfl_opts"
             ) == {:ok, "pfl_opts"}

      assert Options.effective_profile_id(client, %{"profileId" => "pfl_params"}, []) ==
               {:ok, "pfl_params"}

      assert Options.effective_profile_id(client, %{}, []) == {:ok, "pfl_default"}

      assert {:error, %Error{reason: :missing_profile_id}} =
               Options.effective_profile_id(oauth_client(), %{profile_id: nil}, [])

      assert Options.effective_profile_id(api_key_client(), %{profile_id: "pfl_ignored"}, []) ==
               {:ok, nil}
    end

    test "effective_testmode/3 resolves opts before params before client default" do
      client = oauth_client(testmode: true)

      assert Options.effective_testmode(client, %{"testmode" => true}, testmode: false) ==
               {:ok, false}

      assert Options.effective_testmode(client, %{"testmode" => false}, []) == {:ok, false}
      assert Options.effective_testmode(client, %{}, []) == {:ok, true}
      assert Options.effective_testmode(client, %{testmode: nil}, []) == {:ok, nil}

      assert {:error, %Error{reason: :invalid_testmode}} =
               Options.effective_testmode(client, %{"testmode" => "false"}, [])

      assert Options.effective_testmode(api_key_client(), %{testmode: false}, testmode: true) ==
               {:ok, nil}
    end
  end

  describe "body helpers" do
    test "body_with_testmode/4 cases structured fields and resolves effective testmode" do
      client = oauth_client(testmode: true)

      assert {:ok, body, false} =
               Options.body_with_testmode(
                 client,
                 %{
                   amount: %{currency: "EUR", value: "10.00"},
                   metadata: %{order_id: "ord_123"},
                   testmode: true
                 },
                 [testmode: false],
                 ~w(amount)
               )

      assert body == %{
               "amount" => %{"currency" => "EUR", "value" => "10.00"},
               "metadata" => %{order_id: "ord_123"},
               "testmode" => false
             }
    end

    test "body_with_profile/5 resolves profile and testmode before body params" do
      client = oauth_client(profile_id: "pfl_default", testmode: true)

      assert {:ok, body, false} =
               Options.body_with_profile(
                 client,
                 %{
                   profile_id: "pfl_params",
                   testmode: true,
                   amount: %{currency: "EUR", value: "10.00"}
                 },
                 [profile_id: "pfl_opts", testmode: false],
                 ~w(amount),
                 []
               )

      assert body == %{
               "amount" => %{"currency" => "EUR", "value" => "10.00"},
               "profileId" => "pfl_opts",
               "testmode" => false
             }
    end

    test "body_with_profile/5 drops extra relationship keys after casing" do
      client = oauth_client(profile_id: "pfl_default")

      assert {:ok, body, nil} =
               Options.body_with_profile(
                 client,
                 %{customer_id: "cst_123", description: "Order #123"},
                 [],
                 [],
                 ["customerId", "customer_id", :customer_id]
               )

      assert body == %{"description" => "Order #123", "profileId" => "pfl_default"}
    end

    test "body helpers return effective profile and testmode errors unchanged" do
      assert {:error, %Error{reason: :missing_profile_id}} =
               Options.body_with_profile(oauth_client(), %{profile_id: nil}, [], [], [])

      assert {:error, %Error{reason: :invalid_testmode}} =
               Options.body_with_testmode(oauth_client(), %{"testmode" => "false"}, [], [])
    end
  end

  defp api_key_client, do: Client.new!(api_key: @api_key)
  defp oauth_client(opts \\ []), do: Client.new!(Keyword.put(opts, :oauth_token, @oauth_token))
end
