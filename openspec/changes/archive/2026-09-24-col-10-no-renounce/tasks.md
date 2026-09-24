# Tasks

## 1. Specification

- [ ] 1.1 Archive this change into `openspec/specs/collection/spec.md`; verify COL-10 keeps its `**Kind:** work-item` line with the spec lint
- [ ] 1.2 Re-render `docs/SPECIFICATION.md`; verify the generated-prose check passes
- [ ] 1.3 Commit, then run `docs/tools/board.sh` (preview with `--dry` first); verify the MNT COL-10 Task body carries the new Scenario

## 2. Implementation

- [ ] 2.1 `src/MintABear.sol`: override `renounceOwnership` to revert for every caller; verify with `forge test --match-contract MintABearOwnershipTest`
- [ ] 2.2 `test/MintABear.t.sol` and `test/MintABear.tree.md`: the COL-10 Scenario test quotes the new AND clause; the owner's `renounceOwnership` reverts with an offer pending and the owner and offer are unchanged; a non-owner's reverts too; verify the Scenario-quote check and the tree leaf
- [ ] 2.3 `CLAUDE.md` "Ownership (COL-10)" and `docs/RUNBOOK.md` state the refusal; verify no text still says renouncing is possible
