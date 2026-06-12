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

checkout_url = MollieEx.Payment.checkout_url(payment)
```

Retrieve a payment by ID:

```elixir
{:ok, payment} = MollieEx.Payments.get(client, "tr_123")

cond do
  MollieEx.Payment.paid?(payment) -> :ok
  MollieEx.Payment.open?(payment) -> {:pending, payment.raw}
  true -> {:payment_status, payment.status}
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

Cancel a payment with a caller-owned idempotency key:

```elixir
{:ok, payment} =
  MollieEx.Payments.cancel(
    client,
    "tr_123",
    idempotency_key: "5c26fb1d-6fd0-43df-9b55-19b84e1f7b7a"
  )
```

Release a payment authorization with a caller-owned idempotency key:

```elixir
{:ok, :accepted} =
  MollieEx.Payments.release_authorization(
    client,
    "tr_123",
    idempotency_key: "3f9e7465-dfac-4688-8840-f6814b0a16f5"
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

Create a refund for a payment with a caller-owned idempotency key:

```elixir
{:ok, refund} =
  MollieEx.Refunds.create(
    client,
    "tr_123",
    %{
      description: "Refund order #123",
      amount: %{currency: "EUR", value: "10.00"}
    },
    idempotency_key: "f7f88f02-9a60-4a1f-bab8-8ef9e29cfeaf"
  )
```

Retrieve, list, and cancel payment refunds:

```elixir
{:ok, refund} = MollieEx.Refunds.get(client, "tr_123", "re_123")
{:ok, refunds} = MollieEx.Refunds.list(client, "tr_123", limit: 10)
{:ok, :no_content} =
  MollieEx.Refunds.cancel(
    client,
    "tr_123",
    "re_123",
    idempotency_key: "c3f6a4f9-2505-4374-8bb2-71dbfdf5a1ec"
  )
```

All public resource functions return result tuples:

```elixir
{:ok, %MollieEx.Payment{}}
{:ok, %MollieEx.Refund{}}
{:ok, %MollieEx.List{}}
{:ok, :no_content}
{:ok, :accepted}
{:error, %MollieEx.Error{}}
```
