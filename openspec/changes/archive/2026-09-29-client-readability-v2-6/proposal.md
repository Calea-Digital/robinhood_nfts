# Proposal

## Why

The client document is written for MINT's decision-makers and has grown hard to read. This change
collects the edits of a section-by-section review into specification v2.6. The same review
records two decisions of 29 September 2026: MINT named its repository (CQ-14), and Calea withdrew
the existing-contract review (CQ-13), its review work being the internal audit of its own
contracts, tranche 1's on 30 September and 1 October.

## What Changes

- §10: the open items are listed soonest first, each with what it is, what it holds up and
  Calea's fallback; the client document's generated table of open questions is removed, and the
  builder checks the items against the register.
- CQ-14 resolved: the repository is `https://github.com/mintdotio/NFT`. MODIFIED DEL-9 and DEL-11.
- CQ-13 closed as withdrawn. REMOVED DEL-7. MODIFIED DEL-10 (the review is not a commercial item).
- Further section edits, as the review reaches them.

## Capabilities

### Modified Capabilities

- `deliverables` (DEL); others as the review reaches them.

## Impact

- `docs/SPECIFICATION.md` narrative (§1, §8, §10), `openspec/decisions.md`,
  `docs/tools/build_client_doc.py`, the client document v2.6.
- Board: the Task for DEL-7 is canceled by the human; DEL-9's Task is unblocked.
