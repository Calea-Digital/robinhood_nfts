# Differential review: BearDrop, DST-2 (the claim)

- **Target:** `git diff mnt/DST-1 -- packages/contracts/src/BearDrop.sol` on `mnt/DST-2` in mintdotio/NFT,
  stacked on `mnt/DST-1` `c8162bd`.
- **Spec:** DST-2 (claim by the bear's owner).
- **Date:** 29 October 2026.
- **Reviewer:** Claude Code.
- **Strategy:** deep. Every changed line was read.

## Triage

| Change | Risk | Why |
|---|---|---|
| `claim(roundId, ids)` | HIGH (value transfer, external calls) | The only path by which $MNTD leaves to holders |
| `ReentrancyGuard`, `LibBitmap` | MEDIUM | Guard and per-round claim record |
| `claimed(roundId, id)` | LOW | A view |
| Errors and the `Claimed` event | LOW | Additions only |

Nothing is removed or weakened. DST-1's functions are unchanged.

## Analysis

**Order of effects.**
- The checks come first: the round, the pause, the window and the batch.
- Then, per id: ownership through `ownerOf`, the amount, and the claimed bit. The bit is set before
  the next id, so an id repeated in the batch is refused.
- After the loop, `claimedTotal` and `owed` are updated, then one `safeTransfer` to `msg.sender` is
  made last.
- Checks, effects, interaction, with `nonReentrant` on top. A test with a token that calls back on
  transfer shows the nested claim refused with `Reentrancy`.

**Who is paid.** Only `msg.sender`, and only for bears `ownerOf` names as theirs at that moment.
- No one can claim for another holder.
- A seller loses the right the moment the bear moves, which the Scenario test covers.
- A smart account claims like any wallet.

**Arithmetic.**
- `sum` is the sum of distinct ids' amounts in one round, at most the round's unclaimed total, which
  fits in a `uint128`. So `toUint128(sum)` cannot revert on a valid batch.
- `owed -= sum` cannot underflow, because `owed` includes that round's unclaimed total.
- **For DST-4:** `closeRound` must subtract only after `end`. Claims stop at `end`, so a round can
  never be claimed after its unclaimed amount has left `owed`.

**External calls.**
- `ownerOf` on the immutable collection, once per id. Slither flags it as `calls-loop` (Low). It is
  benign: the collection is fixed, the read is a view, and a failing id reverts the whole batch, as
  specified.
- One $MNTD transfer through `SafeTransferLib`, which reverts on a false or failed transfer.

**Gas.** ERC721A's `ownerOf` walks back to a batch's first id. The worst case is a bear deep in the
team's 222-bear mint, roughly 222 storage reads the first time and warm reads after that. A batch of
every one of a wallet's bears stays well under the block gas limit, and the client can split
batches.

**Tests.**
- 6 new tests, 19 in all for `BearDrop`.
- 100% line and branch coverage.
- 15 planted breakages each fail a test, including a missing reentrancy guard, a window made
  exclusive at `end`, and a claim not marked.

## Findings

No Critical, High, Medium or Low findings.

### I-4: Refusal order differs from the spec's list (Informational)

`claim` checks the pause before the window: `UnknownRound`, then `ContractPaused`, then
`OutsideWindow`. DST-2's technical note lists `OutsideWindow` before `ContractPaused`. The note does
not promise an order, and the code matches `MysteryBox` (pause first). As a result, a paused round
that has also ended reports `ContractPaused`.

**Recommendation:** the client (DEL-6) maps both codes to holder messages, so no change. Optionally,
reorder the list in DST-2's note at the next spec edit.

### I-5: `ownerOf` inside the loop (Informational; Slither `calls-loop`, Low)

This is as analysed above, and accepted.

## Coverage and confidence

Confidence is high for `claim`. Not covered here:
- `closeRound` and `withdraw` (DST-4), which must respect the `owed` reasoning above;
- the reads' interface pin (DST-3);
- the deploy script, the list script and the client.
