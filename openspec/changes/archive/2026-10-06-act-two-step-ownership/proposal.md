# Proposal

## Why

The security review (audit L-01, MNT-147) found that `Activation`'s ownership moves in one step.
A rotation to an address nobody controls, made while burning is paused, could never be undone: the
pause could not be lifted, and a new `Activation` would lose every level holders paid for.

## What Changes

- **BREAKING (constructor):** `Activation(owner, bears, mntd, thresholds, weights)`. The owner is
  MINT's admin, set at construction (a zero owner is refused), and `Activation` is paused from
  construction. The deploy makes no call after construction.
- A single-step ownership transfer is refused. Ownership moves only when the new owner has asked
  for it and the current owner then confirms, within 48 hours.

## Capabilities

### Modified Capabilities

- `activation` (ACT): ACT-12 (two-step ownership only), ACT-15 (paused from construction).
- `operations` (OPS): OPS-2 (Activation's constructor and the calls after construction).

## Impact

`src/Activation.sol`, `script/Deploy.s.sol`, `test/Activation.t.sol`, `test/Deploy.t.sol`, the
trees, `docs/RUNBOOK.md`, `CLAUDE.md`, and the client library's ABI and test fixture. Nothing is
deployed yet, so no migration is needed.
