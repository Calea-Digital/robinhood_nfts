## MODIFIED Requirements

### Requirement: DEL-6 — Integration package
**Kind:** work-item
A TypeScript client library for getminted.io that covers every contract call the app makes. It is
typed and tested, and handles every error a caller must deal with, each with a message ready to
show holders:
- **the play page:** the mint's progress, read from the chain (holders mint on OpenSea's drop
  page, WL-4); burning; and the mystery box (opening, outcomes, odds, shots left, payouts);
- **MINT's admin page:** scheduling cycles on both chains, pauses;
- **the worker:** relaying openings and recording payouts.

MINT builds against a library that has already been exercised, not against raw contract
interfaces (`→ CQ-19`). It also includes a reference script that reproduces the royalty split,
dead-address exclusion included, so MINT can check its split adds up.

*Technical note.* Interfaces, events, roles and calldata examples for every contract. The library
is typed against the ABIs and covers: mint reads (the public stage, the allowlist root, a wallet's mint
stats); burn (`costToReach`, approve, `burn`); the mystery box (`open`, outcomes,
odds, shots left, payout records); the admin page (`scheduleCycle` on both
chains, pauses); the worker (`resolve`, `recordPayout`). It documents the revert reasons a caller
has to handle. The reference script reproduces the split from `Activation.snapshot`, so that
"allocations plus carried rounding equal funding" is testable by MINT.

#### Scenario: Every call the app makes is covered
- **WHEN** MINT integrates the play page and the admin page
- **THEN** every contract call they make is covered by the typed TypeScript library, with passing tests and documented revert reasons, and the reference script reproduces the royalty split
