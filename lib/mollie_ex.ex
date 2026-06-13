defmodule MollieEx do
  @moduledoc """
  Top-level module for the `mollie_ex` Hex package.

  `mollie_ex` is a community driven Elixir SDK for the Mollie API. SDK modules
  use the `MollieEx.*` namespace.

  Start by building an explicit `MollieEx.Client`, then pass that client to
  resource modules such as `MollieEx.Payments`, `MollieEx.Refunds`, and
  `MollieEx.Captures`.

  Payment-scoped chargebacks are available through `MollieEx.Chargebacks`.

  Full usage guides are available in the HexDocs sidebar:

  - [Getting started](guides/getting-started.md)
  - [Resources](guides/resources.md)
  """
  @moduledoc since: "0.1.0"
end
