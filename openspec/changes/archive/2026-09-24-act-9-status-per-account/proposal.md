# Proposal

## Why

ACT-9 lets each wallet nominate one bear to carry its Status boost, and the boost's value is
MINT's, off-chain. A getminted.io account may use several wallets — WL-1 and WL-3 already rely on
it — so one account can carry several links, one per wallet. How MINT's Status counts them is not
specified: one link per account (and which), the highest, or every wallet's. The tranche-1 review
of MNT-34 (2026-09-24) found the gap; the reviewer asked for it to be raised with MINT.

## What Changes

- New decision **CQ-21** — how MINT's Status counts the links of an account's wallets — open,
  needed by the burn switch-on (29 October 2026), blocking ACT-9, with Calea's default.
- ACT-9 points to it (`→ CQ-21`). No behaviour change: the contract is as built, the Kind
  (`work-item`) and Scenario are unchanged, and no answer to CQ-21 changes `Activation`.
- §10 of the specification gains the open item O9 for CQ-21.

## Capabilities

### Modified Capabilities

- `activation` (prefix `ACT`): ACT-9 — the pointer to CQ-21.

## Impact

- No code or test change.
- `openspec/decisions.md` gains CQ-21 (folded by hand at archive); `docs/OPEN-QUESTIONS.md` and
  the ACT block of `docs/SPECIFICATION.md` follow on render; §10's narrative gains O9.
- Board: a new decision Task for CQ-21 and a refreshed MNT-34 body, through `board.sh`.
- DEL-6: the portal and MINT's Status service read `linkOf` per wallet; CQ-21's answer says how
  MINT combines them per account.
