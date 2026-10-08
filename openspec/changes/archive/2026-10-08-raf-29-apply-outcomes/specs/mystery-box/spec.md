# Spec Delta

## MODIFIED Requirements

### Requirement: RAF-29 — Resolution, in order
**Kind:** work-item
The worker carries each opening to the draw on Arbitrum One, which decides openings strictly in
the order they were made. It refuses one out of turn, so the worker can't choose which opening
meets which state of the prize pool. It can only delay one, and a delay is visible. Each opening
gets its own random number. Several can be in flight at once, but results are applied in order.
Each relay names the bear that opened, so every result can be matched to its opening on Robinhood
Chain, and the draw refuses a bear relayed twice in one cycle and a relay once a cycle's bears are
all relayed. The worker relays an opening once Robinhood Chain's sequencer has confirmed it. A
random number is never lost to a failed delivery: the draw stores each number as it arrives, and
anyone can apply the stored numbers in order, so a cycle's last results are recorded even when no
further opening follows.

*Technical note.* `resolve(uint64 openIndex, uint64 cycleId, uint256 tokenId, address opener)` on
`PrizeDraw`, relayed from `BoxOpened`. It refuses any `openIndex` but the next unresolved one
(`OutOfOrder`); a cycle it has not been given or one earlier than the last it resolved
(`UnknownCycle`); a `tokenId` outside 1 to `MAX_BEARS` (`InvalidTokenId`); a `tokenId` already
resolved in that cycle (`AlreadyResolved`); and any resolve once the cycle has accepted
`PLAYABLE` relays (`CycleExhausted`). It requests one Chainlink word and emits
`DrawRequested(openIndex, requestId)`. The VRF callback stores the word for its `openIndex` and
never reverts for a request the draw made; outcomes are applied in `openIndex` order, so an open
waits only on the words of the opens before it. The callback and `resolve` each apply pending
outcomes within a fixed budget, and `applyOutcomes(maxCount)`, open to anyone, applies up to
`maxCount` more; none of them can change an outcome, only when it is recorded. A delayed open
shows as a `BoxOpened` with no `OutcomeRecorded`; a relayed open that matches no `BoxOpened` on
4663 is visible the same way. An open made before its cycle's `end` is resolved even if the word
arrives after it.

#### Scenario: Relays are accepted only in order
- **GIVEN** opens 1 and 2 recorded and neither resolved
- **WHEN** the worker calls `resolve(2, cycleId, tokenId, opener)`
- **THEN** it reverts with `OutOfOrder`
- **AND** `resolve(1, cycleId, tokenId, opener)` requests one Chainlink word and emits `DrawRequested`

### Requirement: RAF-14 — Roles
**Kind:** work-item
**MINT's admin** records the team bears, schedules cycles, sets the worker and pauses either
contract. Ownership can't be given up. **The worker** carries openings to the draw and records
payouts (who runs it `→ CQ-23`). **Anyone** can open a box with a bear they hold, apply outcomes
whose random numbers have arrived, and read everything. No role can open a box for a holder,
change an outcome or move a bear.

*Technical note.* Owner: on `MysteryBox` `excludeRange`, `scheduleCycle`, `setPaused`; on
`PrizeDraw` `scheduleCycle`, `setWorker`, `setPaused`; ownership transfer on both;
`renounceOwnership` reverts on both. Worker: `resolve` and `recordPayout` on `PrizeDraw`.
Anyone: `open` on `MysteryBox`, `applyOutcomes` on `PrizeDraw`. The VRF coordinator alone
delivers words.

#### Scenario: Roles hold
- **WHEN** a non-owner calls `excludeRange`, `scheduleCycle` or `setWorker`, or a non-worker calls `resolve` or `recordPayout`
- **THEN** each reverts
- **AND** `open` needs no role but the bear's ownership

### Requirement: RAF-17 — Reads
**Kind:** work-item
The page can read for free: the playable count, whether a bear is excluded or already opened this
cycle, the current cycle and its terms, the longest a cycle may last, the live odds, and each
opening's bear, outcome and payout. A wallet's shots left come from these reads, one per bear
(RAF-28).

*Technical note.* Hub: `MAX_BEARS`, `PLAYABLE`, `EXPECTED_PLAYABLE`, `MAX_CYCLE_LENGTH`,
`isExcluded(tokenId)`, `currentCycle()` and each cycle's `(start, end, prizeCount, manifestHash)`,
`isOpen()`, `opened(cycleId, tokenId)`, `openCount()`. `PrizeDraw`: `PLAYABLE`, each cycle's
`(prizeCount, manifestHash, idsLeft, prizesLeft)`, `nextToResolve()`, `nextToApply()`,
`outcomeOf(openIndex)` with its `tokenId`, `payoutOf(openIndex)`, and `odds(cycleId)` returning
`(prizesLeft, idsLeft)`. Each read costs a fixed amount, whatever the number of bears.

#### Scenario: Every read answers
- **WHEN** every listed read is called during an open cycle
- **THEN** each returns without reverting and `odds(cycleId)` returns `(prizesLeft, idsLeft)`
