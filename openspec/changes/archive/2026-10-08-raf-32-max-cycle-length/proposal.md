# Proposal

## Why

A cycle ends on its own at the `end` the owner sets when scheduling it, and nothing can end or
cancel it earlier: its terms are fixed from its start. A mistyped `end` (a year too far, or the
type's maximum) would therefore keep that cycle open, and block every later one, until that time.
The only way out would be a new `MysteryBox`, which restarts the opening sequence the draw's
in-order relay depends on.

## What Changes

- A cycle lasts at most 90 days: `scheduleCycle` refuses a longer window with `InvalidWindow`.
- `MAX_CYCLE_LENGTH` (90 days) is a public read.
- Terms stay fixed from a cycle's start; no cancel or early end is added.

## Capabilities

### Modified Capabilities

- `mystery-box` (RAF): RAF-32, RAF-17.

## Impact

`MysteryBox` (branch `mnt/RAF-32`, In Review) and its tests and tree; the board's RAF-32 and
RAF-17 Tasks. MINT can ask for a different bound.
