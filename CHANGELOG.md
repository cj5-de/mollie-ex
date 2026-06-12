# Changelog

## Unreleased

### Added

- Add `MollieEx.Payments.create/3` and `MollieEx.Payments.get/3`.
- Add decoded payment, money, and HAL link structs while preserving raw Mollie
  response payloads.
- Emit minimal safe request telemetry for transport success, API errors,
  decode failures, and rate-limit responses.

## 0.0.1 - 2026-05-13

### Added

- Reserve the `mollie_ex` Hex package namespace.
- Add a placeholder `MollieEx` module.

### Notes

- This release does not include a usable Mollie SDK API yet.
