# Spec Delta

## Purpose
MINT gives $MNTD to MintABear holders as a claim each bear makes, never as an airdrop. A bear's
amount stays with the bear until it is claimed, so anyone, including a buyer on the secondary market,
can look a bear up by its id and see what it still has to claim.

## ADDED Requirements

### Requirement: DST-1 — Rounds and amounts
**Kind:** work-item
MINT's $MNTD for holders is handed out in numbered rounds. Before a round opens, the owner sets each
bear's amount for it from the round's list, in as many batches as needed, and can correct them.
Opening the round fixes those amounts, the claim window and a fingerprint of the list, so the amounts
cannot change once holders can claim. A round opens only if the contract already holds every $MNTD it
owes, this round's total included. In round 1, every bear, the team's 222 included, gets 500 $MNTD,
2,222,000 in all, claimable for 90 days (MINT, CQ-25, CQ-27). MINT may run later rounds the same way
(CQ-26).

*Technical note.* `BearDrop.setAmounts(uint64 roundId, uint256[] ids, uint256[] amounts)`, owner only,
for the next round (`roundCount + 1`) only (`NotNextRound`). It refuses mismatched lengths
(`LengthMismatch`) and an id outside 1–4,444 (`InvalidTokenId`). Setting an id again replaces its
amount, and the round's running total follows. Emits `AmountsSet(roundId, count, total)`.
`openRound(uint64 roundId, uint40 start, uint40 end, bytes32 listHash)`, owner only, refuses:
- `NotNextRound`;
- `EmptyRound`, for a total of zero;
- `InvalidWindow`, for `start` in the past, `end <= start` or `end - start > MAX_ROUND_LENGTH`
  (365 days);
- `Unfunded`, when the $MNTD balance is below `owed` plus the round's total.

It then adds the total to `owed`, increments `roundCount` and emits
`RoundOpened(roundId, start, end, total, listHash)`. `listHash` is
`keccak256(abi.encode(ids, amounts))` over the list's rows sorted by id (DST-6).

#### Scenario: A funded round opens and its amounts are fixed
- **GIVEN** amounts set for round 1, with bear 7 at 100 $MNTD and bear 8 at 50, and the contract holding 150 $MNTD
- **WHEN** the owner opens round 1 and then calls `setAmounts` for round 1 again
- **THEN** the round opens with a total of 150 and `owed` reads 150, and the second `setAmounts` reverts with `NotNextRound`
- **AND** with only 149 $MNTD held, `openRound` reverts with `Unfunded`

### Requirement: DST-2 — Claim by the bear's owner
**Kind:** work-item
During a round's window, a bear's current owner claims the bear's amount for that round, for several
bears in one transaction, and receives the $MNTD. Each bear claims once per round. An amount nobody has
claimed stays with the bear when it changes hands, so the buyer can claim it; a transfer resets nothing.

*Technical note.* `claim(uint64 roundId, uint256[] ids)` is non-reentrant and pays `msg.sender` the
sum. The whole call reverts on the first id that fails:
- `UnknownRound`, for a round not yet opened;
- `OutsideWindow`, before `start` or after `end`;
- `ContractPaused` (DST-5);
- `NotBearOwner`, unless `ownerOf(id) == msg.sender`;
- `NothingToClaim`, for an amount of zero;
- `AlreadyClaimed`.

Each id emits `Claimed(roundId, tokenId, owner, amount)`. `owed` falls by the sum. The only call made
on the collection is `ownerOf`.

#### Scenario: The buyer claims what the seller left
- **GIVEN** round 1 open with bear 7 at 100 $MNTD, and bear 7 sold by its first owner without claiming
- **WHEN** the buyer claims bear 7 in round 1, and then the buyer claims it again and the seller tries
- **THEN** the buyer receives 100 $MNTD and `claimed(1, 7)` reads true
- **AND** the buyer's second claim reverts with `AlreadyClaimed` and the seller's with `NotBearOwner`

### Requirement: DST-3 — Reads for an id checker
**Kind:** work-item
For any bear and any round, anyone can read for free how much the bear gets and whether it has been
claimed, together with each round's window, total, amount claimed and fingerprint. A page can therefore
answer "does this bear still have tokens to claim?" with no backend.

*Technical note.* `amountOf(roundId, id)`, `claimed(roundId, id)`,
`roundOf(roundId) → (start, end, total, claimedTotal, listHash, closed)`, `roundCount`, `owed`,
`paused`, `BEARS`, `MNTD`, `MAX_ROUND_LENGTH`, plus Solady's `owner` and `ownershipHandoverExpiresAt`.
No other public read or write exists beyond those named in DST-1 to DST-5. The interface is pinned from
the artifact, as ACT-12 is.

#### Scenario: A bear's entitlement is readable by anyone
- **GIVEN** round 1 open, with bear 7 at 100 $MNTD and claimed, and bear 8 at 50 $MNTD and not claimed
- **WHEN** an address with no bear reads `amountOf` and `claimed` for bears 7, 8 and 9 in round 1
- **THEN** they read 100 and true, 50 and false, and 0 and false

### Requirement: DST-4 — Leftovers and withdrawal
**Kind:** work-item
The owner can withdraw $MNTD only beyond what running rounds still owe holders. Once a round's window
has ended, anyone can close it, which frees its unclaimed share for withdrawal or for a later round.
That share includes the amounts of bears held by the dead address, which no one can claim.

*Technical note.* `closeRound(roundId)` can be called by anyone, strictly after `end`, once. It
refuses `UnknownRound`, `RoundRunning` and `AlreadyClosed`, subtracts `total - claimedTotal` from
`owed`, and emits `RoundClosed(roundId, unclaimed)`.
`withdraw(address to, uint256 amount)` is owner only and non-reentrant. It refuses `ZeroAddress`, and
`Reserved` when the balance after the withdrawal would be below `owed`. It emits
`Withdrawn(to, amount)`. Only $MNTD is held and withdrawable; the contract accepts no native currency.

#### Scenario: Only the unowed balance leaves
- **GIVEN** round 1 open with a total of 150 $MNTD, 100 claimed, and the contract holding 70 $MNTD
- **WHEN** the owner withdraws 21 during the window, withdraws 20, and then, after `end`, someone closes round 1 and the owner withdraws the remaining 50
- **THEN** the first withdrawal reverts with `Reserved`, the second succeeds, and after the close `owed` reads 0 and the 50 is withdrawn

### Requirement: DST-5 — Ownership and pause
**Kind:** work-item
`BearDrop` always has an owner, and ownership moves only by a handover the new owner asks for and the
current owner completes. MINT's admin ends up the owner (OPS-2). The owner can pause claims and resume
them. A pause stops claims only: it does not move a window's end, and reads, closing and withdrawal
carry on.

*Technical note.* `BearDrop(owner, bears, mntd)`: a zero address refuses with `ZeroAddress`, and
`BEARS` and `MNTD` are immutable. Solady `Ownable` with `requestOwnershipHandover` and
`completeOwnershipHandover` (48 h). `transferOwnership` reverts with `TwoStepHandoverOnly`, and
`renounceOwnership` reverts with `RenounceDisabled`. `setPaused(bool)`, owner only, emits
`PausedSet(paused)`.

#### Scenario: Ownership moves only by handover, and the pause stops claims only
- **GIVEN** `BearDrop` owned by the deployer, with round 1 open
- **WHEN** the owner calls `transferOwnership` and `renounceOwnership`, MINT's admin requests a handover and the deployer completes it, and the new owner pauses
- **THEN** the first two revert, `owner` reads MINT's admin, a holder's claim reverts with `ContractPaused`, and `closeRound` after `end` still succeeds

### Requirement: DST-6 — Loading and checking MINT's list
**Kind:** work-item
Each round's list is a CSV with one bear per row. For round 1, Calea writes it from CQ-25 (4,444
rows of 500 $MNTD) and MINT confirms its checksum. Calea's script loads it on-chain in batches and
then reads every bear's amount back. It fails unless the chain matches the file exactly,
with a bear absent from the file reading zero, and the round's total and fingerprint match. A malformed
file is refused before anything is sent.

*Technical note.* `script/BearDropList.s.sol`:
- `load(path, drop, roundId)` sends `setAmounts` in batches.
- `check(path, drop, roundId)` is read-only and compares ids 1–4,444, the total and the `listHash`. A
  difference fails with `AmountMismatch(id, onChain, inFile)`, `TotalMismatch` or `HashMismatch`.
- `hash(path)` prints `listHash` for `openRound`.

The CSV header is `tokenId,amount`, with the amount in whole $MNTD and at most 18 decimal places,
scaled by `MNTD.decimals()`. It refuses `BadHeader`, `BadRow(line, row)`, `EmptyList`,
`DuplicateId(id)`, `InvalidTokenId(id)` and `ZeroAmount(id)`. It reads from `exports/` only.

#### Scenario: The chain matches MINT's file, or the check fails
- **GIVEN** a CSV with bear 7 at `100` and bear 8 at `50.5`, loaded into round 1
- **WHEN** `check` runs against it, and again after the owner changes bear 8 to 50 $MNTD on-chain
- **THEN** the first run passes, with bear 9 reading zero, and the second fails with `AmountMismatch(8, 50e18, 50.5e18)`
