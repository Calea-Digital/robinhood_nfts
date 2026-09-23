# Tasks

## 1. Specification

- [ ] 1.1 Archive this change into `openspec/specs/operations/spec.md`; verify OPS-2 keeps its `**Kind:** work-item` line with the spec lint
- [ ] 1.2 Re-render `docs/SPECIFICATION.md`; verify the generated-prose check passes
- [ ] 1.3 Commit, then run `docs/tools/board.sh` (preview with `--dry` first); verify the MNT OPS-2 Task body carries the new Scenario

## 2. Implementation

- [ ] 2.1 `script/Deploy.s.sol` and its unit test follow the amended order; verify with `forge test --match-contract Deploy`
