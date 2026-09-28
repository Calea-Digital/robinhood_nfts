# Spec Delta

## MODIFIED Requirements

### Requirement: DEL-6 — Integration package
**Kind:** work-item
Interfaces, events, roles and calldata examples for every contract. A **TypeScript** client
library for getminted.io, typed against the ABIs, that covers every call the app makes:
- **the play page:**
  - mint: SeaDrop stages, allowlist proofs built from MINT's whitelist CSV (WL-4), `mintPublic`;
  - burn: `costToReach`, approve, `burn`;
  - the mystery box: `open`, outcomes, odds, shots left and payout records;
- **MINT's admin page:**
  - `excludeRange`;
  - `scheduleCycle` on both chains;
  - pauses;
- **the worker:** `resolve` and `recordPayout`.

It comes with its own tests and the revert reasons a caller has to handle, so that MINT
integrates against a library that has been exercised rather than against an ABI (`→ CQ-19`).
Also a reference script that reproduces the royalty split from `Activation.snapshot`,
dead-address exclusion included, so that "allocations plus carried rounding equal funding" is
testable by MINT.

#### Scenario: Every call the app makes is covered
- **WHEN** MINT integrates the play page and the admin page
- **THEN** every contract call they make is covered by the typed TypeScript library, with passing tests and documented revert reasons, and the reference script reproduces the royalty split

### Requirement: DEL-8 — Audit tranches
**Kind:** informative
Tranche 1: `MintABear` and `Activation`. Tranche 2: `MysteryBox` and `PrizeDraw`, once CQ-20's
remaining values are supplied. The whitelist has no contract: it is MINT's off-chain register
(WL-8), and `WhitelistClaim` and `WhitelistImport` are not deployed. Iñigo accepts after Calea and
MINT sign off; anything not accepted stays disabled in the UI.

#### Scenario: Tranche membership is fixed
- **WHEN** a contract's audit tranche is looked up
- **THEN** it is tranche 1 for `MintABear` and `Activation`, tranche 2 for `MysteryBox` and `PrizeDraw`

### Requirement: DEL-9 — Repository
**Kind:** work-item
The contracts go into MINT's repository as `packages/contracts` (`@mint/contracts`), beside
`packages/contracts-client`. `packages/contracts` is a Foundry package with a thin
`package.json`, so `pnpm -r build|test|check` reach it, and its Foundry dependencies are git
submodules that CI checks out. CI runs `forge fmt --check`, `forge build --sizes` and
`forge test`, and Calea owns that configuration (MINT accepted, 28 September 2026). MINT names
the repository (`→ CQ-14`).

The contracts go in as their tranches are accepted. The client library's mint and allowlist-proof
calls, and the root check (WL-4), are needed before the whitelist stage.

#### Scenario: The package sits in the monorepo
- **WHEN** the contracts land in the monorepo
- **THEN** `pnpm -r build|test|check` reach the Foundry package and CI runs the three forge gates

### Requirement: DEL-10 — Commercial items for Rayco's agreement
**Kind:** commercial
Listed here so nothing is implied:
- prize logic and the unique-winner rule;
- weight interfaces;
- Studio and frontend assistance;
- mainnet execution and role handover on every chain;
- technical support through 19 November with agreed response hours;
- the existing-contract review;
- beyond the SoW's single-chain vault and collection:
  - **whitelist support**: the root check against MINT's CSV, the mint proofs and a review of the
    claim rules (WL-4, WL-8);
  - the **cross-chain draw**: the Chainlink draw on Arbitrum, the relay of each open, and the
    payout record;
  - the admin-page calls in the client library.

Two items are priced only if MINT confirms them:
- **operating the worker** after 19 November, if Calea runs it (`→ CQ-23`);
- **holding the VRF subscription** and invoicing it, if MINT does not (`→ CQ-17`).

#### Scenario: Every item is in the agreement
- **WHEN** Rayco's agreement is drawn up
- **THEN** each listed item appears in it
