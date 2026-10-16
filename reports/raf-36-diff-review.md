# Differential review — RAF-36, `PrizeVault.claim` (`feat/contracts...mnt/RAF-36`, `bb3f12c`)

**Scope:** `src/PrizeVault.sol` gains `claim`, `CLAIM_GRACE`, `claimed`, `claimDeadline` and
Solady's `EIP712` (`eip712Domain`). The diff also touches the suite (10 claim tests, 40 for the
vault), two winner mocks, the tree, DESIGN and the README. The spec change of the same day
(`raf-36-claim-window-from-start`) opens the window at `start`.
**Strategy:** DEEP. Phase 5 was run by `differential-review:adversarial-modeler`.
**Coverage:** `PrizeVault` 100% of lines, statements, branches and functions; 19 planted
breakages, all caught (the index bound after the stale-entry test).

## Findings

Nothing is exploitable. Attackers checked:
- an outside account with no ticket;
- a winner holding one ticket (a second claim, another's prize, a malleable twin, an index
  outside the list, a stale entry);
- a winner contract re-entering through `receive`, `onERC721Received` or `onERC1155Received`;
- a hostile token's callback;
- a ticket replayed across chains, vaults, cycles or prizes.

What holds, and why:
- `held ≥ reserved` holds, and `_tokenUse.entries` is exact.
- Replacement and claim never overlap: replacement needs `now < start`, a claim needs
  `now ≥ start`.
- The guard is Solady's `sstore`-based one, so it is safe for London bytecode.

| # | Severity | Note | Disposition |
|---|---|---|---|
| 1 | Info | A pause in the final hour, or a late word near `end`, leaves a winner less than the full grace hour; the prize carries over | the runbook (5.4): do not pause the vault after `end` |
| 2 | Info | A vault `start` registered later than the box's lets tickets exist for a list that can still be replaced, and a ticket does not bind `manifestHash` | the runbook's comparison of terms (5.4); the worker checks that the vault's cycle has started before it signs (4.2) |
| 3 | Info | If the worker's EOA is ever given code (EIP-7702), Solady checks only ERC-1271, and plain tickets stop validating | availability only, by the key holder's own act; noted in the RUNBOOK with 5.4 |

## Obligations passed to RAF-37 (in `PrizeVault.tree.md`)

- **`release`:**
  - It runs strictly after `end + CLAIM_GRACE`. `claim` accepts that second, and a release in the
    same second could lift a prize that is then claimed, lowering another cycle's reservation of
    the same asset.
  - It runs once per cycle, for a registered cycle only, whatever the pause.
  - It lifts only unclaimed entries 1 … `prizeCount` on this chain.
- **`withdraw`:**
  - It takes canonical arguments and refuses a kind other than the token's while the token is
    reserved (ERC-721 `transferFrom` shares ERC-20's selector).
  - It is `onlyOwner` and non-reentrant, and transfers last.

## Verdict

No exploitable issue. Three informational notes go to the runbook and the worker. Confidence:
high for `claim`; `release` and `withdraw` are not built yet.
