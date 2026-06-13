# MollieEx

`mollie_ex` is a community driven Elixir SDK for the Mollie API.

The Hex package and Mix application name is `:mollie_ex`. Public SDK modules
use the `MollieEx.*` namespace.

## Requirements

- Minimum Elixir: 1.17
- Recommended runtime: Elixir 1.19
- Supported OTP target: 25-28

## Installation

Add `mollie_ex` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mollie_ex, "~> 0.2.0"}
  ]
end
```

## Basic usage

Build an explicit `MollieEx.Client`. The library does not read credentials from
the environment by itself.

```elixir
client =
  MollieEx.Client.new!(
    api_key: System.fetch_env!("MOLLIE_API_KEY")
  )

{:ok, payment} =
  MollieEx.Payments.create(
    client,
    %{
      description: "Order #123",
      amount: %{currency: "EUR", value: "10.00"},
      redirect_url: "https://example.com/checkout/return"
    },
    idempotency_key: "9f0f9a78-9d56-4d2b-a7b6-7fdb8cc7d5f3"
  )

checkout_url = MollieEx.Payment.checkout_url(payment)
```

## Next steps

- [Getting started](guides/getting-started.md) covers installation, client
  setup, payment creation, and result handling.
- [Resources](guides/resources.md) covers payments, refunds, captures,
  chargebacks, payment routes, payment links, pagination, and idempotency.
- `MollieEx.Client`, `MollieEx.Payments`, `MollieEx.Refunds`,
  `MollieEx.Captures`, `MollieEx.Chargebacks`, `MollieEx.PaymentRoutes`,
  `MollieEx.PaymentLinks`, and `MollieEx.Customers` provide the API reference.
