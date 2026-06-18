defmodule MollieEx do
  @moduledoc """
  Top-level module for the `mollie_ex` Hex package.

  `mollie_ex` is a community driven Elixir SDK for the Mollie API. SDK modules
  use the `MollieEx.*` namespace.

  Start by building an explicit `MollieEx.Client`, then pass that client to
  resource modules such as `MollieEx.Payments`, `MollieEx.Refunds`, and
  `MollieEx.Captures`.

  Payment-scoped chargebacks are available through `MollieEx.Chargebacks`.
  Payment-scoped delayed routes are available through
  `MollieEx.PaymentRoutes`.
  Payment links are available through `MollieEx.PaymentLinks`.
  Customers are available through `MollieEx.Customers`.
  Payment methods, mandates, subscriptions, and profiles are available through
  `MollieEx.Methods`, `MollieEx.Mandates`, `MollieEx.Subscriptions`, and
  `MollieEx.Profiles`.
  OAuth permissions are available through `MollieEx.Permissions`.
  Organizations and partner status are available through
  `MollieEx.Organizations`.
  Onboarding status is available through `MollieEx.Onboarding`.
  Organization capabilities are available through `MollieEx.Capabilities`.
  Partner clients are available through `MollieEx.Clients`.
  Client links are available through `MollieEx.ClientLinks`.
  Balances, balance transactions, and balance reports are available through
  `MollieEx.Balances`.

  Full usage guides are available in the HexDocs sidebar:

  - [Getting started](guides/getting-started.md)
  - [Resources](guides/resources.md)
  """
  @moduledoc since: "0.1.0"
end
