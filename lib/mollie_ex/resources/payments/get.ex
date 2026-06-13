defmodule MollieEx.Resources.Payments.Get do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Payments.Options

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
    with :ok <- Options.ensure_keyword(opts),
         :ok <- Options.reject_unknown(opts, @allowed_options),
         {:ok, payment_id} <- payment_id(payment_id),
         {:ok, include} <- Options.string_option(opts, :include),
         {:ok, embed} <- Options.string_option(opts, :embed),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      request = %Request{
        method: :get,
        path: "/payments/" <> encode_path_segment(payment_id),
        path_template: "/payments/{paymentId}",
        query: query(include, embed, testmode),
        idempotency_policy: :unsupported,
        operation: :payments_get,
        testmode: testmode
      }

      {:ok, request, Options.timeout_options(opts)}
    end
  end

  def build(%Client{}, _payment_id, _opts), do: configuration_error(:invalid_payment_id)

  defp payment_id(payment_id) do
    payment_id = String.trim(payment_id)

    if payment_id == "" do
      configuration_error(:invalid_payment_id)
    else
      {:ok, payment_id}
    end
  end

  defp query(include, embed, testmode) do
    []
    |> Options.put_query(:include, include)
    |> Options.put_query(:embed, embed)
    |> Options.put_query(:testmode, testmode)
  end

  defp encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)

  defp configuration_error(reason), do: Options.configuration_error(reason)
end
