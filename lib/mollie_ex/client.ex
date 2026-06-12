defmodule MollieEx.Client do
  @moduledoc """
  Explicit client configuration for MollieEx API calls.

  A client is immutable and carries all user-visible SDK configuration.
  Resource modules receive it explicitly instead of reading process state,
  application environment, or environment variables.
  """

  alias MollieEx.Error

  @default_base_url "https://api.mollie.com/v2"
  @default_connect_timeout 5_000
  @default_pool_timeout 5_000
  @default_receive_timeout 30_000
  @default_request_timeout 35_000
  @default_max_retries 3
  @default_max_retry_after 60_000
  @default_telemetry_prefix [:mollie]

  @auth_keys [:api_key, :oauth_token, :organization_token, :token_provider]
  @timeout_defaults [
    connect_timeout: @default_connect_timeout,
    pool_timeout: @default_pool_timeout,
    receive_timeout: @default_receive_timeout,
    request_timeout: @default_request_timeout
  ]

  @type credential :: String.t() | (-> String.t())

  @type auth ::
          {:api_key, credential()}
          | {:oauth, credential()}
          | {:organization_token, credential()}
          | {:token_provider, module(), atom(), list()}

  @type transport :: :finch | {:req_test, atom()}

  @type t :: %__MODULE__{
          base_url: String.t(),
          auth: auth(),
          profile_id: String.t() | nil,
          testmode: boolean() | nil,
          user_agent: String.t(),
          user_agent_suffix: String.t() | nil,
          finch_name: atom() | nil,
          transport: transport(),
          connect_timeout: pos_integer(),
          pool_timeout: pos_integer(),
          receive_timeout: pos_integer(),
          request_timeout: pos_integer(),
          max_retries: non_neg_integer(),
          max_retry_after: pos_integer(),
          telemetry_prefix: [atom()]
        }

  @enforce_keys [
    :base_url,
    :auth,
    :user_agent,
    :transport,
    :connect_timeout,
    :pool_timeout,
    :receive_timeout,
    :request_timeout,
    :max_retries,
    :max_retry_after,
    :telemetry_prefix
  ]

  defstruct [
    :base_url,
    :auth,
    :profile_id,
    :testmode,
    :user_agent,
    :user_agent_suffix,
    :finch_name,
    :transport,
    :connect_timeout,
    :pool_timeout,
    :receive_timeout,
    :request_timeout,
    :max_retries,
    :max_retry_after,
    :telemetry_prefix
  ]

  @doc """
  Builds a MollieEx client from explicit options.

  Exactly one auth mode must be configured. This function validates static
  configuration only; function credentials and token providers are not called
  during construction.
  """
  @spec new(keyword() | map()) :: {:ok, t()} | {:error, Error.t()}
  def new(opts) when is_list(opts) do
    with true <- Keyword.keyword?(opts),
         {:ok, auth} <- auth(opts),
         {:ok, base_url} <- base_url(opts),
         {:ok, user_agent_suffix} <- user_agent_suffix(opts),
         {:ok, transport} <- transport(opts),
         {:ok, finch_name} <- finch_name(opts),
         {:ok, timeouts} <- timeouts(opts),
         :ok <- validate_connect_timeout_scope(finch_name, timeouts),
         {:ok, max_retries} <- max_retries(opts),
         {:ok, max_retry_after} <- max_retry_after(opts),
         {:ok, telemetry_prefix} <- telemetry_prefix(opts),
         {:ok, profile_id} <- profile_id(opts),
         {:ok, testmode} <- testmode(opts),
         :ok <- validate_profile_scope(auth, profile_id, testmode) do
      {:ok,
       struct!(
         __MODULE__,
         [
           base_url: base_url,
           auth: auth,
           profile_id: profile_id,
           testmode: testmode,
           user_agent: user_agent(user_agent_suffix),
           user_agent_suffix: user_agent_suffix,
           finch_name: finch_name,
           transport: transport,
           max_retries: max_retries,
           max_retry_after: max_retry_after,
           telemetry_prefix: telemetry_prefix
         ] ++ timeouts
       )}
    else
      false -> {:error, configuration_error(:missing_auth)}
      {:error, reason} -> {:error, configuration_error(reason)}
    end
  end

  def new(opts) when is_map(opts) do
    opts
    |> Map.to_list()
    |> new()
  end

  def new(_opts), do: {:error, configuration_error(:missing_auth)}

  @doc """
  Builds a MollieEx client or raises `%MollieEx.Error{}` for invalid config.
  """
  @spec new!(keyword()) :: t()
  def new!(opts) do
    case new(opts) do
      {:ok, client} -> client
      {:error, error} -> raise error
    end
  end

  defp auth(opts) do
    case Enum.filter(@auth_keys, &Keyword.has_key?(opts, &1)) do
      [] -> {:error, :missing_auth}
      [key] -> auth(key, Keyword.fetch!(opts, key))
      _keys -> {:error, :multiple_auth_modes}
    end
  end

  defp auth(:api_key, credential) do
    credential_auth(:api_key, credential, :missing_api_key)
  end

  defp auth(:oauth_token, credential) do
    credential_auth(:oauth, credential, :missing_oauth_token)
  end

  defp auth(:organization_token, credential) do
    credential_auth(:organization_token, credential, :missing_organization_token)
  end

  defp auth(:token_provider, {module, function, args}) when is_list(args) do
    if named_atom?(module) and named_atom?(function) do
      {:ok, {:token_provider, module, function, args}}
    else
      {:error, :invalid_token_provider}
    end
  end

  defp auth(:token_provider, _provider), do: {:error, :invalid_token_provider}

  defp named_atom?(value) when value in [nil, true, false], do: false
  defp named_atom?(value), do: is_atom(value)

  defp credential_auth(kind, credential, missing_reason) do
    case credential(credential) do
      {:ok, credential} -> {:ok, {kind, credential}}
      :error -> {:error, missing_reason}
    end
  end

  defp credential(credential) when is_binary(credential) do
    credential = String.trim(credential)

    if credential == "" do
      :error
    else
      {:ok, credential}
    end
  end

  defp credential(credential) when is_function(credential, 0), do: {:ok, credential}
  defp credential(_credential), do: :error

  defp base_url(opts) do
    opts
    |> Keyword.get(:base_url, @default_base_url)
    |> normalize_base_url()
  end

  defp normalize_base_url(base_url) when is_binary(base_url) do
    base_url = String.trim(base_url)

    case URI.new(base_url) do
      {:ok, uri} ->
        if valid_base_url?(base_url, uri) do
          {:ok, String.trim_trailing(base_url, "/")}
        else
          {:error, :invalid_base_url}
        end

      {:error, _part} ->
        {:error, :invalid_base_url}
    end
  end

  defp normalize_base_url(_base_url), do: {:error, :invalid_base_url}

  defp valid_base_url?(base_url, %URI{} = uri) do
    no_control_characters?(base_url) and valid_base_uri?(uri)
  end

  defp valid_base_uri?(%URI{} = uri) do
    uri.scheme in ["http", "https"] and present?(uri.host) and is_nil(uri.userinfo) and
      is_nil(uri.query) and is_nil(uri.fragment)
  end

  defp no_control_characters?(value) do
    not String.match?(value, ~r/[\x00-\x1F\x7F]/)
  end

  defp user_agent_suffix(opts) do
    opts
    |> Keyword.get(:user_agent_suffix)
    |> normalize_user_agent_suffix()
  end

  defp normalize_user_agent_suffix(nil), do: {:ok, nil}

  defp normalize_user_agent_suffix(suffix) when is_binary(suffix) do
    suffix = String.trim(suffix)

    cond do
      String.contains?(suffix, ["\r", "\n"]) -> {:error, :invalid_user_agent_suffix}
      suffix == "" -> {:ok, nil}
      true -> {:ok, suffix}
    end
  end

  defp normalize_user_agent_suffix(_suffix), do: {:error, :invalid_user_agent_suffix}

  defp transport(opts) do
    opts
    |> Keyword.get(:transport, :finch)
    |> normalize_transport()
  end

  defp normalize_transport(:finch), do: {:ok, :finch}

  defp normalize_transport({:req_test, name}) do
    if named_atom?(name) do
      {:ok, {:req_test, name}}
    else
      {:error, :invalid_transport}
    end
  end

  defp normalize_transport(_transport), do: {:error, :invalid_transport}

  defp finch_name(opts) do
    opts
    |> Keyword.get(:finch_name)
    |> normalize_finch_name()
  end

  defp normalize_finch_name(nil), do: {:ok, nil}

  defp normalize_finch_name(name) do
    if named_atom?(name) do
      {:ok, name}
    else
      {:error, :invalid_finch_name}
    end
  end

  defp timeouts(opts) do
    Enum.reduce_while(@timeout_defaults, {:ok, []}, fn {key, default}, {:ok, timeouts} ->
      case positive_integer(Keyword.get(opts, key, default)) do
        {:ok, timeout} -> {:cont, {:ok, Keyword.put(timeouts, key, timeout)}}
        :error -> {:halt, {:error, :invalid_timeout}}
      end
    end)
  end

  defp validate_connect_timeout_scope(nil, _timeouts), do: :ok

  defp validate_connect_timeout_scope(_finch_name, timeouts) do
    if Keyword.fetch!(timeouts, :connect_timeout) == @default_connect_timeout do
      :ok
    else
      {:error, :unsupported_connect_timeout}
    end
  end

  defp max_retries(opts) do
    case Keyword.get(opts, :max_retries, @default_max_retries) do
      max_retries when is_integer(max_retries) and max_retries >= 0 -> {:ok, max_retries}
      _max_retries -> {:error, :invalid_retry_config}
    end
  end

  defp max_retry_after(opts) do
    case positive_integer(Keyword.get(opts, :max_retry_after, @default_max_retry_after)) do
      {:ok, max_retry_after} -> {:ok, max_retry_after}
      :error -> {:error, :invalid_retry_config}
    end
  end

  defp telemetry_prefix(opts) do
    telemetry_prefix = Keyword.get(opts, :telemetry_prefix, @default_telemetry_prefix)

    if proper_list?(telemetry_prefix) and telemetry_prefix != [] and
         Enum.all?(telemetry_prefix, &named_atom?/1) do
      {:ok, telemetry_prefix}
    else
      {:error, :invalid_telemetry_prefix}
    end
  end

  defp proper_list?([]), do: true
  defp proper_list?([_head | tail]), do: proper_list?(tail)
  defp proper_list?(_value), do: false

  defp profile_id(opts) do
    opts
    |> Keyword.get(:profile_id)
    |> normalize_profile_id()
  end

  defp normalize_profile_id(nil), do: {:ok, nil}

  defp normalize_profile_id(profile_id) when is_binary(profile_id) do
    profile_id = String.trim(profile_id)

    if profile_id == "" do
      {:error, :invalid_profile_id}
    else
      {:ok, profile_id}
    end
  end

  defp normalize_profile_id(_profile_id), do: {:error, :invalid_profile_id}

  defp testmode(opts) do
    case Keyword.get(opts, :testmode) do
      nil -> {:ok, nil}
      testmode when is_boolean(testmode) -> {:ok, testmode}
      _testmode -> {:error, :invalid_testmode}
    end
  end

  defp validate_profile_scope({:api_key, _credential}, profile_id, _testmode)
       when not is_nil(profile_id) do
    {:error, :unsupported_profile_id}
  end

  defp validate_profile_scope({:api_key, _credential}, _profile_id, testmode)
       when not is_nil(testmode) do
    {:error, :unsupported_testmode}
  end

  defp validate_profile_scope(_auth, _profile_id, _testmode), do: :ok

  defp user_agent(nil), do: base_user_agent()
  defp user_agent(suffix), do: base_user_agent() <> " " <> suffix

  defp base_user_agent do
    app_version =
      case Application.spec(:mollie_ex, :vsn) do
        nil -> "unknown"
        version -> to_string(version)
      end

    "mollie_ex/#{app_version} elixir/#{System.version()} otp/#{System.otp_release()}"
  end

  defp positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp positive_integer(_value), do: :error

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp configuration_error(reason) do
    Error.exception(type: :configuration, reason: reason)
  end
end

defimpl Inspect, for: MollieEx.Client do
  def inspect(client, _opts) do
    fields =
      [
        base_url: client.base_url,
        auth: auth_mode(client.auth),
        profile_id: client.profile_id,
        testmode: client.testmode,
        transport: client.transport
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    "#MollieEx.Client<#{fields_text(fields)}>"
  end

  defp auth_mode({mode, _credential}) when mode in [:api_key, :oauth, :organization_token] do
    mode
  end

  defp auth_mode({:token_provider, _module, _function, _args}), do: :token_provider

  defp fields_text(fields) do
    Enum.map_join(fields, ", ", fn {key, value} ->
      "#{key}: #{Kernel.inspect(value)}"
    end)
  end
end
