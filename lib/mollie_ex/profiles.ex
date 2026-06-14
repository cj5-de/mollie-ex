defmodule MollieEx.Profiles do
  @moduledoc """
  Create, retrieve, list, update, and delete Mollie profiles.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.
  """
  @moduledoc since: "0.4.0"

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.List, as: MollieList
  alias MollieEx.Profile
  alias MollieEx.Resources.Profiles.{Create, Current, Delete, Get, Update}
  alias MollieEx.Resources.Profiles.List, as: ListRequest
  alias MollieEx.Resources.RequestRunner

  @type create_params :: map()
  @type create_option ::
          {:idempotency_key, String.t()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type list_option ::
          {:from, String.t()}
          | {:limit, pos_integer()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type get_option ::
          {:testmode, boolean()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type current_option ::
          {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type update_params :: map()
  @type update_option ::
          {:idempotency_key, String.t()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}
  @type delete_option ::
          {:idempotency_key, String.t()}
          | {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Creates a Mollie profile.

  Profile creation requires an organization/OAuth-style bearer credential.
  """
  @doc since: "0.4.0"
  @spec create(Client.t(), create_params(), [create_option()]) ::
          {:ok, Profile.t()} | {:error, Error.t()}
  def create(client, params, opts \\ [])

  def create(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    RequestRunner.run_resource(
      Create.build(client, params, opts),
      client,
      Profile,
      :profiles_create
    )
  end

  def create(%Client{}, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def create(%Client{}, _params, _opts), do: configuration_error(:invalid_profile_params)
  def create(_client, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Lists Mollie profiles.
  """
  @doc since: "0.4.0"
  @spec list(Client.t(), [list_option()]) ::
          {:ok, MollieList.t(Profile.t())} | {:error, Error.t()}
  def list(client, opts \\ [])

  def list(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource_list(
      ListRequest.build(client, opts),
      client,
      "profiles",
      Profile,
      :profiles_list
    )
  end

  def list(%Client{}, _opts), do: configuration_error(:invalid_options)
  def list(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves a profile by ID.
  """
  @doc since: "0.4.0"
  @spec get(Client.t(), String.t(), [get_option()]) ::
          {:ok, Profile.t()} | {:error, Error.t()}
  def get(client, profile_id, opts \\ [])

  def get(%Client{} = client, profile_id, opts)
      when is_binary(profile_id) and is_list(opts) do
    RequestRunner.run_resource(
      Get.build(client, profile_id, opts),
      client,
      Profile,
      :profiles_get
    )
  end

  def get(%Client{}, _profile_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def get(%Client{}, _profile_id, _opts), do: configuration_error(:invalid_profile_id)
  def get(_client, _profile_id, _opts), do: configuration_error(:invalid_client)

  @doc """
  Retrieves the profile tied to an API-key client.
  """
  @doc since: "0.4.0"
  @spec current(Client.t(), [current_option()]) ::
          {:ok, Profile.t()} | {:error, Error.t()}
  def current(client, opts \\ [])

  def current(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource(
      Current.build(client, opts),
      client,
      Profile,
      :profiles_current
    )
  end

  def current(%Client{}, _opts), do: configuration_error(:invalid_options)
  def current(_client, _opts), do: configuration_error(:invalid_client)

  @doc """
  Updates a profile by ID.

  Profile updates require an organization/OAuth-style bearer credential and
  support caller-owned idempotency keys.
  """
  @doc since: "0.4.0"
  @spec update(Client.t(), String.t(), update_params(), [update_option()]) ::
          {:ok, Profile.t()} | {:error, Error.t()}
  def update(client, profile_id, params, opts \\ [])

  def update(%Client{} = client, profile_id, params, opts)
      when is_binary(profile_id) and is_map(params) and is_list(opts) do
    RequestRunner.run_resource(
      Update.build(client, profile_id, params, opts),
      client,
      Profile,
      :profiles_update
    )
  end

  def update(%Client{}, _profile_id, _params, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def update(%Client{}, _profile_id, params, _opts) when not is_map(params),
    do: configuration_error(:invalid_profile_params)

  def update(%Client{}, _profile_id, _params, _opts), do: configuration_error(:invalid_profile_id)
  def update(_client, _profile_id, _params, _opts), do: configuration_error(:invalid_client)

  @doc """
  Deletes a profile by ID.
  """
  @doc since: "0.4.0"
  @spec delete(Client.t(), String.t(), [delete_option()]) ::
          {:ok, :no_content} | {:error, Error.t()}
  def delete(client, profile_id, opts \\ [])

  def delete(%Client{} = client, profile_id, opts)
      when is_binary(profile_id) and is_list(opts) do
    RequestRunner.run_no_content(Delete.build(client, profile_id, opts), client)
  end

  def delete(%Client{}, _profile_id, opts) when not is_list(opts),
    do: configuration_error(:invalid_options)

  def delete(%Client{}, _profile_id, _opts), do: configuration_error(:invalid_profile_id)
  def delete(_client, _profile_id, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
