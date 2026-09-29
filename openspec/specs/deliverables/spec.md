# Deliverables and acceptance Specification

## Purpose
Each deliverable and the standard it is accepted against, written down, so both parties can tell when the work is done and what remains.

## Requirements

### Requirement: DEL-1 — Source
**Kind:** acceptance-standard
The code compiles without warnings, and the automated security scan finds nothing High or
Critical. Every accepted Medium is documented.

*Technical note.* Warning-free `forge build`; Slither with no High or Critical finding.

#### Scenario: The build is clean
- **WHEN** `forge build` and Slither run on the delivered source
- **THEN** the build carries no warning and Slither reports no High or Critical finding, every accepted Medium documented

### Requirement: DEL-2 — Tests
**Kind:** acceptance-standard
Every contract has deterministic tests, organised by a written test tree, covering at least 90%
of lines.

*Technical note.* Deterministic unit and integration tests with a branching tree per contract
(`test/<Contract>.tree.md`); the coverage gate is at least 90% line and 80% branch.

#### Scenario: Coverage holds
- **WHEN** `forge coverage` runs
- **THEN** line coverage reads at least 90% and every contract has a branching tree

### Requirement: DEL-3 — Review report
**Kind:** work-item
Calea's internal auditor reviews each tranche independently of the developer, by hand and with
tools including fuzzing, and delivers a report with it.

*Technical note.* Static and manual review, plus fuzzing and invariant harnesses, written and run
by the internal auditor independently of the developer.

#### Scenario: The report travels with the tranche
- **WHEN** a tranche is delivered
- **THEN** the internal auditor's report, with the fuzzing and invariant results, is delivered with it

### Requirement: DEL-6 — Integration package
**Kind:** work-item
A TypeScript client library for getminted.io that covers every contract call the app makes. It is
typed and tested, and handles every error a caller must deal with, each with a message ready to
show holders:
- **the play page:** minting, with whitelist proofs from MINT's final list (WL-4); burning; and
  the mystery box (opening, outcomes, odds, shots left, payouts);
- **MINT's admin page:** excluding the team bears, scheduling cycles on both chains, pauses;
- **the worker:** relaying openings and recording payouts.

MINT builds against a library that has already been exercised, not against raw contract
interfaces (`→ CQ-19`). It also includes a reference script that reproduces the royalty split,
dead-address exclusion included, so MINT can check its split adds up.

*Technical note.* Interfaces, events, roles and calldata examples for every contract. The library
is typed against the ABIs and covers: mint (SeaDrop stages, allowlist proofs from the whitelist
CSV, `mintPublic`); burn (`costToReach`, approve, `burn`); the mystery box (`open`, outcomes,
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
team-bear ids arrive (O2). The whitelist has no contract, so none of it is audited (WL-8). Iñigo
accepts each tranche after Calea and MINT sign off, and anything not accepted stays switched off
in the page.

*Technical note.* Tranche 1: `MintABear` and `Activation`. Tranche 2: `MysteryBox` and
`PrizeDraw`, once CQ-20's remaining values are supplied. `WhitelistClaim` and `WhitelistImport`
are built but not deployed.

#### Scenario: Tranche membership is fixed
- **WHEN** a contract's audit tranche is looked up
- **THEN** it is tranche 1 for `MintABear` and `Activation`, tranche 2 for `MysteryBox` and `PrizeDraw`

### Requirement: DEL-9 — Repository
**Kind:** work-item
The contracts go into MINT's repository, `github.com/mintdotio/NFT`, as their own package beside
the client library. CI there builds, formats and tests them, and Calea owns that CI (MINT, 28 and
29 September 2026). The contracts go in as each tranche is accepted. The client library's mint
and whitelist calls, and the whitelist check (WL-4), are needed before the whitelist stage.

*Technical note.* `https://github.com/mintdotio/NFT`: `packages/contracts` (`@mint/contracts`)
beside `packages/contracts-client`. `packages/contracts` is a Foundry package with a thin
`package.json`, so `pnpm -r build|test|check` reach it, and its Foundry dependencies are git
submodules that CI checks out. CI runs `forge fmt --check`, `forge build --sizes` and
`forge test` (CQ-14).

#### Scenario: The package sits in the monorepo
- **WHEN** the contracts land in the monorepo
- **THEN** `pnpm -r build|test|check` reach the Foundry package and CI runs the three forge gates

### Requirement: DEL-10 — Commercial items for Rayco's agreement
**Kind:** commercial
Listed so nothing is implied:
- prize logic, the cycles and the win rule;
- weight interfaces;
- Studio and frontend assistance;
- mainnet execution and handover on every chain;
- technical support through 19 November with agreed response hours;
- beyond the statement of work's single-chain design:
  - **whitelist support**: the check, the mint proofs and a review of the claim rules (WL-4,
    WL-8);
  - the **cross-chain draw**: the draw on Arbitrum, relaying each opening, and the payout
    record;
  - the admin-page calls in the client library.

Two items are priced only if MINT confirms them:
- **running the worker** after 19 November, if Calea runs it (O5, `→ CQ-23`);
- **holding and invoicing the randomness subscription**, if MINT doesn't (O4, `→ CQ-17`).

#### Scenario: Every item is in the agreement
- **WHEN** Rayco's agreement is drawn up
- **THEN** each listed item appears in it

### Requirement: DEL-11 — Frontend collaboration
**Kind:** commercial
MINT builds and owns the page holders use to mint, open boxes, burn and level up, in TypeScript
on getminted.io (MINT, CQ-19). Calea owns the contracts and the client library (DEL-6), and
reviews every change that touches a contract call before it merges. The Framer landing page
stays as it is and is neither built nor reviewed by Calea. Everything lives in
`github.com/mintdotio/NFT` (CQ-14).

#### Scenario: Contract-touching changes are reviewed
- **WHEN** a change that touches a contract call is merged on getminted.io
- **THEN** Calea has reviewed it first

### Requirement: DEL-12 — Review sign-off
**Kind:** acceptance-standard
Every Critical and High finding from the internal audit (DEL-3) is fixed before the contract it
concerns goes to mainnet, for every contract in an audit tranche (DEL-8).

#### Scenario: Nothing Critical or High reaches mainnet
- **WHEN** mainnet deployment of an audited contract is scheduled
- **THEN** every Critical and High finding from the review report reads fixed

## Retired Requirements

- DEL-4 (verified testnet addresses) → OPS-3, OPS-4
- DEL-5 (deployment scripts and runbook) → OPS-2, OPS-5
- DEL-7 (the existing-contract review, withdrawn with CQ-13) → DEL-3
