# Differential review — RAF-37, `PrizeVault.release` and `withdraw` (`feat/contracts...mnt/RAF-37`, `79b6b62`)

**Scope:** `release(cycleId)`, `withdraw(kind, token, id, amount, to)` and `released(cycleId)`.
The canonical check, the balance read and the payment now take a bare asset, and are shared by
registration, claim and withdrawal. The diff also touches 7 tests, the tree, DESIGN and the
README. The spec change of the same day is `raf-37-release-and-withdraw-refusals`.
**Strategy:** DEEP. Phase 5 was run by `differential-review:adversarial-modeler`, which ran 3
throwaway PoCs.
**Coverage:** `PrizeVault` 100% of lines, statements, branches and functions; 17 planted
breakages, all caught.

## What holds

The reservations and the per-token counts are exact in every order of calls:
- **Each path owns its own time.** Replacement only before `start`; claim from `start` to
  `end + CLAIM_GRACE`; release strictly after, once. The boundary second was checked.
- **Release:** it makes no external call, so it cannot be blocked, and its loop is bounded by
  `MAX_PRIZES`.
- **Overlapping cycles:** releasing one cycle leaves another's reservation of the same asset
  intact (PoC).
- **No non-owner attacker** gains anything.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | Low | `withdraw` with `amount > held` skipped the reservation check and left the refusal to the token. Some mainstream tokens (Compound III's Comet) read `type(uint256).max` as "everything", so the owner could drain reserved prizes (PoC) | **fixed**: `amount > held` is refused with `Reserved`; pinned in `test_withdraw_refusals` (the old check fails it) |
| F2 | Info | The kind lock is per address. A token reaching one ledger through two addresses (a double-entry-point ERC-20, a DN404 or ERC-404 pair) gets past it: a withdrawal through the twin, or a claim burning the mirror NFT (PoC) | DESIGN says such tokens are never listed; the runbook's token rules (5.4) and the list builder (5.6) |

## Verdict

Nothing is exploitable by an account without a role. F1 is fixed, and F2 is an operating rule.
The vault is complete as a contract (RAF-35 to RAF-37). Before deployment come 5.4 (deploy entry
point and runbook) and 5.5 (verification).
