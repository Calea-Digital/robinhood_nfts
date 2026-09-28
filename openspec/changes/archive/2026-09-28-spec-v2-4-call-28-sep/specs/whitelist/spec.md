# Spec Delta

## MODIFIED Requirements

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
