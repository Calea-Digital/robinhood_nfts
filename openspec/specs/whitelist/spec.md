# Whitelist claim Specification

## Purpose
MINT needs a first-come-first-served whitelist of 1,000 allocations that only wagering holders can claim, recorded where anyone can check it — so that the allowlist loaded into Studio is provably the list the campaign produced.

## Requirements

### Requirement: WL-1 — Rules
**Kind:** work-item
From MINT's brief, as the contract enforces them:

- **1,000 spots**, each the right to mint one bear in the whitelist stage. A spot is an
  allocation: a wallet at $100 holds two of the 1,000 (`→ CQ-18` confirms this reading).
- **First come, first served** through getminted.io/mintabear. Reaching a threshold makes a
  wallet eligible; it reserves nothing. An allocation belongs to a wallet only once its claim
  transaction has succeeded.
- **$50 wagered unlocks allocation 1; $100 unlocks allocation 2.** Historical wagering (Season 1,
  back-credited) counts up to $50, so allocation 2 always requires at least $50 of in-campaign
  wagering. Who has wagered what is MINT's data (WL-2).
- **Live counter** "wagering spots left — X / 1,000", read from the contract. A claim that
  arrives after the last spot fails whole; there is no partial state.
- **The holder selects the NFT wallet** before claiming and may change it until the claim; the
  claim is made for that wallet. One call to action per unlocked allocation: a holder at $75
  claims one now and the second later.
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
the eligibility checker; the UI; and the **eligibility signer**, a backend key that signs a
voucher when the API confirms a threshold. Calea: the `WhitelistClaim` contract, the voucher
format, the export to the Studio allowlist, and the client calls (DEL-6).

#### Scenario: The division of work holds
- **WHEN** a step of the whitelist flow is traced
- **THEN** the login, wager API, eligibility checker, UI and signer are MINT's, and the contract, voucher format, export and client calls are Calea's

### Requirement: WL-3 — Registry
**Kind:** work-item
`WhitelistClaim` on Robinhood Chain (`→ CQ-18`; WL-6 is the alternative). A
voucher is an EIP-712 message `Claim(address wallet, uint8 allocationIndex, bytes32 account,
uint256 deadline)` signed by the eligibility signer, with a short `deadline` (minutes) and
`account` a hash of the getminted.io account id, so the chain carries no personal data.
`claim(voucher,
signature)` reverts unless: `msg.sender == wallet` (`NotClaimant`), the one condition D4 option
(A′) removes; the signature is the signer's (`BadSigner`); `block.timestamp ≤ deadline`
(`Expired`); the campaign window is open (`CampaignClosed`); `spotsLeft() > 0` (`SoldOut`);
`claimsOf(wallet) < MAX_PER_WALLET` (`WalletLimit`) and `allocationIndex == claimsOf(wallet) + 1`
(`WrongAllocation`), so a wallet claims its allocations in order and at most twice whatever the
voucher says; `accountClaims(account) < MAX_PER_ACCOUNT` (`AccountLimit`). Effects: the wallet's
and the account's counts increase, the spot counter increases, the wallet is appended to the
claimant list, and `WhitelistClaimed(wallet, allocationIndex, account, spotNumber)` is emitted. By
default the claim is sent by the wallet itself, which pays Robinhood Chain gas — it needs gas for
the mint anyway; in the relayed variant MINT's worker submits the voucher and pays, which is the
same contract without the `NotClaimant` condition (`→ CQ-18`). Reads: `TOTAL_SPOTS`,
`MAX_PER_WALLET`, `MAX_PER_ACCOUNT`, `spotsLeft()`, `claimsOf(wallet)`, `accountClaims(account)`,
`claimants(offset, limit) → (wallet, allocations)[]`, `openAt`, `closeAt`, `signer`. Owner (MINT
admin): `setSigner`, `setWindow(openAt, closeAt)`, ownership transfer. Nobody can remove or
reassign a claim.

#### Scenario: A valid voucher claims a spot
- **GIVEN** a voucher signed by the signer for wallet W, allocation 1, within its deadline and the campaign window
- **WHEN** W calls `claim`
- **THEN** `spotsLeft` falls by one, `claimsOf(W)` reads 1 and `WhitelistClaimed` is emitted
- **AND** the same call from another wallet reverts with `NotClaimant`

### Requirement: WL-4 — Into the mint
**Kind:** work-item
After the window closes or the spots sell out, MINT exports the claimant
list — one row per wallet with its allocation count — and loads it as the whitelist stage's
allowlist in Studio. SeaDrop allowlist entries carry a per-wallet mint limit, so "one or two" is
enforced by the mint itself. The getminted.io mirror builds its Merkle proofs from the same list
(DEL-6). The registry is public, so a loaded list that differs from it is detectable by anyone.

#### Scenario: The export is the allowlist
- **GIVEN** a closed campaign
- **WHEN** `claimants(offset, limit)` is read across the whole list
- **THEN** every wallet appears once with its allocation count, and the Studio allowlist loaded from it carries the same rows

### Requirement: WL-5 — Timing
**Kind:** work-item
The registry is deployed and its signer set before the campaign opens; the
campaign closes at least 48 hours before the whitelist stage opens, for the export, the Studio
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
