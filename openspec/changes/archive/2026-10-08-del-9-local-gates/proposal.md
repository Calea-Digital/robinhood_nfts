# Proposal

## Why

DEL-9 says CI in MINT's repository builds, formats and tests the contracts. The repository has no
CI, by decision: Calea runs the gates locally before every pull request into the staging branch,
and re-runs them at review. DEL-9's Scenario names CI, so it can never be met as written.

## What Changes

- DEL-9 states where the gates run: locally, by Calea, before every pull request into the staging
  branch, and nowhere in the repository's CI.
- `pnpm -r build|test|check` still reach the Foundry package through its thin `package.json`.
- CQ-14 records the same, dated.

## Capabilities

### Modified Capabilities

- `deliverables` (DEL): DEL-9.

## Impact

`openspec/specs/deliverables/spec.md`, `openspec/decisions.md` (CQ-14), the generated
`docs/SPECIFICATION.md` and `docs/OPEN-QUESTIONS.md`, and the board (MNT-71's body). No code changes.
The `pnpm -r` clause is met when the client joins the pnpm workspace, which carries
`packages/contracts/package.json`.
