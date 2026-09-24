# Spec Delta

## MODIFIED Requirements

### Requirement: WL-3 — Registry
**Kind:** work-item
`WhitelistClaim` on Robinhood Chain (`→ CQ-18`; WL-6 is the alternative). A
voucher is the EIP-712 message whose type is exactly
`Claim(address wallet,uint8 allocationIndex,bytes32 account,uint256 deadline)`, signed by the
eligibility signer, with a short `deadline` (minutes), `account` a hash of the getminted.io
account id, so the chain carries no personal data, and `allocationIndex` the account's
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
signer can always be rotated. Nobody can remove or reassign a claim.

#### Scenario: A valid voucher claims a spot
- **GIVEN** a voucher signed by the signer for wallet W, allocation 1, within its deadline and the campaign window
- **WHEN** W calls `claim`
- **THEN** `spotsLeft` falls by one, `claimsOf(W)` reads 1 and `WhitelistClaimed` is emitted
- **AND** the same call from another wallet reverts with `NotClaimant`, and a voucher for the same account's allocation 1 for another wallet reverts with `WrongAllocation`
