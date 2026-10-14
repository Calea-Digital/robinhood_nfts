# Proposal

## Why

MINT confirmed in the meeting of 12 October 2026 that `0x153052B43c8fD4ec01f14D1Edd8660778daa6141`
owns every contract on every chain: `MintABear`, `Activation` and `MysteryBox` on Robinhood Chain,
`PrizeDraw` on Arbitrum One. A multisig may take over later. CQ-12 is resolved.

## What Changes

- **OPS-1**: the admin row no longer waits on a confirmation, and the technical note says a move
  to a multisig goes through each contract's two-step handover.
- **CQ-12** is resolved; it no longer gates OPS-1, OPS-2 or COL-10. The worker's address stays
  with CQ-23.

No requirement is added or retired, and no Scenario changes. No code changes: every contract
already supports the two-step move.
