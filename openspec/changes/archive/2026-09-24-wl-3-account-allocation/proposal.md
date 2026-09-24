# Proposal

## Why

WL-1 grants allocations by the account's wagering: $50 unlocks allocation 1, $100 allocation 2.
WL-3's voucher carries an `allocationIndex` checked against the *wallet's* claims, so a voucher
for allocation 1 is valid for every wallet the holder selects: an account at $50 can obtain one
for each of two wallets and hold two of the 1,000 spots. The contract caps an account at two but
cannot tell whether the second was earned. The tranche-1 review (MNT-22, finding M-1) found it;
the reviewer chose on 2026-09-24 to bind the index to the account, so a signer that keeps no
state cannot over-issue. The same review found that the registry inherits `renounceOwnership`
(L-1) — after which a leaked signer key could never be rotated — and that WL-3 writes the voucher
type with spaces the contract's type string does not have (I-5).

## What Changes

- **BREAKING** (voucher format, before any deployment): `allocationIndex` is the account's
  allocation number — 1 for the $50 tier, 2 for the $100 tier — and must equal
  `accountClaims(account) + 1` (`WrongAllocation`). The per-wallet cap stays a separate check
  (`WalletLimit`). The check order becomes `NotClaimant`, `BadSigner`, `Expired`,
  `CampaignClosed`, `SoldOut`, `WalletLimit`, `AccountLimit`, `WrongAllocation`.
- The voucher type is quoted exactly as it is hashed.
- The owner list names Solady's ownership functions — one-step `transferOwnership` and the
  two-step handover — and `renounceOwnership` reverts for every caller.
- WL-3's Scenario gains the clause that a second voucher for the account's first allocation,
  for another wallet, reverts. Kind stays `work-item`.

## Capabilities

### Modified Capabilities

- `whitelist` (prefix `WL`): WL-3 — the voucher's index is the account's; renounce refused;
  exact type string.

## Impact

- `src/WhitelistClaim.sol`: the index check moves from the wallet's count to the account's, the
  two limit checks swap places, `renounceOwnership` reverts; NatSpec.
- `test/WhitelistClaim.t.sol`, `test/WhitelistExport.t.sol`, `test/WhitelistClaim.tree.md`: the
  vouchers follow the account's numbering; a regression in `test/poc/`.
- `CLAUDE.md`, `docs/HANDOVER.md`, `docs/RUNBOOK.md`; the portal team's signer (WL-2) signs the
  account's allocation number; DEL-6's client and its known-answer test.
- `docs/SPECIFICATION.md` (generated block) and the MNT WL-3 Task body follow on render and
  `board.sh`.
