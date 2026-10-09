# Proposal

## Why

RAF-33 waits on CQ-22, yet only the way a prize is delivered depends on MINT's answer:
- who sends it;
- whether it is pushed, or the winner requests it within a window.

The record on `PrizeDraw` is the same in every answer: `recordPayout`, `NotAWin`, `AlreadyPaid`
and `PrizePaid`. The handover already says "`recordPayout` is built either way".

While the gate stands, three Tasks can't meet their Scenarios, because each names the record:
- RAF-17 (`payoutOf`);
- RAF-19 ("a win is recorded as paid once");
- RAF-14 (a non-worker's `recordPayout`).

That stalls tranche 2 behind a decision due on 12 October. This was found in the integrity check
of 9 October, IC-1.

## What Changes

- **RAF-33** no longer points at CQ-22 as a gate. The payout record is built now. How a win is
  sent stays MINT's decision (CQ-22), and the statement says it doesn't change the record.
- **RAF-18** carries the CQ-22 gate instead. Its step 6 ("each win is paid … and recorded") is
  where the delivery method shows: the worker's or MINT's sending, and any request window.
- **CQ-22's `Blocks`** goes from RAF-33 to RAF-18. RAF-18 is already gated by CQ-23, so nothing
  that is free today becomes blocked.
- The tranche-2 pick order puts RAF-33 ahead of RAF-17 and RAF-19 (`tasks.md`).

No requirement is added or retired, and no Scenario changes.

## Capabilities

### Modified Capabilities

- `mystery-box` (RAF): RAF-33, RAF-18.

## Impact

- **Code:** none yet. RAF-33's Task (MNT-137) becomes claimable and adds `recordPayout` to
  `PrizeDraw`, which is not deployed anywhere.
- **Board:**
  - MNT-137 loses its gate;
  - MNT-59 (RAF-18) gains CQ-22 beside CQ-23;
  - CQ-22's link to MNT-137 has to be removed (see design.md).
- **Client document:** the "Waits on CQ-22" line moves from RAF-33 to RAF-18 at the next build.
  `spec_version` stays 2.6.
