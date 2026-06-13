# Changelog

## Unreleased

### Added

- Add payment-scoped `MollieEx.Chargebacks.get/4` and
  `MollieEx.Chargebacks.list/3`.
- Add payment-scoped `MollieEx.PaymentRoutes.create/4`,
  `MollieEx.PaymentRoutes.get/4`, and `MollieEx.PaymentRoutes.list/3`.
- Add `MollieEx.PaymentLinks.create/3`, `MollieEx.PaymentLinks.get/3`, and
  `MollieEx.PaymentLinks.list/2`.
- Add `MollieEx.Customers.create/3` and `MollieEx.Customers.get/3`.

### Changed

- Move detailed usage documentation from README into HexDocs guide and API
  documentation.

## 0.1.0 - 2026-06-12

### Added

- Add `MollieEx.Payments.create/3` and `MollieEx.Payments.get/3`.
- Add `MollieEx.Payments.list/2`, `MollieEx.Payments.update/4`,
  `MollieEx.Payments.cancel/3`, and
  `MollieEx.Payments.release_authorization/3`.
- Add `MollieEx.Refunds.create/4`, `MollieEx.Refunds.get/4`,
  `MollieEx.Refunds.list/3`, and `MollieEx.Refunds.cancel/4`.
- Add `MollieEx.Captures.create/4`, `MollieEx.Captures.get/4`, and
  `MollieEx.Captures.list/3`.
- Add decoded payment, money, and HAL link structs while preserving raw Mollie
  response payloads.
- Add decoded refund structs while preserving raw Mollie response payloads.
- Add decoded capture structs while preserving raw Mollie response payloads.
- Emit minimal safe request telemetry for transport success, API errors,
  decode failures, and rate-limit responses.
- Add HexDocs configuration for published API documentation.

## 0.0.1 - 2026-05-13

### Added

- Reserve the `mollie_ex` Hex package namespace.
- Add a placeholder `MollieEx` module.

### Notes

- This release does not include a usable Mollie SDK API yet.
