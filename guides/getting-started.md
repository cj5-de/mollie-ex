# Getting started

This guide shows the shortest path from installation to a Mollie payment.

## Installation

Add `mollie_ex` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mollie_ex, "~> 0.3.0"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## Create a client

MollieEx uses explicit clients. It does not read credentials from application
configuration or environment variables by itself.

```elixir
client =
  MollieEx.Client.new!(
    api_key: System.fetch_env!("MOLLIE_API_KEY")
  )
```

Use `MollieEx.Client.new/1` when invalid configuration should be returned as an
error tuple:

```elixir
{:ok, client} = MollieEx.Client.new(api_key: System.fetch_env!("MOLLIE_API_KEY"))
{:error, %MollieEx.Error{}} = MollieEx.Client.new(api_key: "")
```

## Create a payment

Write operations accept caller-owned idempotency keys. The SDK never generates
idempotency keys implicitly.

```elixir
idempotency_key = "9f0f9a78-9d56-4d2b-a7b6-7fdb8cc7d5f3"

{:ok, payment} =
  MollieEx.Payments.create(
    client,
    %{
      description: "Order #123",
      amount: %{currency: "EUR", value: "10.00"},
      redirect_url: "https://example.com/checkout/return",
      webhook_url: "https://example.com/webhooks/mollie"
    },
    idempotency_key: idempotency_key
  )

checkout_url = MollieEx.Payment.checkout_url(payment)
```

## Handle results

Public resource functions return result tuples:

```elixir
{:ok, %MollieEx.Payment{}}
{:ok, %MollieEx.Refund{}}
{:ok, %MollieEx.Capture{}}
{:ok, %MollieEx.List{}}
{:ok, :no_content}
{:ok, :accepted}
{:error, %MollieEx.Error{}}
```

For payment status helpers, see `MollieEx.Payment`.
