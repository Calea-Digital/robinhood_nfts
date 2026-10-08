# Spec Delta

## MODIFIED Requirements

### Requirement: RAF-32 — Cycles
**Kind:** work-item
MINT's admin schedules each cycle before it starts: its window, its number of prizes, and a
fingerprint of the prize list MINT publishes (RAF-27) (MINT, CQ-9, CQ-20). A cycle can't be
scheduled while one is open, start in the past, or start before the previous one ends. A cycle
lasts at most 90 days, so a mistyped end date can't hold the game in one cycle for longer. A
scheduled cycle can be replaced until it starts; from then on its terms are fixed. Boxes open
only inside the window, and an opening made inside it is decided even if the answer arrives
after the window ends (RAF-29). Prizes a cycle doesn't award stay in MINT's prize wallet
(RAF-33) for a later cycle. MINT decides when the next cycle starts, so the game can rest between
cycles for as long as MINT needs. The draw is given the same prize count and fingerprint, and
both chains publish them, so anyone can check they match.

*Technical note.* `scheduleCycle(start, end, prizeCount, manifestHash)` on `MysteryBox` records
the next cycle. It is refused while a cycle is open (`CycleInProgress`); for a window that starts
in the past, starts before the previous cycle ends, ends before it starts, or has `end - start`
above `MAX_CYCLE_LENGTH`, 90 days (`InvalidWindow`); and for a prize count of zero or above
`PLAYABLE` (`InvalidPrizeCount`). A cycle is open from `start` to `end` inclusive. `PrizeDraw`
carries each cycle's `prizeCount` and `manifestHash`, set by the owner with
`scheduleCycle(cycleId, prizeCount, manifestHash)` before the cycle's first open is resolved.
Both chains emit `CycleScheduled`.

#### Scenario: A cycle opens and ends on its schedule
- **GIVEN** the owner has scheduled cycle 1 from `start` to `end` with 5 prizes
- **WHEN** a holder opens a box before `start`, between `start` and `end`, and after `end`
- **THEN** only the open between `start` and `end` succeeds, and the others revert with `CycleNotOpen`
- **AND** scheduling cycle 2 while cycle 1 is open reverts with `CycleInProgress`

### Requirement: RAF-17 — Reads
**Kind:** work-item
The page can read for free: the playable count, whether a bear is excluded or already opened this
cycle, the current cycle and its terms, the longest a cycle may last, the live odds, and each
opening's bear, outcome and payout. A wallet's shots left come from these reads, one per bear
(RAF-28).

*Technical note.* Hub: `MAX_BEARS`, `PLAYABLE`, `MAX_CYCLE_LENGTH`, `isExcluded(tokenId)`,
`currentCycle()` and each cycle's `(start, end, prizeCount, manifestHash)`, `isOpen()`,
`opened(cycleId, tokenId)`, `openCount()`. `PrizeDraw`: `PLAYABLE`, each cycle's `(prizeCount,
manifestHash, idsLeft, prizesLeft)`, `nextToResolve()`, `outcomeOf(openIndex)` with its `tokenId`,
`payoutOf(openIndex)`, and `odds(cycleId)` returning `(prizesLeft, idsLeft)`. Each read costs a
fixed amount, whatever the number of bears.

#### Scenario: Every read answers
- **WHEN** every listed read is called during an open cycle
- **THEN** each returns without reverting and `odds(cycleId)` returns `(prizesLeft, idsLeft)`
