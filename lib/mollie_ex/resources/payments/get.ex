defmodule MollieEx.Resources.Payments.Get do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :include,
    :embed,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, payment_id, opts) when is_binary(payment_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         {:ok, payment_id} <- Options.payment_id(payment_id),
         {:ok, include} <- Options.string_option(opts, :include),
         {:ok, embed} <- Options.string_option(opts, :embed),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: Options.resource_path(["payments", payment_id]),
        path_template: "/payments/{paymentId}",
        query: Options.query(include: include, embed: embed, testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :payments_get,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _payment_id, _opts), do: Options.configuration_error(:invalid_payment_id)
end
