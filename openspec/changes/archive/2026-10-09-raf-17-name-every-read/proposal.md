# Proposal

## Why

RAF-17's technical note lists the reads the page needs, but both contracts expose more public
reads than it names: the hub's exclusion count, pause flag, collection and ownership, and the
draw's worker, pause flag, cursor, request map, apply limit and Chainlink configuration
(integrity check of 9 October, IC-15). ACT-14 names every `Activation` read, and the interface of
both tranche-2 contracts is about to be pinned from their artifacts, so the spec should name
every read the pin allows. The same check found that RAF-29's note doesn't name
`InsufficientGas`, which `applyOutcomes` has raised since the fix of 9 October.

## What Changes

- RAF-17's technical note names every public read of `MysteryBox` and `PrizeDraw`. The statement
  and the Scenario are unchanged.
- RAF-29's technical note names `InsufficientGas`: `applyOutcomes` refuses when it stops for gas
  with fewer than `maxCount` applied and the next opening's word stored. The statement and the
  Scenario are unchanged.

## Capabilities

### Modified Capabilities

- `mystery-box` (RAF): RAF-17, RAF-29.

## Impact

- **Code:** none in `src/`. The RAF-17 Task reads every named read and pins both interfaces.
  `InsufficientGas` is on `feat/contracts` already.
- **Board:** the bodies of RAF-17's and RAF-29's Tasks are refreshed.
- **Client document:** the next build carries it. Technical notes are left out of the client
  document, so its text does not change. `spec_version` stays 2.6.
