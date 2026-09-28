# Spec Delta

## MODIFIED Requirements

### Requirement: COL-11 — What Studio owns
**Kind:** informative
Mint stages, dates and pricing; allowlists and per-wallet limits,
including the whitelist stage loaded from MINT's final CSV (WL-4); payout address; `maxSupply`
(COL-2); `baseURI` and provenance (COL-5); royalty info (COL-6); `multiConfigure`. A
"guaranteed" stage is guaranteed by stage sequencing — the guaranteed window must close before
the next window opens — not by the contract.

#### Scenario: Studio settings involve no Calea code
- **WHEN** a stage, allowlist, `maxSupply`, `baseURI`, provenance or royalty setting changes
- **THEN** it changes in OpenSea Studio through the inherited SeaDrop surface, with no Calea contract code involved
