# Proposal

## Why

`PrizeDraw` applies outcomes strictly in `openIndex` order. If Chainlink never answers a
request (its subscription runs dry long enough for the request to lapse), that opening never
gets a word and every later opening waits behind it for good. Separately, decision CQ-20 still
owes the team-bear ranges, but the only requirement it lists, RAF-27, is done; the ranges are
needed by the rehearsal.

## What Changes

- The worker can ask Chainlink again for an opening that has had no answer for 24 hours,
  `rerequest(openIndex)`. Every request for the opening stays valid and the first answer to
  arrive is the one used, so a second request can never let anyone choose between two answers.
- A refusal for an opening not yet relayed (`NotRelayed`), one already answered
  (`AlreadyAnswered`) and one asked within the last 24 hours (`TooEarly`).
- RAF-19 gains the acceptance case.
- CQ-20 blocks OPS-4 as well as RAF-27: the rehearsal's two cycles need the real ranges.

## Capabilities

### Modified Capabilities

- `mystery-box` (RAF): RAF-8, RAF-14, RAF-19.

## Impact

`PrizeDraw` on `mnt/RAF-8` (MNT-51, In Review); `openspec/decisions.md` (CQ-20's Blocks); the
board's gating links.
