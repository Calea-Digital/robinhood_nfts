# Proposal

## Why

MINT keeps one wallet as admin for now and may move every contract to a multisig later (CQ-12,
12 October 2026). The runbook has owner-rotation steps for `MintABear` and `Activation` only;
`MysteryBox` and `PrizeDraw` have none. Found in the integrity check of 14 October (IC-Q2-1).

## What Changes

- **OPS-5**: the runbook also covers moving each contract's ownership to a new owner, all four
  contracts, including as a Safe proposes the steps.

No requirement is added or retired, and no Scenario changes. The runbook edit itself is OPS-5's
work in `../NFT`.
