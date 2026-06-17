defmodule MollieEx.Resources.Balances.Primary do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, opts) when is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: "/balances/primary",
        path_template: "/balances/primary",
        query: Options.query(testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :balances_primary,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _opts), do: Options.configuration_error(:invalid_options)
end
