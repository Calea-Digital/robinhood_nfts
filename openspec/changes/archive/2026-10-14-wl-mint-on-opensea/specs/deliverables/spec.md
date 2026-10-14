## MODIFIED Requirements

### Requirement: DEL-6 — Integration package
**Kind:** work-item
A TypeScript client library for getminted.io that covers every contract call the app makes. It is
typed and tested, and handles every error a caller must deal with, each with a message ready to
show holders:
- **the play page:** the mint's progress, read from the chain (holders mint on OpenSea's drop
  page, WL-4); burning; and the mystery box (opening, outcomes, odds, shots left, payouts);
- **MINT's admin page:** excluding the team bears, scheduling cycles on both chains, pauses;
- **the worker:** relaying openings and recording payouts.

MINT builds against a library that has already been exercised, not against raw contract
interfaces (`→ CQ-19`). It also includes a reference script that reproduces the royalty split,
dead-address exclusion included, so MINT can check its split adds up.

*Technical note.* Interfaces, events, roles and calldata examples for every contract. The library
is typed against the ABIs and covers: mint reads (the public stage, the allowlist root, a wallet's mint
stats); burn (`costToReach`, approve, `burn`); the mystery box (`open`, outcomes,
odds, shots left, payout records); the admin page (`excludeRange`, `scheduleCycle` on both
chains, pauses); the worker (`resolve`, `recordPayout`). It documents the revert reasons a caller
has to handle. The reference script reproduces the split from `Activation.snapshot`, so that
"allocations plus carried rounding equal funding" is testable by MINT.

#### Scenario: Every call the app makes is covered
- **WHEN** MINT integrates the play page and the admin page
- **THEN** every contract call they make is covered by the typed TypeScript library, with passing tests and documented revert reasons, and the reference script reproduces the royalty split

### Requirement: DEL-8 — Audit tranches
**Kind:** informative
Tranche 1 is the collection and Activation. Tranche 2 is the mystery box and the draw, once the
team-bear ids arrive (O1). The whitelist has no contract, so none of it is audited (WL-8). Iñigo
accepts each tranche after Calea and MINT sign off, and anything not accepted stays switched off
in the page.

*Technical note.* Tranche 1: `MintABear` and `Activation`. Tranche 2: `MysteryBox` and
`PrizeDraw`, once CQ-20's remaining values are supplied.

#### Scenario: Tranche membership is fixed
- **WHEN** a contract's audit tranche is looked up
- **THEN** it is tranche 1 for `MintABear` and `Activation`, tranche 2 for `MysteryBox` and `PrizeDraw`

### Requirement: DEL-10 — Commercial items for Rayco's agreement
**Kind:** commercial
Listed so nothing is implied:
- prize logic, the cycles and the win rule;
- weight interfaces;
- Studio and frontend assistance;
- mainnet execution and handover on every chain;
- technical support through 19 November with agreed response hours;
- beyond the statement of work's single-chain design:
  - **whitelist support**: the check and a review of the claim rules (WL-4,
    WL-8);
  - the **cross-chain draw**: the draw on Arbitrum, relaying each opening, and the payout
    record;
  - the admin-page calls in the client library.

Two items are priced only if MINT confirms them:
- **running the worker** after 19 November, if Calea runs it (O4, `→ CQ-23`);
- **holding and invoicing the randomness subscription**, if MINT doesn't (O3, `→ CQ-17`).

#### Scenario: Every item is in the agreement
- **WHEN** Rayco's agreement is drawn up
- **THEN** each listed item appears in it
