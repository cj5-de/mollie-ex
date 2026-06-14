# mollie_ex

Community driven Elixir SDK for [Mollie](https://www.mollie.com/de/).

Hex package and Mix application name: `:mollie_ex`.
Public SDK module namespace: `MollieEx.*`.

## Requirements

- Minimum Elixir: 1.17
- Recommended runtime: Elixir 1.19
- Supported OTP target: 25-28

## Installation

Add `mollie_ex` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mollie_ex, "~> 0.4.0"}
  ]
end
```

## Basic usage

Build an explicit client. The library does not read credentials from the
environment by itself.

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

## Documentation

Full guides and API reference are available on
[HexDocs](https://hexdocs.pm/mollie_ex/).
