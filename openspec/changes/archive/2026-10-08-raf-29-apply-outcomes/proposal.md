# Proposal

## Why

Chainlink VRF v2.5 marks a request fulfilled even when the consumer's callback reverts, and the
number is then lost. In a draw that applies outcomes strictly in order, one lost number would
stall every later opening for good. So the callback must only store the number, and something
else must apply stored numbers in order: in particular the last openings of a cycle, after which
no further relay comes. Separately, `CycleExhausted` was keyed on `idsLeft`, which falls only
when a number is applied, so with several requests in flight more relays than playable bears
could be accepted.

## What Changes

- The VRF callback stores the number and applies outcomes in order within a fixed budget; it
  never reverts for a request the draw made.
- `resolve` applies pending outcomes too, and `applyOutcomes(maxCount)`, callable by anyone,
  applies stored numbers in order. Neither can change an outcome, only when it is recorded.
- `CycleExhausted` counts the relays accepted in the cycle, refusing one beyond `PLAYABLE`.
- `nextToApply()` is a read.

## Capabilities

### Modified Capabilities

- `mystery-box` (RAF): RAF-29, RAF-14, RAF-17.

## Impact

`PrizeDraw` (not yet written; RAF-8 builds its core). Nothing is deployed.
