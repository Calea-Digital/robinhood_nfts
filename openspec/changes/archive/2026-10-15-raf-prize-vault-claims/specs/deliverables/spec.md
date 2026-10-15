# Spec Delta

## MODIFIED Requirements

### Requirement: DEL-6 — Integration package
**Kind:** work-item
A TypeScript client library for getminted.io that covers every contract call the app makes. It is
typed and tested, and handles every error a caller must deal with, each with a message ready to
show holders:
- **the play page:** the mint's progress, read from the chain (holders mint on OpenSea's drop
  page, WL-4); burning; and the mystery box (opening, outcomes, odds, shots left, a winner's
  ticket and claim, payouts);
- **MINT's admin page:** setting up a cycle — sending each prize from the prize wallet to the
  vault on its chain, registering the prize list on every vault and scheduling the cycle on both
  game chains, all with one fingerprint computed from the list — then pauses, the vaults' signer,
  releases and withdrawals;
- **the worker:** relaying openings, signing and serving claim tickets, and recording payouts.

MINT builds against a library that has already been exercised, not against raw contract
interfaces (`→ CQ-19`). It also includes a reference script that reproduces the royalty split,
dead-address exclusion included, so MINT can check its split adds up.

*Technical note.* Interfaces, events, roles and calldata examples for every contract. The library
is typed against the ABIs and covers: mint reads (the public stage, the allowlist root, a wallet's mint
stats); burn (`costToReach`, approve, `burn`); the mystery box (`open`, outcomes,
odds, shots left, payout records); the prize vault (the funding transfer for each prize kind —
native, ERC-20 `transfer`, ERC-721 and ERC-1155 `safeTransferFrom` — from the prize wallet,
`manifestHash` computed as `keccak256(abi.encode(prizes))`, `registerCycle`, the ticket's EIP-712
typed data, `claim`, the vault's reads, `release`, `withdraw`, `setSigner`, pauses); the admin
page (`scheduleCycle` on both game chains, pauses); the worker (`resolve`, `recordPayout`,
ticket signing). It documents the revert reasons a caller has to handle. The reference script
reproduces the split from `Activation.snapshot`, so that "allocations plus carried rounding equal
funding" is testable by MINT.

#### Scenario: Every call the app makes is covered
- **WHEN** MINT integrates the play page and the admin page
- **THEN** every contract call they make is covered by the typed TypeScript library, with passing tests and documented revert reasons, and the reference script reproduces the royalty split

### Requirement: DEL-8 — Audit tranches
**Kind:** informative
Tranche 1 is the collection and Activation. Tranche 2 is the mystery box, the draw and the prize
vault. The whitelist has no contract, so none of it is audited (WL-8). Iñigo
accepts each tranche after Calea and MINT sign off, and anything not accepted stays switched off
in the page.

*Technical note.* Tranche 1: `MintABear` and `Activation`. Tranche 2: `MysteryBox`, `PrizeDraw`
and `PrizeVault`.

#### Scenario: Tranche membership is fixed
- **WHEN** a contract's audit tranche is looked up
- **THEN** it is tranche 1 for `MintABear` and `Activation`, tranche 2 for `MysteryBox`, `PrizeDraw` and `PrizeVault`
