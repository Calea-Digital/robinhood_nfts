# Design

## Context

`PrizeVault.registerCycle` is built on `mnt/RAF-35` (`7eadd3d`). The review's findings 4 (a bounded
balance read) and 5 (DESIGN's wording) are fixed on that branch without a spec change. This
change covers 1, 2 and 3, which add refusals, and 6, which is a trust statement.

## Goals / Non-Goals

**Goals:**
- A reservation always matches something the vault can pay to one winner, whatever mistake the
  owner makes in a list.
- No new public read, and RAF-17's list unchanged.

**Non-Goals:**
- Checking the vault's terms against the box on chain. No messaging joins the chains, so the
  runbook compares `cycle(cycleId)` on every vault with `CycleScheduled` on the box and the draw
  before `start`.
- A delay on `setSigner`, or a signer per cycle (finding 6, accepted).
- ERC-165 checks of a token's standard.

## Decisions

- **One kind per token while it is reserved.**
  - The vault keeps, per token address, the kind it is reserved under and the number of reserved
    own-chain entries naming it.
  - An entry under another kind is refused with `KindMismatch` while that count is above zero.
  - Replacement lowers the count with the reservations it lifts. The claim and the release
    (RAF-36, RAF-37) must lower it the same way.
  - Native entries name no token and are not counted.
  - The alternative, a kind fixed for good on first use, makes a mistaken listing permanent.
- **The 90-day bound** is a private constant equal to the box's `MAX_CYCLE_LENGTH`. A public read
  would change RAF-17. The bound caps how long a mistyped `end` can hold prizes reserved.
- **Canonical entries, `InvalidPrize`:**
  - `amount` is non-zero;
  - a native entry has a zero token and a zero id;
  - an ERC-20 entry has a zero id;
  - an ERC-721 entry's amount is 1.

  The check runs for every entry, own-chain or not, so every vault refuses the same lists and the
  published list says exactly what is reserved. The asset-key normalisation stays in the code, as
  a second line of defence.

## Risks / Trade-offs

- **The per-token count is new state that RAF-36 and RAF-37 must keep exact.** It is recorded as
  an obligation in `PrizeVault.tree.md` and in `tranche-2/tasks.md` 5.2 and 5.3.
- **A list that a vault on another chain refuses** fails registration everywhere only if every
  vault runs the same checks. They do: every check except `Unfunded` and `KindMismatch` depends
  on the list alone.
