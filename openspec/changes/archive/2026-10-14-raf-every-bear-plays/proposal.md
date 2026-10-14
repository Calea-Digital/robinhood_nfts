# Proposal

## Why

MINT's answer at the meeting of 12 October 2026 (CQ-20): every bear plays the mystery box, the
team's 222 included, and a team bear can win like any other. The specification excluded the 222
team bears for good before the first cycle (RAF-27), and `MysteryBox` is built to record and
freeze that exclusion. The person chose to remove the exclusion from the code rather than deploy
it unused: an unused `excludeRange` called by mistake before the first cycle would stop the
first cycle from ever being scheduled.

## What Changes

- **RAF-27** becomes "Every bear plays, and the prize pool": no exclusion; `PLAYABLE` is 4,444 on
  both chains. Its Scenario keeps its title and now reads: a box deployed with no other call schedules its first cycle with
  `PLAYABLE` 4,444, and a team bear can be opened.
- **RAF-28**: no refusal for a team bear (`IdExcluded` goes); shots left read `ownerOf` and
  `opened`.
- **RAF-8**: at most 4,444 numbers a cycle.
- **RAF-14**: the owner no longer records team bears (`excludeRange` goes).
- **RAF-16**: `IdsExcluded` goes.
- **RAF-17**: `EXPECTED_PLAYABLE`, `excludedCount` and `isExcluded` go.
- **RAF-18**: the one-time exclusion step goes.
- **RAF-19**: the two exclusion cases become one: every bear can be opened, a team bear included.
- **DEL-6**: the admin page has no exclusion.
- **OPS-2**: `MysteryBox(owner, bears)`; `PrizeDraw` with `playable` 4,444.
- **OPS-4**: the rehearsal's cycles exclude nothing.

No requirement is added or retired. RAF-27's Scenario is replaced; RAF-14's, RAF-16's, RAF-18's
and RAF-28's lose their exclusion wording. The code change is a `NONE` Task in `../NFT`.
