# Proposal

## Why

Specification v2.1 is the contract; the code on `main` predates it and is the input to
tranche 1, not the output. Tranche 1 takes `MintABear`, `WhitelistClaim`, `Activation` and
`DirectBurnAdapter` from what is on `main` to what the specification says, with the deploy
scripts, the runbook material and the rehearsal that go with them, so the internal auditor
can take the tranche and MINT can run the whitelist campaign and the mint on the dates §8
anchors.

## What Changes

- ERC-6551 and the placeholder renderer leave `MintABear` (COL-9, COL-5); the reset event and
  `exists()` arrive (COL-4, COL-12); burn refusal, supply cap and validator-at-deploy stay.
- `WhitelistClaim` is new (WL-3, with WL-1, WL-4, WL-5).
- `Activation` is rewritten against ACT-1…ACT-14; `DirectBurnAdapter` is new (ACT-7, ACT-8).
- Deploy, configuration and verification scripts per OPS-2, OPS-3, OPS-6; testnet rehearsal
  per OPS-4.
- Trees, tests and `CLAUDE.md` rewritten against the requirement ids.

## Capabilities

### Modified Capabilities

(none at the specification level — this change implements requirements that already stand
in `openspec/specs/`; `skip_specs: true`)

## Impact

`src/`, `test/`, `script/`, `CLAUDE.md`, `docs/HANDOVER.md`. YouTrack project MNT: the
requirement Tasks the ids below name move Open → In Progress → In Review → Done.
