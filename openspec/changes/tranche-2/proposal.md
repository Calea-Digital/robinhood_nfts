# Proposal

## Why

Tranche 2 is the mystery box: `MysteryBox` on Robinhood Chain runs the cycles and records
openings, and `PrizeDraw` on Arbitrum One decides each opening with its own Chainlink word and
records wins and payouts. The specification is final (RAF-8, RAF-14, RAF-16…RAF-19,
RAF-27…RAF-30, RAF-32…RAF-34). The code is written against the defaults of the open decisions so
that the internal auditor can take the tranche, and so that `PrizeDraw` can be deployed once
MINT answers (CQ-17, CQ-20, CQ-22, CQ-23, all needed by 12 October).

## What Changes

- `MysteryBox` is new: team-bear exclusions frozen at the first cycle, owner-scheduled cycles,
  `open` with one shot per bear per cycle, pause, events and reads.
- `PrizeDraw` is new: the cycle terms mirrored from the hub, `resolve` strictly in `openIndex`
  order, one VRF v2.5 word per open, the win rule `(w mod idsLeft) < prizesLeft`, the payout
  record, pause, events and reads.
- Trees and deterministic tests per contract; INV-N and Fork-N obligations documented for the
  auditor.

## Capabilities

### Modified Capabilities

(none at the specification level — this change implements requirements that already stand
in `openspec/specs/`; `skip_specs: true`)

## Impact

`packages/contracts/src/`, `test/` in `mintdotio/NFT`, on Task branches off `feat/contracts`.
The deploy entry points, the runbook sections and the client library's admin-page and worker
calls follow in later Tasks. YouTrack project MNT: the RAF Tasks move Open → In Progress →
In Review → Done.
