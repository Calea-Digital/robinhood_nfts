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
- **the worker:** relaying openings, signing and serving claim tickets, and recording payouts;
- **holders' $MNTD** (DST): looking any bear up by its id (its amount and whether it is claimed, per
  round), a wallet's bears with something left to claim, the claim, and MINT's admin calls (loading a
  list, opening and closing a round, pause, withdrawal).

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
ticket signing); `BearDrop` (`amountOf`, `claimed`, `roundOf`, `roundCount`, `owed`, a wallet's
claimable bears in one Multicall3 call over its bear ids, `claim`, `setAmounts`, `openRound`,
`closeRound`, `setPaused`, `withdraw`, and `listHash` computed from a list). It documents the revert reasons a caller has to handle. The reference script
reproduces the split from `Activation.snapshot`, so that "allocations plus carried rounding equal
funding" is testable by MINT.

#### Scenario: Every call the app makes is covered
- **WHEN** MINT integrates the play page and the admin page
- **THEN** every contract call they make is covered by the typed TypeScript library, with passing tests and documented revert reasons, and the reference script reproduces the royalty split

## ADDED Requirements

### Requirement: DEL-13 — Holders' $MNTD claim as an extra
**Kind:** commercial
`BearDrop` (DST-1 to DST-6) is outside the statement of work and DEL-10's list. Calea builds it at MINT's
request of 29 October 2026, with its deployment, its list check and its calls in the client library, and
invoices it separately as an extra at a price agreed with MINT. It is live on Robinhood Chain by
15 November 2026. No external review is part of it (MINT, CQ-28), and running it afterwards is MINT's.

#### Scenario: The extra is agreed and invoiced on its own
- **WHEN** Calea invoices MINT for the work of November 2026
- **THEN** `BearDrop` appears as its own line, at the price agreed with MINT
