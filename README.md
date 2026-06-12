# mollie_ex

Community driven Elixir SDK for [Mollie](https://www.mollie.com/de/).

Hex package and Mix application name: `:mollie_ex`.
Public SDK module namespace: `MollieEx.*`.

## Requirements

- Minimum Elixir: 1.17
- Recommended runtime: Elixir 1.19
- Supported OTP target: 25-28

## Installation

The package can be installed by adding `mollie_ex` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:mollie_ex, "~> 0.0.1"}
  ]
end
```

## Usage

Build an explicit client. The library does not read credentials from the
environment by itself.

```elixir
client =
  MollieEx.Client.new!(
    api_key: System.fetch_env!("MOLLIE_API_KEY")
  )
```

Create a payment with a caller-owned idempotency key. Mollie returns a checkout
link in the payment response.

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

checkout_url = payment.links["checkout"].href
```

Retrieve a payment by ID:

```elixir
{:ok, payment} = MollieEx.Payments.get(client, "tr_123")

case payment.status do
  "paid" -> :ok
  "open" -> {:pending, payment.raw}
  status -> {:payment_status, status}
end
```

Update a payment with a caller-owned idempotency key:

```elixir
{:ok, payment} =
  MollieEx.Payments.update(
    client,
    "tr_123",
    %{
      description: "Updated order #123",
      redirect_url: "https://example.com/checkout/return",
      metadata: %{"order_id" => "123"}
    },
    idempotency_key: "e1e6e0e2-4260-4f18-a11f-061f5a9d3ed7"
  )
```

List payments with ordinary Mollie pagination:

```elixir
{:ok, payment_list} = MollieEx.Payments.list(client, limit: 10, sort: :desc)

for payment <- payment_list.data do
  IO.puts("#{payment.id}: #{payment.status}")
end

next_page_url = payment_list.links["next"] && payment_list.links["next"].href
```

All public resource functions return result tuples:

```elixir
{:ok, %MollieEx.Payment{}}
{:ok, %MollieEx.List{}}
{:error, %MollieEx.Error{}}
```
