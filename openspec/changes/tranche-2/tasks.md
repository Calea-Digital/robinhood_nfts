# Tasks

One line per requirement id, in pick order. `/mnt:next` takes the first unticked line whose Task
is Open and not hard-gated; `/mnt:done` ticks it. RAF-14 and RAF-18 stay last while CQ-23 is
open (and CQ-22, which gates RAF-18). RAF-33's payout record is built ahead of CQ-22 (change
`raf-33-record-ungated`), so RAF-17, RAF-19 and RAF-14 can quote it.

## 1. MysteryBox (Robinhood Chain)

- [x] 1.1 RAF-32 — cycles: `scheduleCycle(start, end, prizeCount, manifestHash)`, replaceable until `start`, `CycleInProgress`, `InvalidWindow`, `InvalidPrizeCount`, `CycleNotOpen`; owner in the constructor, two-step handover, `renounceOwnership` refused
- [x] 1.2 RAF-27 — playable ids: `excludeRange(from, to)`, `IdsExcluded`, `ExclusionFrozen`, `PLAYABLE` fixed at the first `scheduleCycle`
- [x] 1.3 RAF-28 — `open(tokenId)`: the RAF-28 Scenario test (`opened(cycleId, tokenId)` reads true; the buyer refused, then free next cycle); no per-wallet read on the hub (`ContractPaused` comes with RAF-34)

## 2. PrizeDraw (Arbitrum One)

- [x] 2.1 RAF-8 — one VRF v2.5 request and one word per open, `PrizeDraw` the subscription's consumer
- [x] 2.2 RAF-29 — `resolve(openIndex, cycleId, tokenId, opener)`: `OutOfOrder`, `UnknownCycle`, `InvalidTokenId`, `AlreadyResolved`, `CycleExhausted`, `DrawRequested`; outcomes applied in `openIndex` order; the draw's `scheduleCycle(cycleId, prizeCount, manifestHash)`
- [x] 2.3 RAF-30 — the win rule: `(w mod idsLeft) < prizesLeft`, both counters, `OutcomeRecorded`
- [x] 2.4 RAF-29 — (Defect MNT-157) `applyOutcomes` refuses with `InsufficientGas` when it stops for gas with fewer than `maxCount` applied and the next opening's word stored, so a wallet's gas estimate applies every ready outcome up to `maxCount`; a missing word or `maxCount` 0 returns 0; the callback and `resolve` still stop quietly (INV-28); INV-29 records the bound and the trade (a fixed gas limit with too large a `maxCount` makes no progress)

- [x] 2.5 RAF-33 — `recordPayout(openIndex, chainId, txHash)`: `NotAWin`, `AlreadyPaid`, `PrizePaid`, and the `payoutOf(openIndex)` read; assert `recordPayout` still works while the draw is paused (RAF-34's Scenario clause)

## 3. Both

- [x] 3.1 RAF-34 — pause on both: the hub's `setPaused` blocks `open`, the draw's blocks `resolve` while words already requested are still applied; `PausedSet`; payout records and reads unaffected; `end` unmoved
- [x] 3.2 RAF-16 — events carry the documented arguments
- [x] 3.3 RAF-17 — every read answers; `odds(cycleId)`
- [ ] 3.4 RAF-19 — every acceptance case has a deterministic test
- [ ] 3.5 DEL-6 — the client's mystery-box calls: `open`, the reads, and a wallet's shots left counted from `ownerOf`, `isExcluded` and `opened` per bear in one Multicall3 call

## 4. Gated (CQ-23; RAF-18 also CQ-22)

- [ ] 4.1 RAF-14 — roles: the worker (`setWorker`, `WorkerSet`), non-owner and non-worker refusals
- [ ] 4.2 RAF-18 — the worker sequence, end to end on the testnets through two cycles
