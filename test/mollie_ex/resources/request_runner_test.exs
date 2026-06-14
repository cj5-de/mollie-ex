defmodule MollieEx.Resources.RequestRunnerTest do
  use ExUnit.Case, async: true

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.Payment
  alias MollieEx.Resources.RequestRunner

  @api_key "test_request_runner_secret"

  describe "build-result helpers" do
    test "run_resource/4 returns build errors unchanged" do
      error = configuration_error()

      assert RequestRunner.run_resource({:error, error}, client(), Payment, :payments_get) ==
               {:error, error}
    end

    test "run_resource_list/5 returns build errors unchanged" do
      error = configuration_error()

      assert RequestRunner.run_resource_list(
               {:error, error},
               client(),
               "payments",
               Payment,
               :payments_list
             ) == {:error, error}
    end

    test "run_no_content/2 returns build errors unchanged" do
      error = configuration_error()

      assert RequestRunner.run_no_content({:error, error}, client()) == {:error, error}
    end

    test "run_accepted/2 returns build errors unchanged" do
      error = configuration_error()

      assert RequestRunner.run_accepted({:error, error}, client()) == {:error, error}
    end
  end

  defp client, do: Client.new!(api_key: @api_key)

  defp configuration_error do
    Error.exception(type: :configuration, reason: :invalid_options)
  end
end
