# Spec Delta

## MODIFIED Requirements

### Requirement: RAF-17 — Reads
**Kind:** work-item
The page can read for free: the playable count, whether a bear is excluded or already opened this
cycle, the current cycle and its terms, the longest a cycle may last, the live odds, and each
opening's bear, outcome and payout. A wallet's shots left come from these reads, one per bear
(RAF-28).

*Technical note.* Hub: `MAX_BEARS`, `PLAYABLE`, `EXPECTED_PLAYABLE`, `MAX_CYCLE_LENGTH`,
`excludedCount`, `isExcluded(tokenId)`, `currentCycle()` and each cycle's
`(start, end, prizeCount, manifestHash)`, `isOpen()`, `opened(cycleId, tokenId)`, `openCount()`,
`paused()`, `BEARS`, `owner()` and `ownershipHandoverExpiresAt(pendingOwner)`. `PrizeDraw`:
`MAX_BEARS`, `PLAYABLE`, each cycle's `(prizeCount, manifestHash, idsLeft, prizesLeft)`,
`nextToResolve()`, `nextToApply()`, `lastCycleResolved()`, `outcomeOf(openIndex)` with its
`tokenId`, `payoutOf(openIndex)`, `odds(cycleId)` returning `(prizesLeft, idsLeft)`,
`openingOfRequest(requestId)` (0 for a request the draw never made), `RESOLVE_APPLY_LIMIT`,
`worker()`, `paused()`, the Chainlink configuration `COORDINATOR`, `KEY_HASH`, `SUBSCRIPTION_ID`,
`CALLBACK_GAS_LIMIT`, `REQUEST_CONFIRMATIONS` and `NATIVE_PAYMENT`, `owner()` and
`ownershipHandoverExpiresAt(pendingOwner)`. No other public read exists on either contract. Each
read costs a fixed amount, whatever the number of bears.

#### Scenario: Every read answers
- **WHEN** every listed read is called during an open cycle
- **THEN** each returns without reverting and `odds(cycleId)` returns `(prizesLeft, idsLeft)`

### Requirement: RAF-29 — Resolution, in order
**Kind:** work-item
The worker carries each opening to the draw on Arbitrum One, which decides openings strictly in
the order they were made. It refuses one out of turn, so the worker can't choose which opening
meets which state of the prize pool. It can only delay one, and a delay is visible. Each opening
gets its own random number. Several can be in flight at once, but results are applied in order.
Each relay names the bear that opened, so every result can be matched to its opening on Robinhood
Chain, and the draw refuses a bear relayed twice in one cycle, a relay with no opener, and a relay
once a cycle's bears are all relayed. The worker relays an opening once Robinhood Chain's
sequencer has confirmed it. A random number is never lost to a failed delivery: the draw stores
each number as it arrives, and anyone can apply the stored numbers in order, so a cycle's last
results are recorded even when no further opening follows.

*Technical note.* `resolve(uint64 openIndex, uint64 cycleId, uint256 tokenId, address opener)` on
`PrizeDraw`, relayed from `BoxOpened`. It refuses any `openIndex` but the next unresolved one
(`OutOfOrder`); a cycle it has not been given or one earlier than the last it resolved
(`UnknownCycle`); a `tokenId` outside 1 to `MAX_BEARS` (`InvalidTokenId`); a zero `opener`
(`InvalidOpener`); a `tokenId` already resolved in that cycle (`AlreadyResolved`); and any resolve
once the cycle has accepted `PLAYABLE` relays (`CycleExhausted`). It requests one Chainlink word
and emits `DrawRequested(openIndex, requestId)`. The VRF callback stores the word for its
`openIndex` and never reverts for a request the draw made; outcomes are applied in `openIndex`
order, so an open waits only on the words of the opens before it. The callback applies pending
outcomes within the gas it has, `resolve` applies at most `RESOLVE_APPLY_LIMIT` (16), and
`applyOutcomes(maxCount)`, open to anyone, applies up to `maxCount` more; none of them can change
an outcome, only when it is recorded. `applyOutcomes` reverts with `InsufficientGas` when it stops
for gas with fewer than `maxCount` applied and the next opening's word stored, so a wallet's gas
estimate applies every ready outcome up to `maxCount`; the callback and `resolve` stop quietly
instead. A delayed open shows as a `BoxOpened` with no `OutcomeRecorded`; a relayed open that
matches no `BoxOpened` on 4663 is visible the same way. An open made before its cycle's `end` is
resolved even if the word arrives after it.

#### Scenario: Relays are accepted only in order
- **GIVEN** opens 1 and 2 recorded and neither resolved
- **WHEN** the worker calls `resolve(2, cycleId, tokenId, opener)`
- **THEN** it reverts with `OutOfOrder`
- **AND** `resolve(1, cycleId, tokenId, opener)` requests one Chainlink word and emits `DrawRequested`
