defmodule MollieEx.Types.Money do
  @moduledoc """
  Money amount returned by the Mollie API.

  `raw` preserves the original decoded Mollie payload.
  """

  @type t :: %__MODULE__{
          currency: String.t() | nil,
          value: String.t() | nil,
          raw: map()
        }

  defstruct [
    :currency,
    :value,
    raw: %{}
  ]

  @doc false
  @spec from(term()) :: t() | nil
  def from(%{} = raw) do
    %__MODULE__{
      currency: Map.get(raw, "currency"),
      value: Map.get(raw, "value"),
      raw: raw
    }
  end

  def from(_raw), do: nil
end
