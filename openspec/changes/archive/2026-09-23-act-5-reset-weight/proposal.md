# Proposal

## Why

ACT-5 says a transfer makes a bear's weight read zero. ACT-3 gives level 0 a weight of 100 and
defines `weightOf` as the weight of the bear's current level, and ACT-10 counts every bear not
held by the dead address in the royalty total. Read literally, ACT-5 would make a bear that was
sold unactivated weigh nothing while an identical bear that never moved weighs 100. The reset
takes a bear back to level 0; its weight is then level 0's weight. The reviewer confirmed this
reading on 2026-09-23.

## What Changes

- ACT-5's statement and Scenario: after a transfer, cumulative and level read zero, the weight
  reads the level-0 weight (`weightFor(0)`, 100 as specified in ACT-3), and the link reads
  `(0, 0)`. Nothing else in ACT-5 changes.

## Capabilities

### Modified Capabilities

- `activation` (prefix `ACT`): ACT-5 — what the weight reads after a reset.

## Impact

- No code change: `Activation.weightOf` already returns `weightFor(levelOf(id))`, which is the
  level-0 weight once the counter has moved.
- `test/Activation.t.sol`: the ACT-5 Scenario test asserts the level-0 weight.
- `docs/SPECIFICATION.md` (generated block) and the client document pick up the wording on the
  next render; the MNT board's ACT-5 Task body follows on the next `board.sh` run.
