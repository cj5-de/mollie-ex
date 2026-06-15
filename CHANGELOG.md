# Changelog

## Unreleased

### Added

- Add `MollieEx.Permissions.list/2` and `MollieEx.Permissions.get/3`.
- Add `MollieEx.Organizations.get/3`, `MollieEx.Organizations.current/2`,
  and `MollieEx.Organizations.partner_status/2`.
- Add `MollieEx.Onboarding.get/2`.

## 0.4.0 - 2026-06-14

### Added

- Add `MollieEx.Methods.list/2`, `MollieEx.Methods.all/2`, and
  `MollieEx.Methods.get/3`.
- Add `MollieEx.Mandates.create/4`, `MollieEx.Mandates.get/4`,
  `MollieEx.Mandates.list/3`, and `MollieEx.Mandates.revoke/4`.
- Add `MollieEx.Subscriptions.create/4`, `MollieEx.Subscriptions.get/4`,
  `MollieEx.Subscriptions.list/3`, `MollieEx.Subscriptions.all/2`,
  `MollieEx.Subscriptions.update/5`, `MollieEx.Subscriptions.cancel/4`, and
  `MollieEx.Subscriptions.list_payments/4`.
- Add `MollieEx.Profiles.create/3`, `MollieEx.Profiles.list/2`,
  `MollieEx.Profiles.get/3`, `MollieEx.Profiles.current/2`,
  `MollieEx.Profiles.update/4`, and `MollieEx.Profiles.delete/3`.

## 0.3.0 - 2026-06-14

### Added

- Add top-level `MollieEx.Refunds.all/2` and
  `MollieEx.Chargebacks.all/2` list endpoints.
- Add `MollieEx.PaymentRoutes.update_release_date/5`.
- Add `MollieEx.PaymentLinks.list_payments/3`,
  `MollieEx.PaymentLinks.update/4`, and `MollieEx.PaymentLinks.delete/3`.
- Add `MollieEx.Customers.create_payment/4` and
  `MollieEx.Customers.list_payments/3`.

## 0.2.0 - 2026-06-13

### Added

- Add payment-scoped `MollieEx.Chargebacks.get/4` and
  `MollieEx.Chargebacks.list/3`.
- Add payment-scoped `MollieEx.PaymentRoutes.create/4`,
  `MollieEx.PaymentRoutes.get/4`, and `MollieEx.PaymentRoutes.list/3`.
- Add `MollieEx.PaymentLinks.create/3`, `MollieEx.PaymentLinks.get/3`, and
  `MollieEx.PaymentLinks.list/2`.
- Add `MollieEx.Customers.create/3`, `MollieEx.Customers.get/3`,
  `MollieEx.Customers.list/2`, `MollieEx.Customers.update/4`, and
  `MollieEx.Customers.delete/3`.

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
