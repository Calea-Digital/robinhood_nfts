# Design

## Context

The architecture is fixed by the specification and by `docs/HANDOVER.md`: the box runs in cycles;
`MysteryBox` (4663) never decides anything; `PrizeDraw` (Arbitrum One) refuses an open out of turn
so the worker cannot choose which open meets which state of the pool; prizes stay in MINT's
wallet and only the payout is recorded. `solc 0.8.17` and `london` apply to every contract in the
package (SeaDrop's exact pragma), so any dependency must compile there.

## Goals / Non-Goals

**Goals:** every Task's `Done when` has a passing deterministic test; coverage stays at or above
the gate; the build stays warning-free; Slither reports no High or Critical.

**Non-Goals:** the deploy entry points, the runbook and the client calls (later Tasks); fuzz and
invariant harnesses (the internal auditor's); anything on a prize chain.

## Decisions

- **Solady `Ownable`, owner set in the constructor, two-step handover only, `renounceOwnership`
  reverts**, as `Activation` does (ACT-12), on both contracts. A one-step transfer to an address
  nobody controls would strand a paused box.
- **`MysteryBox` reads the collection through `IMintABear`** (`ownerOf`), like `Activation`; the
  collection never calls the box.
- **Chainlink VRF v2.5 through a minimal local interface** (the coordinator's
  `requestRandomWords` with its request struct, and the v2.5 extra-args encoding), decided in
  RAF-8's claim after checking the official package's pragmas against 0.8.17.
- **Outcomes applied in order as words arrive:** a word for a later open waits in storage until
  every earlier open's word has been applied.

## Risks / Trade-offs

- A wallet's shots left are counted by the client library from per-bear reads in one Multicall3
  call; the hub has no per-wallet read, since a scan of the collection costs about 23M gas.
- One VRF request per open is a real cost, accepted in HANDOVER.
