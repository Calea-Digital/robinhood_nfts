# Tasks

One line per requirement id, in pick order. `/mnt:next` takes the first unticked line whose Task
is Open and not hard-gated; `/mnt:done` ticks it. RAF-33, RAF-14 and RAF-18 stay last while
CQ-22 and CQ-23 are open.

## 1. MysteryBox (Robinhood Chain)

- [x] 1.1 RAF-32 — cycles: `scheduleCycle(start, end, prizeCount, manifestHash)`, replaceable until `start`, `CycleInProgress`, `InvalidWindow`, `InvalidPrizeCount`, `CycleNotOpen`; owner in the constructor, two-step handover, `renounceOwnership` refused
- [x] 1.2 RAF-27 — playable ids: `excludeRange(from, to)`, `IdsExcluded`, `ExclusionFrozen`, `PLAYABLE` fixed at the first `scheduleCycle`
- [x] 1.3 RAF-28 — `open(tokenId)`: the RAF-28 Scenario test (`opened(cycleId, tokenId)` reads true; the buyer refused, then free next cycle); no per-wallet read on the hub (`ContractPaused` comes with RAF-34)

## 2. PrizeDraw (Arbitrum One)

- [x] 2.1 RAF-8 — one VRF v2.5 request and one word per open, `PrizeDraw` the subscription's consumer
- [x] 2.2 RAF-29 — `resolve(openIndex, cycleId, tokenId, opener)`: `OutOfOrder`, `UnknownCycle`, `InvalidTokenId`, `AlreadyResolved`, `CycleExhausted`, `DrawRequested`; outcomes applied in `openIndex` order; the draw's `scheduleCycle(cycleId, prizeCount, manifestHash)`
- [x] 2.3 RAF-30 — the win rule: `(w mod idsLeft) < prizesLeft`, both counters, `OutcomeRecorded`

## 3. Both

- [x] 3.1 RAF-34 — pause on both: the hub's `setPaused` blocks `open`, the draw's blocks `resolve` while words already requested are still applied; `PausedSet`; payout records and reads unaffected; `end` unmoved
- [ ] 3.2 RAF-16 — events carry the documented arguments
- [ ] 3.3 RAF-17 — every read answers; `odds(cycleId)`
- [ ] 3.4 RAF-19 — every acceptance case has a deterministic test
- [ ] 3.5 DEL-6 — the client's mystery-box calls: `open`, the reads, and a wallet's shots left counted from `ownerOf`, `isExcluded` and `opened` per bear in one Multicall3 call

## 4. Gated (CQ-22, CQ-23)

- [ ] 4.1 RAF-33 — `recordPayout(openIndex, chainId, txHash)`: `NotAWin`, `AlreadyPaid`, `PrizePaid`; assert `recordPayout` still works while the draw is paused (RAF-34's Scenario clause)
- [ ] 4.2 RAF-14 — roles: the worker (`setWorker`, `WorkerSet`), non-owner and non-worker refusals
- [ ] 4.3 RAF-18 — the worker sequence, end to end on the testnets through two cycles
