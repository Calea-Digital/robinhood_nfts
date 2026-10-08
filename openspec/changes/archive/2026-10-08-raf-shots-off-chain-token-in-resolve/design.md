# Design

## Context

`MysteryBox` (4663) is built through RAF-27: cycles, exclusions, and an `open` that refuses
`CycleNotOpen`, `NotBearOwner`, `IdExcluded` and `AlreadyOpened`, keyed on `(cycleId, tokenId)`.
`PrizeDraw` (Arbitrum One) is not written. Robinhood Chain has no cross-chain messaging, so the
draw learns of an opening only from the worker's relay.

Measured on the tranche-2 branch (a throwaway test: 222 team bears, then 2,111 wallets of 2): a
read that asks the collection for the owner of all 4,444 ids costs 23,114,866 gas. Multicall3
(`0xcA11bde05977b3631167028862bE2a173976CA11`) has code on 4663 and on 46630 (read with `cast code`,
8 October 2026).

## Goals / Non-Goals

**Goals:** no read whose cost grows with the collection; every result traceable to the bear that
opened; the draw's per-cycle accounting cannot be driven below zero or count a bear twice,
whatever the worker relays.

**Non-Goals:** proving on Arbitrum that an opening happened on 4663 (no messaging endpoint on
4663, HANDOVER); verifying exclusions on the draw; any change to `open`'s rules.

## Decisions

- **Shots left off-chain, from per-bear reads.** Alternatives weighed:
  - *A full scan on the hub* (the spec's `shotsLeft(wallet)`): 23M gas per read, near common RPC
    read limits. Rejected.
  - *A per-wallet counter on the hub*: the hub is not told of transfers (the collection never
    calls it, COL-3), so the count would be wrong after any sale. Rejected.
  - *`shotsLeft(wallet, tokenIds)` on the hub, the ids supplied by the page*: bounded and verified,
    but new contract surface for what Multicall3 already does. Rejected.
  - *The client library batches `ownerOf`, `isExcluded` and `opened` per bear in one Multicall3
    call*: chosen. Ownership is read on-chain, so a stale indexer list undercounts a bear just
    received and never counts a bear sold; the open itself is unaffected.
- **`tokenId` in `resolve`, with three refusals on the draw.** `InvalidTokenId` (outside 1 to
  `MAX_BEARS`) and `AlreadyResolved` (a per-cycle bitmap) mirror what the hub already guarantees,
  so an honest relay never meets them and the in-order queue cannot stall on them.
  `CycleExhausted` (`idsLeft == 0`) makes the win rule's `w mod idsLeft` safe on any input. The win
  rule reads neither `tokenId` nor `opener`, so carrying them cannot bias an outcome.
- **The worker relays from sequencer-confirmed blocks**, not after Ethereum finality: the outcome
  stays near-instant; a reorg that drops a relayed open leaves an `OutcomeRecorded` with no
  `BoxOpened`, which is visible.
- **The draw does not hold the exclusions.** Giving it the ranges would duplicate a deployment
  value that must then match the hub's; `PLAYABLE`, `AlreadyResolved` and `CycleExhausted` bound
  the damage instead.

## Risks / Trade-offs

- **The worker can still invent an opening.** Nothing on Arbitrum can prove a `BoxOpened`. After
  this change an invented relay must name a real id at most once per cycle, cannot take the pool
  below zero, and is visible as an `OutcomeRecorded` whose `(openIndex, cycleId, tokenId, opener)`
  matches no `BoxOpened`. It also breaks the index sequence, so the next real opening's relay is
  refused `OutOfOrder` until the operator intervenes. Accepted as the worker's trust (CQ-23).
- **An invented relay for an excluded id** consumes one of the cycle's `idsLeft` and shifts the
  odds slightly. Visible the same way; accepted.
- **Gas on Arbitrum** rises by one storage write per resolve (the bitmap), small against the VRF
  request each resolve already pays for.
- **The shots-left count depends on the page's indexer** for the list of bears. It is display
  only and errs low, never high.

## Migration Plan

None: nothing is deployed, and `PrizeDraw` is not written. `MysteryBox` never had `shotsLeft`.
