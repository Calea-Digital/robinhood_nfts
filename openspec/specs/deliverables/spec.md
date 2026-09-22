# Deliverables and acceptance Specification

## Purpose
The engagement needs each deliverable and the bar it is accepted against written down — so that both parties can tell when the work is done and what remains.

## Requirements

### Requirement: DEL-1 — Source
**Kind:** acceptance-standard
Warning-free `forge build`; Slither with no High or Critical finding, every
accepted Medium documented.

#### Scenario: The build is clean
- **WHEN** `forge build` and Slither run on the delivered source
- **THEN** the build carries no warning and Slither reports no High or Critical finding, every accepted Medium documented

### Requirement: DEL-2 — Tests
**Kind:** acceptance-standard
Deterministic unit and integration tests with a branching tree per contract;
at least 90% line coverage.

#### Scenario: Coverage holds
- **WHEN** `forge coverage` runs
- **THEN** line coverage reads at least 90% and every contract has a branching tree

### Requirement: DEL-3 — Review report
**Kind:** work-item
Static and manual review, plus fuzzing and invariant harnesses, written
and run by Calea's internal auditor independently of the developer; report delivered with each
tranche.

#### Scenario: The report travels with the tranche
- **WHEN** a tranche is delivered
- **THEN** the internal auditor's report, with the fuzzing and invariant results, is delivered with it

### Requirement: DEL-6 — Integration package
**Kind:** work-item
Interfaces, events, roles and calldata examples for every
contract; a **TypeScript** client library for getminted.io, typed against the ABIs and covering
every call the app makes — mint (SeaDrop stages, allowlist proofs, `mintPublic`), whitelist claim
(voucher check and `claim`), burn (`costToReach`, approve, `burn`), link, and the mystery box (open
and prize claims on each chain) — together with its own tests and the revert reasons a caller has
to handle, so that MINT integrates against a library that has been exercised rather than against an
ABI (`→ CQ-19`); a reference script that reproduces the royalty split from `Activation.snapshot`,
dead-address exclusion included, so that "allocations plus carried rounding equal funding" is
testable by MINT.

#### Scenario: Every call the app makes is covered
- **WHEN** MINT integrates the play page
- **THEN** every contract call it makes is covered by the typed TypeScript library, with passing tests and documented revert reasons, and the reference script reproduces the royalty split

### Requirement: DEL-7 — Existing-contract review
**Kind:** work-item
A read of the contract MINT names, within the agreed line
limit; findings only, no remediation. Unscheduled: no contract has been named, so it books no
time until one is (`→ CQ-13`).

#### Scenario: Findings only
- **GIVEN** MINT has named a contract within the line limit
- **WHEN** the review is delivered
- **THEN** it lists findings only, with no remediation

### Requirement: DEL-8 — Audit tranches
**Kind:** informative
Tranche 1: `MintABear`, `WhitelistClaim`, `Activation` and
`DirectBurnAdapter`. Tranche 2: `MysteryBox`, `PrizeVault` and `PrizeDraw`, once CQ-9's remaining
questions and CQ-20 are answered. Iñigo accepts after Calea and MINT sign off; anything not
accepted stays disabled in the UI.

#### Scenario: Tranche membership is fixed
- **WHEN** a contract's audit tranche is looked up
- **THEN** it is tranche 1 for `MintABear`, `WhitelistClaim`, `Activation` and `DirectBurnAdapter`, and tranche 2 for `MysteryBox`, `PrizeVault` and `PrizeDraw`

### Requirement: DEL-9 — Repository
**Kind:** work-item
The contracts live in MINT's monorepo (`github.com/mintdotio/NFT`) as
`packages/contracts` (`@mint/contracts`), a Foundry package with a thin `package.json` so
`pnpm -r build|test|check` reach it, with the Foundry dependencies as git submodules that CI
checks out; CI runs `forge fmt --check`, `forge build --sizes`, `forge test`, and Calea owns
that configuration. This is Calea's recommendation and what it builds if the decision is
deferred (`→ CQ-14`, `→ CQ-19`).

#### Scenario: The package sits in the monorepo
- **WHEN** the contracts land in the monorepo
- **THEN** `pnpm -r build|test|check` reach the Foundry package and CI runs the three forge gates

### Requirement: DEL-10 — Commercial items for Rayco's agreement
**Kind:** commercial
Listed here so nothing is implied: prize
intake and unique-winner logic; weight interfaces; Studio and frontend assistance; mainnet
execution and role handover on every chain; technical support through 19 November with agreed
response hours; the existing-contract review; and two items beyond the SoW's single-chain vault
and collection: the **whitelist registry** (WL) and **multi-chain prize delivery** (a vault per
prize chain, the seed relay, the recipient nomination).

#### Scenario: Every item is in the agreement
- **WHEN** Rayco's agreement is drawn up
- **THEN** each listed item appears in it

### Requirement: DEL-11 — Frontend collaboration
**Kind:** commercial
MINT builds and owns the page holders play on — mint, raffle,
burn and level-up — in TypeScript, served from **getminted.io** (MINT, CQ-19). Calea owns the
Solidity and the TypeScript client library of DEL-6, and reviews every change that touches a
contract call before it merges. The Framer landing page stays where it is and is neither built
nor reviewed by Calea. Which repository holds these packages is `→ CQ-14`.

#### Scenario: Contract-touching changes are reviewed
- **WHEN** a change that touches a contract call is merged on getminted.io
- **THEN** Calea has reviewed it first

### Requirement: DEL-12 — Review sign-off
**Kind:** acceptance-standard
Every Critical and High finding from DEL-3's review is fixed before
mainnet deployment.

#### Scenario: Nothing Critical or High reaches mainnet
- **WHEN** mainnet deployment is scheduled
- **THEN** every Critical and High finding from the review report reads fixed

## Retired Requirements

- DEL-4 (verified testnet addresses) → OPS-3, OPS-4
- DEL-5 (deployment scripts and runbook) → OPS-2, OPS-5
