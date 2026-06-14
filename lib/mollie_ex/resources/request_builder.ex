defmodule MollieEx.Resources.RequestBuilder do
  @moduledoc false

  alias MollieEx.HTTP.Request
  alias MollieEx.Resources.Options

  @spec build(keyword(), keyword()) :: {:ok, Request.t(), keyword()}
  def build(opts, attrs) when is_list(opts) and is_list(attrs) do
    request =
      attrs
      |> Keyword.put_new(:idempotency_policy, :unsupported)
      |> put_idempotency_key(opts)
      |> then(&struct!(Request, &1))

    {:ok, request, Options.timeout_options(opts)}
  end

  defp put_idempotency_key(attrs, opts) do
    case Keyword.fetch!(attrs, :idempotency_policy) do
      policy when policy in [:optional, :required] ->
        Keyword.put(attrs, :idempotency_key, Keyword.get(opts, :idempotency_key))

      :unsupported ->
        Keyword.delete(attrs, :idempotency_key)
    end
  end
end
