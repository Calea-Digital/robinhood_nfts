# Proposal

## Why

The review of `PrizeDraw` (MNT-51) found that asking Chainlink again for an unanswered opening lets
its node operator choose outcomes: it withholds a losing number until the worker asks again, then
delivers whichever number wins. Chainlink's own guidance is not to re-request randomness. The
review also found that a replacement draw would restart the opening sequence, that a relay could
apply an unbounded backlog, that a zero opener was accepted, and that the draw's copy of a
cycle's terms stayed replaceable after the cycle had started on Robinhood Chain.

## What Changes

- **Removed:** asking again (`rerequest`, `REREQUEST_AFTER`, `NotRelayed`, `AlreadyAnswered`,
  `TooEarly`). An unanswered request is recovered by funding the subscription; pending requests
  are then answered.
- **BREAKING (unreleased constructor):** `PrizeDraw` takes the first opening index it will relay,
  so a replacement (a new coordinator or subscription) continues `MysteryBox`'s sequence.
- `resolve` applies at most `RESOLVE_APPLY_LIMIT` (16) pending outcomes; `applyOutcomes` drains
  the rest.
- `resolve` refuses a zero opener (`InvalidOpener`).
- **BREAKING (unreleased):** `PrizeDraw.scheduleCycle(cycleId, start, prizeCount, manifestHash)`
  carries the cycle's start; the draw's terms are fixed from then, as the hub's are.

## Capabilities

### Modified Capabilities

- `mystery-box` (RAF): RAF-8, RAF-14, RAF-16, RAF-19, RAF-29, RAF-32.

## Impact

`PrizeDraw` on `mnt/RAF-8` (MNT-51, changes requested), its tests and tree; the stacked
branches `mnt/RAF-29`, `mnt/RAF-30`, `mnt/RAF-34` take the change before their reviews.
