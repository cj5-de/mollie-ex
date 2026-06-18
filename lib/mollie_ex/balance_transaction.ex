defmodule MollieEx.BalanceTransaction do
  @moduledoc """
  Balance transaction resource returned by the Mollie API.

  Stable fields are exposed as snake_case struct fields. The original decoded
  Mollie response is preserved in `raw` with upstream JSON casing unchanged.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.Money

  @type t :: %__MODULE__{
          id: String.t(),
          resource: String.t() | nil,
          type: String.t() | nil,
          created_at: String.t() | nil,
          result_amount: Money.t() | nil,
          initial_amount: Money.t() | nil,
          deductions: Money.t() | nil,
          deduction_details: map() | nil,
          context: map() | nil,
          raw: map()
        }

  @enforce_keys [:id, :raw]
  defstruct [
    :id,
    :resource,
    :type,
    :created_at,
    :result_amount,
    :initial_amount,
    :deductions,
    :deduction_details,
    :context,
    raw: %{}
  ]

  @doc false
  @spec from_response(Response.t(), atom()) :: {:ok, t()} | {:error, Error.t()}
  def from_response(%Response{body: %{} = body} = response, operation) do
    case Map.get(body, "id") do
      id when is_binary(id) and id != "" ->
        {:ok,
         %__MODULE__{
           id: id,
           resource: Map.get(body, "resource"),
           type: Map.get(body, "type"),
           created_at: Map.get(body, "createdAt"),
           result_amount: Money.from(Map.get(body, "resultAmount")),
           initial_amount: Money.from(Map.get(body, "initialAmount")),
           deductions: Money.from(Map.get(body, "deductions")),
           deduction_details: Map.get(body, "deductionDetails"),
           context: Map.get(body, "context"),
           raw: body
         }}

      _id ->
        invalid_response_error(operation, response)
    end
  end

  def from_response(%Response{} = response, operation),
    do: invalid_response_error(operation, response)

  defp invalid_response_error(operation, %Response{} = response) do
    {:error,
     Error.exception(
       type: :decode,
       status: response.status,
       headers: response.headers,
       raw: response.raw,
       reason: :invalid_balance_transaction_response,
       operation: operation
     )}
  end
end
