defmodule MollieEx.HTTP.Request do
  @moduledoc false

  @type method :: :delete | :get | :head | :patch | :post | :put
  @type idempotency_policy :: :unsupported | :optional | :required

  @type t :: %__MODULE__{
          method: method(),
          path: String.t(),
          query: keyword() | map(),
          headers: [{String.t(), String.t()}],
          body: term(),
          idempotency_key: String.t() | nil,
          idempotency_policy: idempotency_policy(),
          operation: atom() | nil,
          path_template: String.t() | nil,
          testmode: boolean() | nil,
          retry_policy: :default | :disabled
        }

  @enforce_keys [:method, :path]
  defstruct [
    :method,
    :path,
    query: [],
    headers: [],
    body: nil,
    idempotency_key: nil,
    idempotency_policy: :unsupported,
    operation: nil,
    path_template: nil,
    testmode: nil,
    retry_policy: :default
  ]
end
