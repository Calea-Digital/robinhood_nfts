# Differential review: BearDrop, DST-4 (leftovers and withdrawal), with DST-5's Scenario

**Target:** `git diff mnt/DST-2 -- packages/contracts/src/BearDrop.sol` on `mnt/DST-4` in
mintdotio/NFT, stacked on `mnt/DST-2` `2ea3b28`.
**Spec:** DST-4, and DST-5's Scenario test, which needed `claim` and `closeRound`.
**Date:** 29 October 2026. **Reviewer:** Claude Code. **Strategy:** deep.

## Triage

| Change | Risk | Why |
|---|---|---|
| `withdraw(to, amount)` | HIGH (value transfer, owner power) | The owner's only way to move $MNTD out |
| `closeRound(roundId)` | HIGH (accounting) | Lowers `owed`, which is the cap on `withdraw` |
| The events and errors | LOW | Additions only |

Nothing is removed. `claim`, `setAmounts` and `openRound` are unchanged.

## Analysis

**The accounting holds.** Every write keeps `balance ≥ owed`:
- `openRound` requires `balance ≥ owed + total` before it adds `total` to `owed`.
- `claim` lowers `owed` and the balance by the same `sum`.
- `closeRound` lowers only `owed`.
- `withdraw` requires `amount ≤ balance` and `balance − amount ≥ owed`.

A transfer of $MNTD into the contract only adds surplus, and the contract cannot lose $MNTD any
other way: $MNTD needs an allowance to burn, and nothing grants one.

**No double release.**
- `closeRound` runs only strictly after `end`, and `claim` only up to `end`, so no bear of a
  closed round can still be paid.
- `closed` is set once, guarded by `AlreadyClosed`.
- `owed −= total − claimedTotal` cannot underflow: `owed` includes exactly that amount for an
  open round (INV-39).

**Who can do what.**
- `withdraw` is the owner's only, and is non-reentrant. The `Withdrawn` event is emitted before
  the single `safeTransfer`.
- `closeRound` is open to anyone. Its only effect is to stop reserving what nobody can claim any
  more, so an early or hostile caller gains nothing.
- The pause gates neither function, as DST-5 requires. Both the DST-5 Scenario test and the pause
  leaf show it.

**Tests and coverage.**
- 6 new tests (25 in all), among them the DST-4 and DST-5 Scenario quotes.
- 100% line and branch coverage.
- 11 planted breakages each fail a test.

## Findings

No Critical, High, Medium or Low findings.

### I-1 (restated now that `withdraw` exists): fund only after the handover, Informational

Until MINT's admin completes the handover, the deploying wallet is the owner, and `withdraw`
lets it take any $MNTD that no open round owes. If MINT funded before the handover, the
deployer could withdraw that funding.

**Required in the RUNBOOK (OPS-2, `tasks.md` 2.2), in this order:**
1. the handover;
2. MINT reads `owner()` and confirms it is the admin;
3. MINT funds the contract;
4. the admin calls `openRound`.

### I-6: a round can be opened against surplus another round freed, Informational, intended

After `closeRound`, the unclaimed share becomes surplus and can back a later round with no new
funding (`test_closedShare_fundsTheNextRound`). The spec intends this ("for a later round"). It
is listed so the reviewer sees that `openRound` counts the whole balance, not only fresh funding.

## Coverage and confidence

Confidence is high. With DST-4, the contract's value paths are complete: `openRound` reserves,
`claim` pays, `closeRound` releases, `withdraw` takes the surplus.

Still to come:
- DST-3: every read asserted, and the interface pinned.
- DST-6: the list script.
- OPS-2: the deploy entry point and the runbook, where I-1's order is written down.
- DEL-6: the client.
