# Design

## Context

Holders' $MNTD has to reach each bear without an airdrop, and anyone must be able to check a bear's
entitlement by its id. The collection (`MintABear`) is live on Robinhood Chain and will not change, so
the new contract reads it through `IMintABear` (`ownerOf`, `exists`), as `MysteryBox` does. $MNTD on
4663 is `0x62Ed…a967`: a plain ERC-20 with 18 decimals, no fee on transfer, no owner and no proxy.

## Goals / Non-Goals

**Goals:**
- Each bear's amount per round, on-chain and readable with no proof and no backend.
- A claim only the bear's current owner makes, once per bear per round, in batches.
- $MNTD owed to holders can never be withdrawn while its round runs.
- The house pattern: Solady, solc 0.8.17, constructor-fixed addresses, two-step ownership, deterministic
  tests with a BTT tree, a deploy entry point with read-back, and Sourcify verification.

**Non-Goals:**
- the UI (MINT's);
- a Merkle tree or proof server;
- claims on a holder's behalf;
- eligibility by an owner snapshot;
- any link to `Activation` or the mystery box;
- any token other than $MNTD;
- other chains.

## Decisions

- **Amounts in storage, not a Merkle root.** 4,444 entries are about 50M gas on Robinhood Chain,
  sent in batches. The checker becomes `amountOf(round, id)`, which any explorer can answer, and MINT
  has no proofs to host. A Merkle root would save gas and nothing else; this chain's gas is cheap.
- **Rounds numbered by the contract, built one at a time.** Amounts can only be set on round
  `roundCount + 1`, and `openRound` makes it current. This avoids editing a round that is already open
  and keeps one `NotNextRound` rule. Opened rounds are independent and may overlap.
- **`owed` as a running sum, with an explicit close.** `openRound` adds the total and `claim` subtracts
  what it pays. `closeRound`, anyone's call after `end`, subtracts the rest. Withdrawal checks
  `balance - amount >= owed` in O(1), never looping over rounds. This mirrors `PrizeVault`'s `release`.
- **The owner-only claim pays the caller.** Paying `ownerOf` from anyone's call would push $MNTD into a
  contract that holds the bear and cannot move it (a marketplace escrow, a lending vault).
- **The whole batch reverts on the first bad id.** This is predictable for a wallet's simulation. The
  client filters already-claimed and zero-amount ids before it builds the call.
- **Deployed owned by Calea, then handed over.** About ten `setAmounts` batches come from Calea's
  deploying wallet, so MINT's admin does not have to send them. Solady's handover means MINT's admin
  must ask first, so ownership cannot land on an address nobody controls. The deployer holds no $MNTD
  in the contract, because MINT funds it after the handover.
- **`listHash` over the data, not the file bytes.** `keccak256(abi.encode(ids, amounts))` with ids
  sorted ascending. The script, the client and anyone with the list compute the same value whatever the
  CSV's line endings or decimals formatting.
- **The pause stops claims only** and never moves `end`, as `PrizeVault`'s does. Closing and
  withdrawal carry on, so a paused contract cannot lock MINT's leftovers.

## Risks / Trade-offs

- **A wrong list.** Bad amounts are fixed at `openRound`. Mitigations: `check` against MINT's CSV and
  checksum before the handover, MINT's own read of the `listHash`, and the testnet run. Recovery: pause,
  let the round run out, close it, and open a corrected round. The reserved $MNTD is not lost.
- **Owner key.** The owner can withdraw only what nobody is owed, and can pause claims until `end`. A
  lost owner key strands only the unowed balance.
- **A bear in a contract that cannot call `claim`** (a lending vault, an account with no code on this
  chain) cannot claim until it leaves. Its share returns at close.
- **A long window** keeps $MNTD reserved for longer (CQ-27).
- **No external review by default** (CQ-28).

## Migration Plan

Nothing live changes. The order is: testnet 46630 with test $MNTD `0x15CF…`, through deploy, load,
check, handover, fund, open, claim, transfer and claim, close and withdraw; then mainnet 4663 on
13–14 November; then MINT funds and opens. Rollback before opening: do not fund, and redeploy. After
opening: the recovery described under Risks.
