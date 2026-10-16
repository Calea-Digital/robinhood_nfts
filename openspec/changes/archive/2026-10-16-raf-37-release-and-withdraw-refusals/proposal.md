# Proposal

## Why

RAF-37 names only `Reserved` and the two events. MNT-167's review settled what `release` and
`withdraw` must also refuse for the reservations to stay exact:
- A `release` in the claim window's last second could lift a prize that is then claimed.
  `claim` accepts that second, and the second lift would take another cycle's reservation of the
  same asset.
- A second `release` would lift the same entries twice.
- A `withdraw` naming a reserved token under another kind could move it. An ERC-721's
  `transferFrom` shares ERC-20's selector.

The person chose a named error for each refusal (16 October 2026, MNT-168).

## What Changes

- **RAF-37:**
  - `release` is refused with `UnknownCycle`, with `ClaimWindowOpen` until `end + CLAIM_GRACE`
    has passed, and with `AlreadyReleased`. It lifts only the cycle's unclaimed entries on this
    chain, and runs whatever the pause.
  - `withdraw` is refused with `InvalidPrize`, `KindMismatch`, `Reserved` and `ZeroAddress`, and
    is non-reentrant.

  The Scenario is unchanged.
- **RAF-17:** `PrizeVault`'s reads include `released(cycleId)`, so the worker and the admin page
  can see whether a release is still due. The Scenario is unchanged.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mystery-box` (RAF): RAF-37's note; RAF-17's note.

## Impact

`PrizeVault.release`, `withdraw` and `released` on `mnt/RAF-37` (MNT-168, In Progress), and the
interface pin. No other contract changes.
