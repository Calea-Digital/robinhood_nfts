# Spec Delta

## MODIFIED Requirements

### Requirement: WL-4 — Into the mint
**Kind:** work-item
After the window closes or the spots sell out, MINT exports the claimant
list — one row per wallet with its allocation count — and loads it as the whitelist stage's
allowlist in Studio. SeaDrop allowlist entries carry a per-wallet mint limit, so "one or two" is
enforced by the mint itself. That limit counts every bear minted to the wallet in any stage, so
the whitelist stage is the first in which any wallet but the team's can mint and no other stage
overlaps it; a later stage's per-wallet limit counts the whitelist mints too. The getminted.io mirror builds its Merkle proofs from the same list
(DEL-6). The registry is public, so a loaded list that differs from it is detectable by anyone.

#### Scenario: The export is the allowlist
- **GIVEN** a closed campaign
- **WHEN** `claimants(offset, limit)` is read across the whole list
- **THEN** every wallet appears once with its allocation count, and the Studio allowlist loaded from it carries the same rows
