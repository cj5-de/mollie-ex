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

List refunds across the active API-key profile:

```elixir
{:ok, refunds} = MollieEx.Refunds.all(client, limit: 10, sort: :desc)
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

List chargebacks across the active API-key profile:

```elixir
{:ok, chargebacks} = MollieEx.Chargebacks.all(client, limit: 10, sort: :desc)
```

## Payment routes

Create, retrieve, update, and list delayed payment routes:

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

{:ok, route} =
  MollieEx.PaymentRoutes.update_release_date(
    client,
    "tr_123",
    "crt_123",
    "2026-07-01",
    idempotency_key: "2d5d68d4-c729-435f-8e8a-a1ef45ae8801"
  )

{:ok, routes} = MollieEx.PaymentRoutes.list(client, "tr_123")
```

## Payment links

Create, retrieve, list, update, delete, and inspect payments for payment links:

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
{:ok, payment_link_payments} = MollieEx.PaymentLinks.list_payments(client, "pl_123", limit: 10)

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

Create, retrieve, list, update, delete, and inspect payments for customers:

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

{:ok, payment} =
  MollieEx.Customers.create_payment(
    client,
    customer.id,
    %{
      amount: %{currency: "EUR", value: "10.00"},
      description: "Order #123",
      redirect_url: "https://example.org/checkout/return"
    },
    idempotency_key: "11298b4a-83c6-4e8e-b6ab-a2c9bc50ea32"
  )

{:ok, customer_payments} = MollieEx.Customers.list_payments(client, customer.id, limit: 10)

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

## Methods

Retrieve enabled or all payment methods:

```elixir
{:ok, methods} = MollieEx.Methods.list(client, include: "issuers")
{:ok, all_methods} = MollieEx.Methods.all(client)
{:ok, ideal} = MollieEx.Methods.get(client, "ideal", currency: "EUR")
```

## Mandates

Create, retrieve, list, and revoke customer mandates:

```elixir
{:ok, mandate} =
  MollieEx.Mandates.create(
    client,
    customer.id,
    %{
      method: "directdebit",
      consumer_name: "Jane Doe",
      consumer_account: "NL55INGB0000000000",
      signature_date: "2026-06-14"
    },
    idempotency_key: "fd4f5141-6f16-4220-b9d9-6e43ce80f7dc"
  )

{:ok, mandate} = MollieEx.Mandates.get(client, customer.id, mandate.id)
{:ok, mandates} = MollieEx.Mandates.list(client, customer.id, limit: 10)

{:ok, :no_content} =
  MollieEx.Mandates.revoke(
    client,
    customer.id,
    mandate.id,
    idempotency_key: "f9160307-fd02-4522-8d32-98ff7375c7d7"
  )
```

## Subscriptions

Create and manage customer subscriptions:

```elixir
{:ok, subscription} =
  MollieEx.Subscriptions.create(
    client,
    customer.id,
    %{
      amount: %{currency: "EUR", value: "25.00"},
      interval: "1 month",
      description: "Monthly plan",
      webhook_url: "https://example.com/webhooks/mollie"
    },
    idempotency_key: "270fa354-28bc-4a86-a230-47340647c490"
  )

{:ok, subscription} = MollieEx.Subscriptions.get(client, customer.id, subscription.id)
{:ok, subscriptions} = MollieEx.Subscriptions.list(client, customer.id, limit: 10)
{:ok, all_subscriptions} = MollieEx.Subscriptions.all(client, limit: 10)

{:ok, subscription} =
  MollieEx.Subscriptions.update(
    client,
    customer.id,
    subscription.id,
    %{amount: %{currency: "EUR", value: "30.00"}},
    idempotency_key: "1f7509f9-6d85-4501-8152-341ce953c1dc"
  )

{:ok, subscription_payments} =
  MollieEx.Subscriptions.list_payments(client, customer.id, subscription.id, limit: 10)

{:ok, canceled_subscription} =
  MollieEx.Subscriptions.cancel(
    client,
    customer.id,
    subscription.id,
    idempotency_key: "69c9801a-b8b6-4bd9-8f93-c1f22a5ca67d"
  )
```

## Profiles

Manage profiles with organization-level or OAuth-style bearer credentials:

```elixir
{:ok, profile} =
  MollieEx.Profiles.create(
    organization_client,
    %{
      name: "Example webshop",
      website: "https://example.com",
      email: "info@example.com",
      phone: "+31208202070",
      business_category: "OTHER_MERCHANDISE"
    },
    idempotency_key: "e44f783b-c2cd-49ef-85c8-e05a9b3a3f48"
  )

{:ok, profiles} = MollieEx.Profiles.list(organization_client, limit: 10)
{:ok, profile} = MollieEx.Profiles.get(organization_client, profile.id)
{:ok, profile} = MollieEx.Profiles.update(organization_client, profile.id, %{name: "Updated"})
{:ok, :no_content} = MollieEx.Profiles.delete(organization_client, profile.id)

{:ok, current_profile} = MollieEx.Profiles.current(api_key_client)
```

## Permissions

Retrieve permissions available to OAuth-style bearer credentials:

```elixir
{:ok, permissions} = MollieEx.Permissions.list(organization_client)
{:ok, permission} = MollieEx.Permissions.get(organization_client, "payments.read")

for permission <- permissions.data do
  IO.puts("#{permission.id}: #{permission.granted}")
end
```

## Organizations

Retrieve organizations and partner status with OAuth-style bearer credentials:

```elixir
{:ok, organization} = MollieEx.Organizations.current(organization_client)
{:ok, organization} = MollieEx.Organizations.get(organization_client, "org_12345678")
{:ok, partner_status} = MollieEx.Organizations.partner_status(organization_client)
```

## Idempotency

MollieEx accepts idempotency keys for write operations, but does not generate
them. Callers own key generation and storage.
