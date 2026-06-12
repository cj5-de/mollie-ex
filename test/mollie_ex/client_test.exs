defmodule MollieEx.ClientTest do
  use ExUnit.Case, async: true

  alias MollieEx.Client
  alias MollieEx.Error

  @api_key "test_client_secret"
  @oauth_token "access_client_secret"
  @organization_token "org_client_secret"

  defmodule TokenProvider do
  end

  test "constructs an API-key client with defaults" do
    assert {:ok, %Client{} = client} = Client.new(api_key: @api_key)

    assert client.auth == {:api_key, @api_key}
    assert client.base_url == "https://api.mollie.com/v2"
    assert client.profile_id == nil
    assert client.testmode == nil
    assert client.user_agent =~ ~r/^mollie_ex\/.+ elixir\/.+ otp\/.+/
    assert client.user_agent_suffix == nil
    assert client.transport == :finch
    assert client.connect_timeout == 5_000
    assert client.pool_timeout == 5_000
    assert client.receive_timeout == 30_000
    assert client.request_timeout == 35_000
    assert client.max_retries == 3
    assert client.max_retry_after == 60_000
    assert client.telemetry_prefix == [:mollie]
  end

  test "constructs clients for each bearer-token auth mode" do
    cases = [
      {[oauth_token: @oauth_token], {:oauth, @oauth_token}},
      {[organization_token: @organization_token], {:organization_token, @organization_token}},
      {[token_provider: {TokenProvider, :fetch_token, [:tenant_secret]}],
       {:token_provider, TokenProvider, :fetch_token, [:tenant_secret]}}
    ]

    for {opts, expected_auth} <- cases do
      assert {:ok, %Client{} = client} =
               Client.new(opts ++ [profile_id: " pfl_123 ", testmode: true])

      assert client.auth == expected_auth
      assert client.profile_id == "pfl_123"
      assert client.testmode == true
    end
  end

  test "accepts zero-arity function credentials without calling them" do
    credential = fn -> raise "credential should not be called during construction" end

    assert {:ok, %Client{} = client} = Client.new(api_key: credential)
    assert {:api_key, stored_credential} = client.auth
    assert stored_credential == credential
  end

  test "normalizes optional configuration" do
    assert %Client{} =
             client =
             Client.new!(
               api_key: " #{@api_key} ",
               base_url: " http://localhost:4002/v2/ ",
               user_agent_suffix: " my-shop/1.2.3 ",
               finch_name: MyApp.MollieFinch,
               transport: {:req_test, __MODULE__},
               connect_timeout: 1_000,
               pool_timeout: 2_000,
               receive_timeout: 3_000,
               request_timeout: 4_000,
               max_retries: 0,
               max_retry_after: 5_000,
               telemetry_prefix: [:my_app, :mollie]
             )

    assert client.auth == {:api_key, @api_key}
    assert client.base_url == "http://localhost:4002/v2"
    assert client.user_agent_suffix == "my-shop/1.2.3"
    assert client.user_agent =~ " my-shop/1.2.3"
    assert client.finch_name == MyApp.MollieFinch
    assert client.transport == {:req_test, __MODULE__}
    assert client.connect_timeout == 1_000
    assert client.pool_timeout == 2_000
    assert client.receive_timeout == 3_000
    assert client.request_timeout == 4_000
    assert client.max_retries == 0
    assert client.max_retry_after == 5_000
    assert client.telemetry_prefix == [:my_app, :mollie]
  end

  test "new! raises configuration errors" do
    error =
      assert_raise Error, fn ->
        Client.new!(api_key: "")
      end

    assert error.type == :configuration
    assert error.reason == :missing_api_key
  end

  test "returns helpful auth validation errors" do
    cases = [
      {[], :missing_auth},
      {[api_key: @api_key, oauth_token: @oauth_token], :multiple_auth_modes},
      {[api_key: ""], :missing_api_key},
      {[api_key: nil], :missing_api_key},
      {[api_key: 123], :missing_api_key},
      {[oauth_token: ""], :missing_oauth_token},
      {[organization_token: ""], :missing_organization_token},
      {[token_provider: {nil, :fetch_token, []}], :invalid_token_provider},
      {[token_provider: {TokenProvider, nil, []}], :invalid_token_provider},
      {[token_provider: {TokenProvider, :fetch_token, :not_args}], :invalid_token_provider}
    ]

    for {opts, reason} <- cases do
      assert {:error, %Error{type: :configuration, reason: ^reason}} = Client.new(opts)
    end
  end

  test "validates base URL" do
    for base_url <- [
          "",
          "ftp://api.mollie.com/v2",
          "https://",
          "https://user:pass@example.com/v2",
          "https://api.mollie.com:abc/v2",
          "http://localhost:notaport/v2",
          "https://api.mollie.com/v2?token=secret",
          "https://api.mollie.com/v2#fragment",
          "https://api.mollie.com/v2\nAuthorization: Bearer secret",
          "https://api.mollie.com/v2\rbad",
          "https://api.mollie.com/v2/#{<<0>>}",
          123
        ] do
      assert {:error, %Error{type: :configuration, reason: :invalid_base_url}} =
               Client.new(api_key: @api_key, base_url: base_url)
    end
  end

  test "validates timeout values" do
    for timeout_key <- [:connect_timeout, :pool_timeout, :receive_timeout, :request_timeout],
        timeout <- [0, -1, "1000"] do
      opts = [api_key: @api_key] ++ [{timeout_key, timeout}]

      assert {:error, %Error{type: :configuration, reason: :invalid_timeout}} =
               Client.new(opts)
    end
  end

  test "validates retry configuration" do
    for opts <- [
          [api_key: @api_key, max_retries: -1],
          [api_key: @api_key, max_retries: "3"],
          [api_key: @api_key, max_retry_after: 0],
          [api_key: @api_key, max_retry_after: "60000"]
        ] do
      assert {:error, %Error{type: :configuration, reason: :invalid_retry_config}} =
               Client.new(opts)
    end
  end

  test "validates telemetry prefix" do
    for telemetry_prefix <- [
          [],
          :mollie,
          ["mollie"],
          [:mollie, nil],
          [:mollie | :bad],
          [:my_app, :mollie | :bad]
        ] do
      assert {:error, %Error{type: :configuration, reason: :invalid_telemetry_prefix}} =
               Client.new(api_key: @api_key, telemetry_prefix: telemetry_prefix)
    end
  end

  test "validates user-agent suffix" do
    for user_agent_suffix <- ["shop\n1", "shop\r1", 123] do
      assert {:error, %Error{type: :configuration, reason: :invalid_user_agent_suffix}} =
               Client.new(api_key: @api_key, user_agent_suffix: user_agent_suffix)
    end
  end

  test "validates transport" do
    for transport <- [:hackney, {:req_test, nil}, {:req_test, "name"}] do
      assert {:error, %Error{type: :configuration, reason: :invalid_transport}} =
               Client.new(api_key: @api_key, transport: transport)
    end
  end

  test "validates Finch name" do
    for finch_name <- ["MyApp.MollieFinch", true, false, 123] do
      assert {:error, %Error{type: :configuration, reason: :invalid_finch_name}} =
               Client.new(api_key: @api_key, finch_name: finch_name)
    end
  end

  test "validates profile_id and testmode values" do
    assert {:error, %Error{type: :configuration, reason: :invalid_profile_id}} =
             Client.new(oauth_token: @oauth_token, profile_id: "")

    assert {:error, %Error{type: :configuration, reason: :invalid_profile_id}} =
             Client.new(oauth_token: @oauth_token, profile_id: 123)

    assert {:error, %Error{type: :configuration, reason: :invalid_testmode}} =
             Client.new(oauth_token: @oauth_token, testmode: "true")
  end

  test "rejects client-level profile_id and testmode for API-key clients" do
    assert {:error, %Error{type: :configuration, reason: :unsupported_profile_id}} =
             Client.new(api_key: @api_key, profile_id: "pfl_123")

    assert {:error, %Error{type: :configuration, reason: :unsupported_testmode}} =
             Client.new(api_key: @api_key, testmode: false)
  end

  test "inspect hides auth credentials and token-provider details" do
    clients = [
      Client.new!(api_key: @api_key),
      Client.new!(oauth_token: @oauth_token, profile_id: "pfl_123", testmode: true),
      Client.new!(
        organization_token: @organization_token,
        profile_id: "pfl_123",
        testmode: false
      ),
      Client.new!(token_provider: {TokenProvider, :fetch_token, [:tenant_secret]})
    ]

    inspected_clients = Enum.map(clients, &inspect/1)

    assert Enum.any?(inspected_clients, &String.contains?(&1, "auth: :api_key"))
    assert Enum.any?(inspected_clients, &String.contains?(&1, "auth: :oauth"))
    assert Enum.any?(inspected_clients, &String.contains?(&1, "auth: :organization_token"))
    assert Enum.any?(inspected_clients, &String.contains?(&1, "auth: :token_provider"))

    for inspected <- inspected_clients do
      assert inspected =~ "#MollieEx.Client<"
      refute inspected =~ @api_key
      refute inspected =~ @oauth_token
      refute inspected =~ @organization_token
      refute inspected =~ "tenant_secret"
      refute inspected =~ "fetch_token"
    end
  end
end
