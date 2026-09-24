# Spec Delta

## MODIFIED Requirements

### Requirement: COL-10 — Ownership
**Kind:** work-item
Deployed by Calea; ownership transferred to MINT's admin address by the
inherited two-step process (`transferOwnership`, then `acceptOwnership` from the admin) before
the drop page is published. Calea retains no role. The collection always has an owner:
`renounceOwnership` reverts for every caller, the owner included, because an ownerless collection
would freeze every owner setting — Studio's drop configuration, `baseURI`, royalties and the
transfer-validator lift and restore (OPS-6) — and a pending ownership offer would survive it.

#### Scenario: Two-step transfer to MINT's admin
- **GIVEN** Calea has called `transferOwnership(admin)`
- **WHEN** the admin calls `acceptOwnership`
- **THEN** the admin is the owner
- **AND** Calea holds no role, and `renounceOwnership` reverts for the admin as for anyone else
