# Proposal

## Why

`Activation` was made token-agnostic while it was open whether $MNTD would be native to Robinhood
Chain: a separate `DirectBurnAdapter` burned the holder's tokens and told `Activation` through one
owner-set `crediter`. MINT confirmed on 21 September 2026 that $MNTD is native to 4663 (CQ-2), which
removes the reason for the indirection and leaves its cost: an extra contract to deploy, verify
and audit, and an owner who can point `crediter` at an address of their own and record levels no
one burned for (tranche-1 review, MNT-26 finding L-1) — against the family's purpose, "in a way no
key can forge". The review also found the prose describing the burn before the record, the reverse
of the code (I-1), and `renounceOwnership` allowed while unpaused (I-2). Calea decided on
2026-09-24 to merge the burn into `Activation`; the interface MINT's portal uses keeps its shape
(approve once, then one `burn` call, the same reads).

## What Changes

- **BREAKING** (before any deployment): `DirectBurnAdapter` is removed. `Activation` takes $MNTD as
  an immutable constructor argument and burns the caller's own $MNTD in `burn(tokenId, amount)`,
  recording first and burning second in one non-reentrant call.
- `credit`, `crediter`, `setCrediter`, refs, `NotCrediter`, `StaleNonce`, `RefAlreadyUsed`,
  `CrediterSet` and `BurnedForBear` go. `burn` refuses, in order, `ContractPaused`, `ZeroAmount`,
  `NotBearOwner`, `AlreadyAtMaxLevel`, `Overshoot`.
- Thresholds are given to the constructor in whole $MNTD and scaled there by the token's
  `decimals`, exposed as `DECIMALS`.
- `renounceOwnership` reverts always.
- ACT-1, ACT-4 and ACT-7 are renamed to what they now describe.

## Capabilities

### Modified Capabilities

- `activation` (prefix `ACT`): ACT-1, ACT-2, ACT-4, ACT-6, ACT-7, ACT-8, ACT-11, ACT-12, ACT-13,
  ACT-14.
- `operations` (prefix `OPS`): OPS-1, OPS-2, OPS-4 — no adapter to deploy, wire or rehearse.
- `deliverables` (prefix `DEL`): DEL-8 — tranche 1 without the adapter.

## Impact

- `src/Activation.sol` rewritten around `burn`; `src/DirectBurnAdapter.sol` deleted.
- `test/Activation.t.sol` takes the adapter's tests (hostile tokens now meet `nonReentrant`);
  `test/DirectBurnAdapter.t.sol` and its tree deleted; ACT-12 pins one interface; INV-15 and
  INV-16 move to `Activation`'s tree; a regression in `test/poc/` for the removed `setCrediter`.
- `script/Deploy.s.sol` and its tests: `Activation(bears, mntd, thresholdsWhole, weights)`, no
  adapter, no `setCrediter`, no `mntdDecimals` in the config.
- `CLAUDE.md`, `README.md`, `docs/HANDOVER.md`, `docs/RUNBOOK.md`; `openspec/decisions.md`
  (CQ-2, CQ-3, CQ-12); `spec_version` 2.2.
- DEL-6's client: `burn` and `BearActivated` on `Activation`, approve `Activation` rather than an
  adapter.
