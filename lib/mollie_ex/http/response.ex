defmodule MollieEx.HTTP.Response do
  @moduledoc false

  @type headers :: %{optional(String.t()) => [String.t()]}

  @type t :: %__MODULE__{
          status: non_neg_integer(),
          headers: headers(),
          body: term(),
          raw: term()
        }

  @enforce_keys [:status, :headers]
  defstruct [
    :status,
    :headers,
    :body,
    :raw
  ]
end
