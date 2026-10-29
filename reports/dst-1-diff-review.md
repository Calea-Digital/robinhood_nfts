# Differential review — BearDrop, DST-5 and DST-1

- **Target:** `packages/contracts/src/BearDrop.sol` in mintdotio/NFT, diffed against `feat/contracts` `ae733f4`.
  The file is new. It is stacked on `mnt/DST-5` (`e2a5e8c`); DST-1 is uncommitted on `mnt/DST-1`.
- **Spec:** DST-5 (ownership and pause) and DST-1 (rounds and amounts), in `openspec/specs/distribution/spec.md`.
- **Date:** 29 October 2026. **Reviewer:** Claude Code. **Strategy:** DEEP, since it is one small file.
  Every line was read.

## Triage

| Area | Risk | Why |
|---|---|---|
| Constructor, two-step ownership, `renounceOwnership` and `transferOwnership` overrides | HIGH (auth) | Decides who can set amounts and open rounds |
| `setPaused` | MEDIUM | Owner only. It gates claims, which DST-2 adds |
| `setAmounts`, `openRound` | HIGH (value accounting) | They decide what holders are owed, and `owed` caps later withdrawals (DST-4) |
| `roundOf` | LOW | A view |

There is no history to blame and nothing is removed: this is greenfield code. Its blast radius is
nothing calling it today. The deploy script, the client and the claim come in later Tasks.

## Analysis

**Access control.**
- Every write is `onlyOwner` (Solady's caller check).
- `transferOwnership` and `renounceOwnership` revert for every caller.
- Ownership moves only by `requestOwnershipHandover` from the new owner, then
  `completeOwnershipHandover` from the owner, within 48 h. An expired request is refused, which a
  test covers.
- The zero owner is refused in the constructor. Solady's `_initializeOwner` would otherwise accept
  it.

**Arithmetic.**
- In `total - amounts_[id] + amounts[i]`, the subtraction cannot underflow, because `total` is
  always the sum of the round's stored amounts (INV-38), so it is at least `amounts_[id]`.
- The addition is checked.
- `toUint128` caps the round's total. Every single amount is therefore at most 2^128, and so is the
  `claimedTotal` that DST-2 adds.
- In `openRound`, `end <= start` is tested before `end - start`, and `||` short-circuits, so the
  `uint40` subtraction cannot underflow.

**External calls.** `openRound` makes one `staticcall` to `MNTD.balanceOf`. Nothing else is
called, so there is no reentrancy surface. MNTD is immutable and non-zero.

**Round lifecycle.**
- Only `roundCount + 1` takes amounts or opens, so an opened round's amounts and terms can never
  change (INV-37).
- A next round that is never opened leaves inert storage, which is harmless.
- `owed` grows only by an opened round's total, after the balance check.

**Funding check.** `balanceOf(this) >= owed + total`. Anyone sending $MNTD only raises the balance.
A fee-on-transfer token would not change the check. $MNTD on 4663 is a plain OpenZeppelin ERC-20.

**Tests.**
- 13 tests, 100% line and branch coverage of the contract.
- Six planted breakages for DST-5 and eleven for DST-1 each fail a test.

**Adversarial view.** The attacker is a holder or a stranger. Neither has any write path, because
every write is the owner's. A compromised owner can set and open future rounds and pause claims,
which is the trust the spec accepts. It cannot change an opened round. Withdrawal is DST-4's and is
not in this diff.

## Findings

No Critical, High, Medium or Low findings.

### I-1 — Fund only after the handover (Informational)
**Where:** the deploy order (OPS-2) and the runbook, which come with DST-4 and OPS-2.

The deployer owns `BearDrop` until MINT's admin completes the handover. If MINT sent $MNTD before
the handover, the deployer would hold every owner power over it. Once DST-4 adds `withdraw`, that
includes withdrawing the unowed balance.

**Recommendation:** the RUNBOOK (OPS-2, 2.2) orders it as handover, then a read of `owner()`, then
funding. Add a test of the deploy script that funds nothing.

### I-2 — `listHash` is the owner's statement, not a check (Informational)
**Where:** `openRound`, line 156.

`openRound` stores the `listHash` it is given. It cannot know whether the stored amounts hash to it,
so before opening an owner could change an amount and still pass MINT's expected hash. The guard
is DST-6's `check`, run after the handover and immediately before `openRound`, against MINT's file.

**Option for the person:** compute the hash on-chain instead. `openRound` would walk ids 1 to
4,444, about 9.5M gas on Robinhood Chain, which is affordable. The emitted hash would then always
describe the stored amounts. This changes DST-1's technical note, so it is a spec change, not a fix.

### I-3 — A start far in the future holds funds (Informational)
**Where:** `openRound`, line 161.

`start` has no upper bound. A mistyped `start` years ahead would make the round's total owed, and
unwithdrawable, until `end`. Only the owner can do this, and DST-4's close needs `end` to pass.

**Recommendation:** accept it as owner error caught by the runbook's read-back of `roundOf`, or bound
`start` to, say, 30 days ahead. A bound is a spec change.

## Coverage and confidence

- Confidence is high for this diff. Every function was read and every refusal is tested.
- Not covered here:
  - `claim`, `closeRound` and `withdraw` (DST-2, DST-4), where the value actually leaves;
  - the deploy script;
  - the client.
- The review repeats for each of those Tasks.
