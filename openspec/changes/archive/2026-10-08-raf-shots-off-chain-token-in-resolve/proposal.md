# Proposal

## Why

`shotsLeft(wallet)` on `MysteryBox` cannot be built cheaply. The collection keeps no list of a
wallet's bears, so the read has to ask the owner of all 4,444 ids: measured at about 23M gas per
call, close to the limit many RPC providers put on a read. It enforces nothing; the page only shows
it. And `PrizeDraw` takes the worker's word for each opening without knowing which bear opened, so
a result can only be matched to an index, and nothing on the draw stops one bear being resolved
twice in a cycle or a relay running a cycle's pool below zero.

## What Changes

- `MysteryBox` has no per-wallet read. The page's "8 of 10 shots left" is counted by the client
  library from per-bear reads (`ownerOf`, `isExcluded`, `opened`) batched in one call; `open`
  still enforces one shot per bear per cycle.
- **BREAKING (unreleased interface):** `PrizeDraw.resolve(openIndex, cycleId, tokenId, opener)`
  carries the bear. The draw refuses an id outside the collection (`InvalidTokenId`), a bear
  already resolved in the cycle (`AlreadyResolved`) and a resolve once the cycle has no ids left
  (`CycleExhausted`). `OutcomeRecorded` and `outcomeOf` carry the `tokenId`.
- The win rule does not read the `tokenId`. The worker relays an opening only once the
  sequencer on 4663 has confirmed its block.

## Capabilities

### Modified Capabilities

- `mystery-box` (RAF): RAF-28, RAF-29, RAF-30, RAF-16, RAF-17, RAF-19.

## Impact

`MysteryBox` (RAF-28's open is built; no `shotsLeft` is added), `PrizeDraw` (not yet written),
the client library's mystery-box calls (DEL-6), `docs/HANDOVER.md`, the CQ-9 record, and the
tranche-2 pick order. Nothing is deployed.
