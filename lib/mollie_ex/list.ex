defmodule MollieEx.List do
  @moduledoc """
  Paginated list returned by the Mollie API.

  `data` contains hydrated resources. `raw` preserves the original decoded
  Mollie list payload with upstream JSON casing unchanged.
  """

  alias MollieEx.Types.Link

  @type t(item) :: %__MODULE__{
          data: [item],
          count: non_neg_integer(),
          links: %{optional(String.t()) => Link.t() | term()},
          raw: map()
        }
  @type t :: t(term())

  @enforce_keys [:count, :raw]
  defstruct [
    :count,
    data: [],
    links: %{},
    raw: %{}
  ]
end
