# Tasks

## 1. Specification

- [ ] 1.1 Archive this change into `openspec/specs/activation/spec.md` (`/opsx:archive`); verify ACT-5 keeps its `**Kind:** work-item` line with the spec lint
- [ ] 1.2 Re-render `docs/SPECIFICATION.md` (`docs/tools/spec_tools/render_calea_prose.py`); verify the generated-prose check passes
- [ ] 1.3 Commit, then run `docs/tools/board.sh`; verify the MNT ACT-5 Task body carries the new Scenario

## 2. Test

- [ ] 2.1 The ACT-5 Scenario test in `test/Activation.t.sol` asserts `weightOf == weightFor(0)` after the transfer, with the tree leaf citing ACT-5; verify with `forge test --match-contract ActivationResetTest`
