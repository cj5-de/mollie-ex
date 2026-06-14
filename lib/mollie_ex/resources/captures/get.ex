defmodule MollieEx.Resources.Captures.Get do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_options [
    :embed,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, payment_id, capture_id, opts)
      when is_binary(payment_id) and is_binary(capture_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         {:ok, payment_id} <- Options.payment_id(payment_id),
         {:ok, capture_id} <- Options.capture_id(capture_id),
         {:ok, embed} <- Options.string_option(opts, :embed),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: Options.resource_path(["payments", payment_id, "captures", capture_id]),
        path_template: "/payments/{paymentId}/captures/{captureId}",
        query: Options.query(embed: embed, testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :captures_get,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _payment_id, _capture_id, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, payment_id, _capture_id, _opts) when not is_binary(payment_id),
    do: Options.configuration_error(:invalid_payment_id)

  def build(%Client{}, _payment_id, _capture_id, _opts),
    do: Options.configuration_error(:invalid_capture_id)
end
