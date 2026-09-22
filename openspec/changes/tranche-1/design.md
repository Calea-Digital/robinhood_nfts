# Design

## Context

The architecture is fixed by the specification and by the decisions in `docs/HANDOVER.md`
that are not to be relitigated: the transfer counter (never a callback), `Activation` never
touching the token, one `crediter`, the adapter as the same-chain burn route, `solc 0.8.17`
forced by SeaDrop, the validator set at deploy with a one-call fallback.

## Goals / Non-Goals

**Goals:** every tranche-1 requirement Task's `Done when` has a passing deterministic test;
coverage stays at or above the gate; `forge build --sizes` warning-free; Slither without High
or Critical.

**Non-Goals:** tranche 2 (`MysteryBox`, `PrizeDraw`, `PrizeVault` — waits on CQ-20); the
TypeScript client library (DEL-6, its own change); fuzz or invariant harnesses (the auditor's).

## Decisions

- `decimals` (CQ-2, follow-up) is a constructor value, not structure: `Activation` takes
  thresholds in base units; the deploy script converts from whole $MNTD once `decimals` is
  confirmed. Code proceeds; the deploy value waits.
- Each requirement is picked in `tasks.md` order (below); the coding unit is whatever the
  requirement needs, and neighbouring requirements satisfied by the same file are ticked
  when their own Scenario has a passing test.

## Risks / Trade-offs

- OpenSea's handling of a validated collection on 4663 is unobserved (COL-7): proven on
  testnet, then by one team-bear sale — a rehearsal step, not code.
- `WhitelistClaim` must be live before the campaign (WL-5, proposed 6 October): it is first
  after the `MintABear` cleanup in the order below.
