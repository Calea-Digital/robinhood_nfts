# Proposal

## Why

The v2.2 client document places each open question under the requirements it holds up, from the
register's `Blocks` and the requirements' own `→ CQ-n` pointers. Four open questions reached only
part of what they govern, and CQ-7's record still said every sale settles through allowed venues,
which COL-7 no longer says. The reviewer agreed on 2026-09-24.

## What Changes

- CQ-9 **Blocks**: `RAF-28` → `RAF-28, RAF-29, RAF-30, RAF-31` (the four choices MINT confirms).
- CQ-12 **Blocks**: none → `OPS-1, OPS-2, WL-3, COL-10` (the admin, signer and deploy addresses).
- CQ-18 **Blocks**: none → `WL-4, OPS-4` (the stage order; the rehearsal's whitelist step).
- CQ-20 **Blocks**: none → `RAF-24, RAF-27` (the prize chains; the excluded ids and prize count).
- CQ-7's *Recorded as*: a sale a marketplace operates settles through allowed venues; one arranged
  outside a marketplace pays none (COL-7).
- No requirement changes; no decision changes state.

## Capabilities

None — register fields and one record sentence (`skip_specs: true`).

## Impact

- `openspec/decisions.md` (folded by hand); `docs/OPEN-QUESTIONS.md` re-rendered.
- Board: new gating links from CQ-9, CQ-12, CQ-18 and CQ-20's issues through `board.sh`.
- The client document's "Waits on" lines and its opening table follow.
