# Design

## Context

MINT's answers of 28 September 2026 (the call on O1–O9) and the follow-up the same day.

## Decisions

- **Cycles on both chains, set by the owner.** `MysteryBox` enforces the window and the one shot
  per bear per cycle. `PrizeDraw` needs only each cycle's prize count and list hash, so that it
  can run its counters, and it gets them from the owner's own call. Both emit `CycleScheduled`,
  so a mismatch is public. The alternative, the worker relaying the schedule, would give the
  worker a say in the odds.
- **One `openIndex` sequence across cycles.** The in-order rule (RAF-29) works as it did, and
  each open carries its cycle id. `PrizeDraw` refuses a cycle it does not know, or one earlier
  than the last it resolved.
- **Exclusions frozen at the first `scheduleCycle`.** "Fixed for good" (MINT). `PLAYABLE` is then
  `PrizeDraw`'s constructor argument.
- **No vaults.** MINT holds the prizes in an EOA and pays by transfer. So nothing on-chain
  guarantees a payout, and CQ-11's "nothing leaves while live" rule cannot be enforced; CQ-11 is
  closed as superseded. What stays checkable is the record: every win is an `OutcomeRecorded`,
  and every payout a `PrizePaid` naming the chain and the transaction.
- **The payout is pushed by default.** CQ-22 is open. Pushing needs no claim window and no
  holder action, which also suits OPS-7's rule that nothing depends on a holder acting by a
  deadline.
- **Status link removed.** MINT tracks it against the Privy account. `Activation` keeps the
  levels that MINT's Status reads.

## Risks

- The owner `0x1530…` is one EOA for every contract (assumed). The accepted risk "the owner can
  add a minter" loses its Safe mitigation.
- A prize list published off-chain can differ from what the wallet holds. The hash fixes the
  list, not the funds.
- A worker operated by Calea after 19 November is a service outside the SoW (CQ-23, DEL-10).
