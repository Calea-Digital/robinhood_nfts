# Proposal

## Why

OPS-2's technical note gives constructors for `MysteryBox` and `PrizeDraw` that the code does not
have. Found by the review of the registry removal (14 October 2026): `MysteryBox` takes
`expectedPlayable` (RAF-27), and `PrizeDraw` takes the VRF request settings and `firstOpenIndex`
(RAF-8) and no worker, which the owner sets with `setWorker` (RAF-14).

## What Changes

- **OPS-2**: the technical note states both constructors as built, and `setWorker` after the
  draw is added to the subscription.

No requirement is added or retired, and no Scenario changes.
