defmodule MollieEx.Types.Link do
  @moduledoc """
  HAL link returned by the Mollie API.

  `raw` preserves the original decoded Mollie link payload.
  """

  @type t :: %__MODULE__{
          href: String.t() | nil,
          type: String.t() | nil,
          raw: map()
        }

  defstruct [
    :href,
    :type,
    raw: %{}
  ]

  @doc false
  @spec from(term()) :: t() | term()
  def from(%{} = raw) do
    %__MODULE__{
      href: Map.get(raw, "href"),
      type: Map.get(raw, "type"),
      raw: raw
    }
  end

  def from(raw), do: raw
end
