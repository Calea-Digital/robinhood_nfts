# Spec Delta

## MODIFIED Requirements

### Requirement: RAF-27 — Playable ids and the prize pool
**Kind:** work-item
A cycle's odds depend on two numbers: how many bears can play and how many prizes it has. MINT's
222 team bears are excluded (which ids `→ CQ-20`). The exclusion is recorded once, before the
first cycle, and never changes. The box is told at deployment how many bears will play, and the
first cycle can't be scheduled until the exclusions leave exactly that many, so a missed or
mistyped range is caught before anything is fixed. An excluded bear stays out whoever holds it,
so a sold team bear stays out. That leaves 4,222 playable bears. Before each cycle MINT publishes
its prize list: each prize's chain, token and id or amount, in order. The n-th prize won in a
cycle is entry n of the list. Only the count and the list's fingerprint are on-chain. The prizes
are in MINT's prize wallet (RAF-33), so the list is MINT's commitment.

*Technical note.* `MysteryBox(owner, bears, expectedPlayable)` takes the expected playable count,
4,222, the same deploy value `PrizeDraw` takes as `PLAYABLE`; it is refused unless from 1 to
`MAX_BEARS`. The owner records exclusions as ranges with `excludeRange(from, to)` (event
`IdsExcluded`), allowed only until the first cycle is scheduled and frozen after it
(`ExclusionFrozen`). `PLAYABLE = MAX_BEARS − excluded`; the first `scheduleCycle` is refused unless
it equals `EXPECTED_PLAYABLE` (`ExclusionsIncomplete(have, want)`), and from then on `PLAYABLE` is
fixed. The prize list's hash is the cycle's `manifestHash` (RAF-32); the contracts cannot check
it against a balance.

#### Scenario: Opening freezes the odds
- **GIVEN** ranges excluded totalling 222 ids
- **WHEN** the owner schedules the first cycle
- **THEN** `PLAYABLE` reads 4,222 and `excludeRange` reverts with `ExclusionFrozen`

### Requirement: RAF-17 — Reads
**Kind:** work-item
The page can read for free: the playable count, whether a bear is excluded or already opened this
cycle, the current cycle and its terms, the longest a cycle may last, the live odds, and each
opening's bear, outcome and payout. A wallet's shots left come from these reads, one per bear
(RAF-28).

*Technical note.* Hub: `MAX_BEARS`, `PLAYABLE`, `EXPECTED_PLAYABLE`, `MAX_CYCLE_LENGTH`,
`isExcluded(tokenId)`, `currentCycle()` and each cycle's `(start, end, prizeCount, manifestHash)`,
`isOpen()`, `opened(cycleId, tokenId)`, `openCount()`. `PrizeDraw`: `PLAYABLE`, each cycle's
`(prizeCount, manifestHash, idsLeft, prizesLeft)`, `nextToResolve()`, `outcomeOf(openIndex)` with
its `tokenId`, `payoutOf(openIndex)`, and `odds(cycleId)` returning `(prizesLeft, idsLeft)`. Each
read costs a fixed amount, whatever the number of bears.

#### Scenario: Every read answers
- **WHEN** every listed read is called during an open cycle
- **THEN** each returns without reverting and `odds(cycleId)` returns `(prizesLeft, idsLeft)`
