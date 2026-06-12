defmodule MollieEx.HTTP.FinchAdapter do
  @moduledoc false

  alias MollieEx.Client

  @timeout_http_reasons [:timeout, :request_timeout]

  @spec ensure_pool(Client.t()) :: :ok | {:error, Exception.t()}
  def ensure_pool(%Client{transport: {:req_test, _name}}), do: :ok
  def ensure_pool(%Client{finch_name: nil}), do: :ok

  def ensure_pool(%Client{} = client) do
    client.finch_name
    |> Finch.start_pool(
      Finch.Pool.new(client.base_url),
      conn_opts: [transport_opts: [timeout: client.connect_timeout]]
    )
  rescue
    exception in ArgumentError ->
      if unknown_registry?(exception) do
        {:error, Req.TransportError.exception(reason: :finch_not_started)}
      else
        reraise exception, __STACKTRACE__
      end
  end

  @spec put_options(keyword(), Client.t(), pos_integer()) :: keyword()
  def put_options(req_options, %Client{} = client, request_timeout) do
    req_options
    |> Keyword.put(:finch_request, request_fun(request_timeout))
    |> maybe_put_finch(client)
    |> maybe_put_req_test(client)
  end

  @spec request_fun(pos_integer()) :: function()
  def request_fun(request_timeout) do
    fn req, finch_request, finch_name, finch_options ->
      finch_options = Keyword.put(finch_options, :request_timeout, request_timeout)

      case request_finch(finch_request, finch_name, finch_options) do
        {:ok, finch_response} -> {req, Req.Response.new(finch_response)}
        {:error, exception} -> {req, normalize_error(exception)}
      end
    end
  end

  defp maybe_put_finch(req_options, %Client{finch_name: nil, connect_timeout: connect_timeout}),
    do: Keyword.put(req_options, :connect_options, timeout: connect_timeout)

  defp maybe_put_finch(req_options, %Client{finch_name: finch}),
    do: Keyword.put(req_options, :finch, finch)

  defp maybe_put_req_test(req_options, %Client{transport: {:req_test, name}}) do
    req_options
    |> Keyword.delete(:finch_request)
    |> Keyword.delete(:finch)
    |> Keyword.delete(:connect_options)
    |> Keyword.put(:plug, {Req.Test, name})
  end

  defp maybe_put_req_test(req_options, %Client{transport: :finch}), do: req_options

  defp request_finch(finch_request, finch_name, finch_options) do
    Finch.request(finch_request, finch_name, finch_options)
  rescue
    exception in RuntimeError ->
      if checkout_timeout?(exception) do
        {:error, Req.TransportError.exception(reason: :timeout)}
      else
        reraise exception, __STACKTRACE__
      end

    exception in ArgumentError ->
      if unknown_registry?(exception) do
        {:error, Req.TransportError.exception(reason: :finch_not_started)}
      else
        reraise exception, __STACKTRACE__
      end
  catch
    :exit, {:timeout, {NimblePool, :checkout, _affected_pids}} ->
      {:error, Req.TransportError.exception(reason: :timeout)}
  end

  defp checkout_timeout?(%RuntimeError{} = exception) do
    exception
    |> Exception.message()
    |> String.contains?("Finch was unable to provide a connection within the timeout")
  end

  defp unknown_registry?(%ArgumentError{} = exception) do
    exception
    |> Exception.message()
    |> String.contains?(["unknown registry:", "is not running"])
  end

  defp normalize_error(%Req.TransportError{} = error), do: error
  defp normalize_error(%Req.HTTPError{} = error), do: error

  defp normalize_error(%Finch.Error{reason: reason})
       when reason in @timeout_http_reasons,
       do: Req.TransportError.exception(reason: :timeout)

  defp normalize_error(%Finch.Error{reason: reason}),
    do: Req.HTTPError.exception(protocol: :http2, reason: reason)

  defp normalize_error(%Finch.TransportError{reason: reason}),
    do: Req.TransportError.exception(reason: reason)

  defp normalize_error(%Finch.HTTPError{module: Mint.HTTP2, reason: reason}),
    do: Req.HTTPError.exception(protocol: :http2, reason: reason)

  defp normalize_error(%Finch.HTTPError{reason: reason}),
    do: Req.HTTPError.exception(protocol: :http1, reason: reason)
end
