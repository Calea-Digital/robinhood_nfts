# Whitelist claim Specification

## Purpose
MINT needs a first-come-first-served whitelist of 1,000 allocations that only wagering holders can claim, recorded where anyone can check it — so that the allowlist loaded into Studio is provably the list the campaign produced.

## Requirements

### Requirement: WL-1 — Rules
**Kind:** work-item
From MINT's brief, as the contract enforces them:

- **1,000 spots**, each the right to mint one bear in the whitelist stage. A spot is an
  allocation: an account at $100 holds two of the 1,000 (`→ CQ-18` confirms this reading).
- **First come, first served** through getminted.io/mintabear. Reaching a threshold makes the
  getminted.io account eligible for the allocation it unlocks; it reserves nothing. An allocation
  belongs to a wallet only once its claim transaction has succeeded.
- **$50 wagered unlocks allocation 1; $100 unlocks allocation 2.** Historical wagering (Season 1,
  back-credited) counts up to $50, so allocation 2 always requires at least $50 of in-campaign
  wagering. Who has wagered what is MINT's data (WL-2); each allocation is the account's, claimed
  once, in order (WL-3).
- **Live counter** "wagering spots left — X / 1,000", read from the contract. A claim that
  arrives after the last spot fails whole; there is no partial state.
- **The holder selects the NFT wallet** before claiming and may change it until the claim; the
  claim puts the account's allocation in that wallet. One call to action per unlocked allocation:
  a holder at $75 claims one now and the second later.
- **Two per wallet, two per account.** A getminted.io account cannot spread more than two
  over several wallets.

#### Scenario: Two per wallet, two per account
- **GIVEN** a wallet holding one claimed allocation and an account holding one
- **WHEN** the wallet claims allocation 2 with a valid voucher
- **THEN** the claim succeeds and both counts read 2
- **AND** a third claim for either reverts

### Requirement: WL-2 — Division of work
**Kind:** informative
MINT: the Privy mirror login on getminted.io; the wager API that
returns, for the logged-in account, historical wagering capped at $50 and in-campaign wagering;
the eligibility checker; the UI; and either the **eligibility signer**, a backend key that signs
a voucher when the API confirms a threshold (WL-3), or the CSV of eligible wallets and its
import through the admin page (WL-7) (`→ CQ-18`). Calea: the `WhitelistClaim` and
`WhitelistImport` contracts, the voucher format, the export to the Studio allowlist, and the
client calls (DEL-6).

#### Scenario: The division of work holds
- **WHEN** a step of the whitelist flow is traced
- **THEN** the login, wager API, eligibility checker, UI and the signer or the CSV are MINT's, and the contracts, voucher format, export and client calls are Calea's

### Requirement: WL-3 — Registry
**Kind:** work-item
`WhitelistClaim` on Robinhood Chain, the voucher variant of the registry (`→ CQ-18`); WL-7 is
the owner-imported variant, MINT deploys one of the two, and WL-6 is the off-chain alternative. A
voucher is the EIP-712 message whose type is exactly
`Claim(address wallet,uint8 allocationIndex,bytes32 account,uint256 deadline)`, signed by the
eligibility signer, with a short `deadline` (minutes), `account` a keyed hash —
HMAC-SHA256 under a key held server-side — over a canonical form of the getminted.io account id
(an immutable user id, or an email case-folded and trimmed), so the chain carries no personal data
and the indexed `account` of `WhitelistClaimed` cannot be matched to a guessed id, and
`allocationIndex` the account's
allocation number — 1 for the allocation $50 unlocks, 2 for the one $100 unlocks (WL-1).
`claim(voucher,
signature)` reverts unless: `msg.sender == wallet` (`NotClaimant`), the one condition D4 option
(A′) removes; the signature is the signer's (`BadSigner`); `block.timestamp ≤ deadline`
(`Expired`); the campaign window is open (`CampaignClosed`); `spotsLeft() > 0` (`SoldOut`);
`claimsOf(wallet) < MAX_PER_WALLET` (`WalletLimit`); `accountClaims(account) < MAX_PER_ACCOUNT`
(`AccountLimit`); and `allocationIndex == accountClaims(account) + 1` (`WrongAllocation`), so an
account claims its allocations in order, each once, over whichever wallets it selects, and a
voucher is spent by its claim. Effects: the wallet's
and the account's counts increase, the spot counter increases, the wallet is appended to the
claimant list, and `WhitelistClaimed(wallet, allocationIndex, account, spotNumber)` is emitted. By
default the claim is sent by the wallet itself, which pays Robinhood Chain gas — it needs gas for
the mint anyway; in the relayed variant MINT's worker submits the voucher and pays, which is the
same contract without the `NotClaimant` condition (`→ CQ-18`). Reads: `TOTAL_SPOTS`,
`MAX_PER_WALLET`, `MAX_PER_ACCOUNT`, `spotsLeft()`, `claimsOf(wallet)`, `accountClaims(account)`,
`claimants(offset, limit) → (wallet, allocations)[]`, `openAt`, `closeAt`, `signer`. Owner (MINT
admin): `setSigner`, `setWindow(openAt, closeAt)`, and ownership transfer — one-step
`transferOwnership` or the two-step handover. `renounceOwnership` reverts for every caller, so the
signer can always be rotated. Nobody can remove or reassign a claim. The eligibility signer
is an externally owned key, since the registry recovers signatures with `ecrecover` alone and a
contract's vouchers revert `BadSigner`. It issues `allocationIndex` as
`accountClaims(account) + 1`, and only while `claimsOf(wallet) < MAX_PER_WALLET`. A key rotated
out by `setSigner` is never rotated back in, since its unexpired vouchers would be valid again.
DEL-6's backend reference pins these rules.

#### Scenario: A valid voucher claims a spot
- **GIVEN** a voucher signed by the signer for wallet W, allocation 1, within its deadline and the campaign window
- **WHEN** W calls `claim`
- **THEN** `spotsLeft` falls by one, `claimsOf(W)` reads 1 and `WhitelistClaimed` is emitted
- **AND** the same call from another wallet reverts with `NotClaimant`, and a voucher for the same account's allocation 1 for another wallet reverts with `WrongAllocation`

### Requirement: WL-4 — Into the mint
**Kind:** work-item
After the window closes or the spots sell out (WL-3), or once the imported list is frozen
(WL-7), MINT exports the claimant list — one row per wallet with its allocation count — and loads it as the whitelist stage's
allowlist in Studio. SeaDrop allowlist entries carry a per-wallet mint limit, so "one or two" is
enforced by the mint itself. That limit counts every bear minted to the wallet in any stage, so
the whitelist stage is the first in which any wallet but the team's can mint and no other stage
overlaps it; a later stage's per-wallet limit counts the whitelist mints too. The getminted.io mirror builds its Merkle proofs from the same list
(DEL-6). The registry is public, so a loaded list that differs from it is detectable by anyone.

#### Scenario: The export is the allowlist
- **GIVEN** a closed campaign
- **WHEN** `claimants(offset, limit)` is read across the whole list
- **THEN** every wallet appears once with its allocation count, and the Studio allowlist loaded from it carries the same rows

### Requirement: WL-5 — Timing
**Kind:** work-item
The registry is deployed before the campaign opens, with its signer for WL-3. The campaign, or
for WL-7 the import, closes at least 48 hours before the whitelist stage opens, for the export, the Studio
import and the publication of proofs. Dates `→ CQ-18`; calendar in §8.

#### Scenario: The window gates claims
- **GIVEN** `openAt` and `closeAt` set with the close at least 48 hours before the whitelist stage
- **WHEN** a claim arrives before `openAt` or after `closeAt`
- **THEN** it reverts with `CampaignClosed`

### Requirement: WL-6 — Alternative — off-chain register
**Kind:** informative
MINT's backend records claims in its database behind
an atomic counter; Calea supplies the claim-API contract and the Studio export script and deploys
nothing. Faster to build and free of gas for holders; the order of claims and the sell-out rest
on MINT's server, nothing is publicly checkable, and the SeaDrop allowlist root is the only trace
on-chain. `→ CQ-18`.

#### Scenario: The alternative is recorded, not built
- **WHEN** the whitelist design is reviewed
- **THEN** the off-chain register is recorded as the alternative D4 did not choose, and nothing in the build implements it

### Requirement: WL-7 — Owner-imported registry
**Kind:** work-item
`WhitelistImport` on Robinhood Chain is the variant of the registry for a whitelist MINT fills
itself from a CSV (`→ CQ-18`). WL-3 is the alternative, and MINT deploys one of the two.
Constructor: `WhitelistImport(owner, closeAt)`; the owner is MINT's admin. A zero owner is
refused (`NewOwnerIsZeroAddress`), and so is a close in the past (`InvalidWindow`). Until `closeAt` the owner can write the list:
- `addAllocations(address[] wallets, uint8[] counts)` gives each wallet `counts[i]` more
  allocations. The call is refused whole, with no partial state, on any of these:
  - after `closeAt` (`ListFrozen`);
  - arrays of different lengths (`LengthMismatch`);
  - a zero wallet (`ZeroWallet`);
  - a zero count (`ZeroCount`);
  - a wallet above `MAX_PER_WALLET` = 2 (`WalletLimit`);
  - a total above `TOTAL_SPOTS` = 1,000 (`SoldOut`).
- `removeAllocations(address[] wallets)` sets each wallet's allocations to zero and drops it from
  the list. After `closeAt` it is refused (`ListFrozen`); for a wallet with no allocations it is
  refused (`NotListed`).
- `setCloseAt(closeAt)` moves the freeze, so the owner can extend the import or freeze early.
  After `closeAt` it is refused (`ListFrozen`); a close in the past is refused (`InvalidWindow`).

Once `block.timestamp > closeAt` the list is frozen for good. Nothing can then add, remove or
reassign an allocation, and `claimsOf(wallet)` is the wallet's eligibility for the whitelist
stage.

Events:
- `AllocationsAdded(wallet, count, total)` for each wallet, where `total` is the wallet's
  allocations after the add, so an indexer can rebuild `claimsOf` from events alone;
- `AllocationsRemoved(wallet, count)`;
- `CloseSet(closeAt)`.

Reads, with the names `WhitelistClaim` uses so the export and the Studio compare (WL-4) read
either registry:
- `TOTAL_SPOTS`, `MAX_PER_WALLET`;
- `spotsLeft()`, `claimsOf(wallet)`;
- `claimants(offset, limit) → (wallet, allocations)[]`, each listed wallet once;
- `closeAt`, `frozen()`.

The export (WL-4) refuses a list that is not yet frozen (`CampaignStillOpen`), even when all
1,000 allocations are written, because it can still be corrected until `closeAt`.
`renounceOwnership` reverts for every caller. There is no voucher, no signer and no per-account
cap: who is eligible is MINT's alone to decide, and the chain records what the owner wrote and
when.

#### Scenario: The owner's import freezes at the close
- **GIVEN** a `WhitelistImport` whose `closeAt` has not passed
- **WHEN** the owner adds allocations for wallets A (2) and B (1), and `closeAt` then passes
- **THEN** `claimsOf(A)` reads 2, `claimsOf(B)` reads 1 and `spotsLeft` reads 997
- **AND** any later `addAllocations`, `removeAllocations` or `setCloseAt` reverts with `ListFrozen`
