# Resources

This guide covers the public resource modules available in `mollie_ex`.

## Payments

Create a payment with `MollieEx.Payments.create/3`:

```elixir
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
```

Retrieve and inspect a payment:

```elixir
{:ok, payment} = MollieEx.Payments.get(client, "tr_123")

cond do
  MollieEx.Payment.paid?(payment) -> :ok
  MollieEx.Payment.open?(payment) -> {:pending, payment.raw}
  true -> {:payment_status, payment.status}
end
```

Update, cancel, and release an authorization:

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

{:ok, payment} =
  MollieEx.Payments.cancel(
    client,
    "tr_123",
    idempotency_key: "5c26fb1d-6fd0-43df-9b55-19b84e1f7b7a"
  )

{:ok, :accepted} =
  MollieEx.Payments.release_authorization(
    client,
    "tr_123",
    idempotency_key: "3f9e7465-dfac-4688-8840-f6814b0a16f5"
  )
```

List payments with Mollie pagination:

```elixir
{:ok, payment_list} = MollieEx.Payments.list(client, limit: 10, sort: :desc)

for payment <- payment_list.data do
  IO.puts("#{payment.id}: #{payment.status}")
end

next_page_url = payment_list.links["next"] && payment_list.links["next"].href
```

## Refunds

Create a refund for a payment:

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

## Captures

Create a capture for an authorized payment:

```elixir
{:ok, capture} =
  MollieEx.Captures.create(
    client,
    "tr_123",
    %{
      description: "Capture order #123",
      amount: %{currency: "EUR", value: "10.00"}
    },
    idempotency_key: "7da9444e-4360-4ab4-b411-73b33ac52b1f"
  )
```

Retrieve and list payment captures:

```elixir
{:ok, capture} = MollieEx.Captures.get(client, "tr_123", "cpt_123")
{:ok, captures} = MollieEx.Captures.list(client, "tr_123", limit: 10)
```

## Chargebacks

Retrieve and list payment chargebacks:

```elixir
{:ok, chargeback} = MollieEx.Chargebacks.get(client, "tr_123", "chb_123")
{:ok, chargebacks} = MollieEx.Chargebacks.list(client, "tr_123", limit: 10)
```

## Payment routes

Create, retrieve, and list delayed payment routes:

```elixir
{:ok, route} =
  MollieEx.PaymentRoutes.create(
    client,
    "tr_123",
    %{
      amount: %{currency: "EUR", value: "10.00"},
      destination: %{type: "organization", organization_id: "org_123"},
      description: "Payment for order #123"
    },
    idempotency_key: "1de10c6a-8b87-4e0c-9c88-52f4c8936d5d"
  )

{:ok, route} = MollieEx.PaymentRoutes.get(client, "tr_123", "crt_123")
{:ok, routes} = MollieEx.PaymentRoutes.list(client, "tr_123")
```

## Payment links

Create, retrieve, list, update, and delete payment links:

```elixir
{:ok, payment_link} =
  MollieEx.PaymentLinks.create(
    client,
    %{
      description: "Order #123",
      amount: %{currency: "EUR", value: "10.00"},
      redirect_url: "https://example.com/checkout/return"
    },
    idempotency_key: "fc1693c0-b788-46f5-9d08-61eac31d5ab8"
  )

checkout_url = MollieEx.PaymentLink.checkout_url(payment_link)

{:ok, payment_link} = MollieEx.PaymentLinks.get(client, "pl_123")
{:ok, payment_links} = MollieEx.PaymentLinks.list(client, limit: 10)

{:ok, payment_link} =
  MollieEx.PaymentLinks.update(
    client,
    "pl_123",
    %{description: "Updated order #123", archived: false},
    idempotency_key: "70d6fc9d-6ec8-4cc7-a7cd-f1fd3a961f0a"
  )

{:ok, :no_content} =
  MollieEx.PaymentLinks.delete(
    client,
    "pl_123",
    idempotency_key: "99c89c77-3a12-4272-9718-f0ba9eba2ffb"
  )
```

## Customers

Create, retrieve, list, update, and delete customers:

```elixir
{:ok, customer} =
  MollieEx.Customers.create(
    client,
    %{
      name: "Jane Doe",
      email: "jane@example.org",
      metadata: %{"crm_id" => "customer-123"}
    },
    idempotency_key: "0e4f812e-5d50-4fcb-8c42-153f17e52147"
  )

{:ok, customer} = MollieEx.Customers.get(client, customer.id)
{:ok, customers} = MollieEx.Customers.list(client, limit: 10)

{:ok, customer} =
  MollieEx.Customers.update(
    client,
    customer.id,
    %{name: "Jane Updated"},
    idempotency_key: "d7d336f4-193f-4f5d-8702-c9111355386d"
  )

{:ok, :no_content} =
  MollieEx.Customers.delete(
    client,
    customer.id,
    idempotency_key: "b5c820c4-941d-4f06-a117-cb6afae5ac07"
  )
```

## Idempotency

MollieEx accepts idempotency keys for write operations, but does not generate
them. Callers own key generation and storage.
