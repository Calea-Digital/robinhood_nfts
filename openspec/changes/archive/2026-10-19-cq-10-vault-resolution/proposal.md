# Proposal

## Why

CQ-10's Resolution still states the prize-wallet model: "there is no vault to claim from; a win is
paid from MINT's prize wallet … a 30-day window applies only if it is requested". MINT replaced
that model on 15 October (CQ-22, option B): a winner claims from the prize vault on the prize's
chain until one hour after the cycle's end (RAF-36), and an unclaimed prize carries over to a
later cycle (RAF-37). The Summary already reads "Superseded by CQ-22"; the Resolution line and
the record do not say what replaced it. It shows in `docs/OPEN-QUESTIONS.md` and in the client
document (integrity check of 16 October, IC-19).

## What Changes

- **Register:** CQ-10's Resolution names the claim window that replaced it, its Blocks line adds
  RAF-36 and RAF-37, and its record gains a "Superseded (MINT, 15 October 2026, CQ-22)"
  paragraph, the same shape as CQ-8, CQ-11 and CQ-20.

No requirement changes (`skip_specs`), so no test quote and no board Task body changes beyond
CQ-10's decision issue.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- None (register only).

## Out of scope

- RAF-27's Scenario title (R-2): OpenSpec refuses a renamed Scenario in a MODIFIED block.
