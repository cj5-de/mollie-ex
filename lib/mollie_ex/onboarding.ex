defmodule MollieEx.Onboarding do
  @moduledoc """
  Retrieve the onboarding status for the current organization.

  All functions return result tuples. They do not raise for ordinary API,
  transport, or validation failures.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.OnboardingStatus
  alias MollieEx.Resources.Onboarding.Get
  alias MollieEx.Resources.RequestRunner

  @type option ::
          {:pool_timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
          | {:request_timeout, pos_integer()}

  @doc """
  Retrieves the onboarding status for the currently authenticated organization.
  """
  @doc since: "0.5.0"
  @spec get(Client.t(), [option()]) :: {:ok, OnboardingStatus.t()} | {:error, Error.t()}
  def get(client, opts \\ [])

  def get(%Client{} = client, opts) when is_list(opts) do
    RequestRunner.run_resource(
      Get.build(client, opts),
      client,
      OnboardingStatus,
      :onboarding_get
    )
  end

  def get(%Client{}, _opts), do: configuration_error(:invalid_options)
  def get(_client, _opts), do: configuration_error(:invalid_client)

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
