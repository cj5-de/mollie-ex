defmodule MollieEx.Resources.Balances.GetReport do
  @moduledoc false

  alias MollieEx.Client
  alias MollieEx.Error
  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options
  alias MollieEx.Resources.RequestBuilder

  @allowed_groupings ["status-balances", "transaction-categories"]

  @allowed_options [
    :grouping,
    :testmode,
    :pool_timeout,
    :receive_timeout,
    :request_timeout
  ]

  @spec build(Client.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, Request.t(), keyword()} | {:error, Error.t()}
  def build(%Client{} = client, balance_id, from, until, opts)
      when is_binary(balance_id) and is_list(opts) do
    with :ok <- Options.validate_options(opts, @allowed_options),
         :ok <- Options.reject_api_key_client(client),
         {:ok, balance_id} <- Options.balance_id(balance_id),
         {:ok, from} <- report_date(from, :invalid_report_from),
         {:ok, until} <- report_date(until, :invalid_report_until),
         {:ok, grouping} <- grouping(opts),
         {:ok, testmode} <- Options.effective_testmode(client, opts) do
      RequestBuilder.build(opts,
        method: :get,
        path: Options.resource_path(["balances", balance_id, "report"]),
        path_template: "/balances/{balanceId}/report",
        query: Options.query(from: from, until: until, grouping: grouping, testmode: testmode),
        idempotency_policy: :unsupported,
        operation: :balances_get_report,
        testmode: testmode
      )
    end
  end

  def build(%Client{}, _balance_id, _from, _until, opts) when not is_list(opts),
    do: Options.configuration_error(:invalid_options)

  def build(%Client{}, _balance_id, _from, _until, _opts),
    do: Options.configuration_error(:invalid_balance_id)

  defp report_date(value, reason) when is_binary(value) do
    value
    |> String.trim()
    |> Date.from_iso8601()
    |> case do
      {:ok, date} -> {:ok, Date.to_iso8601(date)}
      {:error, _reason} -> Options.configuration_error(reason)
    end
  end

  defp report_date(_value, reason), do: Options.configuration_error(reason)

  defp grouping(opts) do
    case Keyword.get(opts, :grouping) do
      nil -> {:ok, nil}
      grouping when grouping in @allowed_groupings -> {:ok, grouping}
      _grouping -> Options.configuration_error({:invalid_option, :grouping})
    end
  end
end
