# Tasks

One line per requirement id, in pick order (from `docs/HANDOVER.md`, "What is left"). `/mnt:next`
takes the first unticked line; `/mnt:done` ticks it. A line without an id is non-spec work and
becomes a Task with Spec Ref `NONE` when picked.

## 1. MintABear — take `main` to the specification

- [x] 1.1 COL-9 — remove ERC-6551: `BearAccount`, `accountOf`, `deployAccount`, `recordAccounts`, `isBearAccount`, `TransferToBearAccount`, the PoC and tests that depend on them
- [x] 1.2 COL-5 — remove the renderer: `IBearRenderer`, `PlaceholderRenderer`, `setRenderer`, the `tokenURI` override, their tests and mock; metadata is stock `baseURI`
- [x] 1.3 COL-8 — burn refused (`BurnDisabled` stays; dead-address exclusion lives in the split script, not the contract)
- [x] 1.4 COL-4 — emit `TransferNonceAdvanced(tokenId, nonce)` in the transfer hook
- [x] 1.5 COL-12 — `exists(tokenId)` view; every listed read answers
- [x] 1.6 COL-13 — events carry the documented arguments
- [x] 1.7 COL-1 — only canonical SeaDrop mints
- [x] 1.8 COL-2 — `MAX_BEARS` on the mint path
- [x] 1.9 COL-3 — transfer counter
- [x] 1.10 COL-6 — royalty info reads 5% to the pot
- [x] 1.11 COL-7 — creator token, validator set at deploy
- [x] 1.12 COL-10 — two-step ownership to MINT's admin

## 2. WhitelistClaim — live before the campaign

- [x] 2.1 WL-3 — the registry: EIP-712 voucher, `claim`, reverts, reads, owner functions
- [x] 2.2 WL-1 — two per wallet, two per account, allocations in order
- [x] 2.3 WL-4 — `claimants(offset, limit)` export equals the Studio allowlist
- [x] 2.4 WL-5 — window gates claims; close ≥ 48 h before the stage

## 3. Activation and DirectBurnAdapter

- [x] 3.1 ACT-1 — token-agnostic `Activation`
- [x] 3.2 ACT-2 — cumulative thresholds, `thresholdFor`, `costToReach`
- [ ] 3.3 ACT-3 — weights, `weightFor`, `weightOf`
- [ ] 3.4 ACT-4 — `credit` with `NotCrediter`, `ContractPaused`, `ZeroAmount`, `NotBearOwner`, `StaleNonce`, `RefAlreadyUsed`; `BearActivated`
- [ ] 3.5 ACT-5 — reset by counter
- [ ] 3.6 ACT-6 — `lifetimeBurned`
- [ ] 3.7 ACT-7 — `DirectBurnAdapter.burn`: `NotOwner`, `AlreadyAtMaxLevel`, `Overshoot`, `burnFrom` + `credit`, `BurnedForBear`
- [ ] 3.8 ACT-8 — overshoot refused
- [ ] 3.9 ACT-9 — Status link
- [ ] 3.10 ACT-10 — `snapshot(ids)`
- [ ] 3.11 ACT-11 — pause semantics, `renounceOwnership` refused while paused
- [ ] 3.12 ACT-12 — roles
- [ ] 3.13 ACT-13 — events
- [ ] 3.14 ACT-14 — reads

## 4. Scripts, runbook material, rehearsal

- [ ] 4.1 OPS-2 — deploy scripts in the specified order, constructor arguments, `setCrediter`, `setPaused(true)`
- [ ] 4.2 OPS-3 — Sourcify verification for 4663 and 46630
- [ ] 4.3 OPS-6 — enforcement toggle script and runbook section
- [ ] 4.4 OPS-4 — testnet rehearsal on 46630 (human-led; Claude prepares the scripts and records the results)

## 5. Non-spec work (Spec Ref `NONE`)

- [ ] 5.1 Rewrite `CLAUDE.md`'s architecture sections to the tranche-1 code
- [ ] 5.2 Rewrite `test/*.tree.md` against the requirement ids; keep INV-N obligations documented, unimplemented
- [ ] 5.3 Update `docs/HANDOVER.md` "Where things stand" at tranche end
