# Proposal

## Why

The first `scheduleCycle` freezes whatever exclusions exist, including none. Scheduling before
the team bears are excluded, a mistyped range (221 or 2,222 ids instead of 222), or excluding
every id would each freeze for good: the team bears playing, odds that differ from the 4,222 the
draw is built with, or a box where no cycle can ever be scheduled.

## What Changes

- **BREAKING (unreleased constructor):** `MysteryBox(owner, bears, expectedPlayable)`. The
  expected playable count, 4,222, is the same deploy value `PrizeDraw` takes.
- The first `scheduleCycle` is refused unless `PLAYABLE` equals it
  (`ExclusionsIncomplete(have, want)`), so every exclusion mistake surfaces before anything
  freezes, and is fixed by one more range or, before the first cycle, a free redeploy.
- `EXPECTED_PLAYABLE` is a read.

## Capabilities

### Modified Capabilities

- `mystery-box` (RAF): RAF-27, RAF-17.

## Impact

`MysteryBox` on `mnt/RAF-27` (MNT-41, In Review) and its tests; the deploy entry point and the
runbook when they are written. Nothing is deployed.
