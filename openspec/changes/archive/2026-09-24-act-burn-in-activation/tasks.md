# Tasks

## 1. Specification

- [ ] 1.1 Archive this change; verify every modified requirement keeps its `**Kind:**` line and the three renames land (spec lint)
- [ ] 1.1b In the same commit, retitle four Scenarios in `openspec/specs/activation/spec.md` by hand — the validator refuses a Scenario title change in a MODIFIED delta: ACT-1 "One token, one collection", ACT-4 "A burn is recorded once", ACT-7 "Record and burn in one transaction", ACT-11 "Pause closes burns and links only" (reviewer's choice, 2026-09-24)
- [ ] 1.2 Fold the decisions delta into `openspec/decisions.md` (CQ-2, CQ-3, CQ-12); bump `openspec/config.yaml` `spec_version` to 2.2
- [ ] 1.3 `docs/SPECIFICATION.md` narrative outside the generated blocks: six contracts, no `DirectBurnAdapter` (§1, the contract table, the flow), version line 2.2; re-render; verify the generated-prose check passes
- [ ] 1.4 Commit, then `docs/tools/board.sh` (`--dry` first); verify the MNT Task bodies of the modified requirements carry the new text

## 2. Contract

- [ ] 2.1 `src/Activation.sol`: constructor `(bears, mntd, thresholdsWhole, weights)` reading `decimals` and scaling with `SafeCastLib`; `burn` with `nonReentrant` and the five refusals in order, record then `burnFrom`; `DECIMALS`, `MNTD`; `renounceOwnership` reverts; `credit`, `crediter`, `setCrediter`, refs and their errors and events removed
- [ ] 2.2 Delete `src/DirectBurnAdapter.sol`

## 3. Tests

- [ ] 3.1 `test/Activation.t.sol`: the adapter's tests moved in; each modified requirement's Scenario test quotes its new text; hostile-token tests assert the reentrancy refusal; ACT-12 pins one interface
- [ ] 3.2 Delete `test/DirectBurnAdapter.t.sol` and its tree; `test/Activation.tree.md` takes INV-15 and INV-16 and the numbering header follows in every tree
- [ ] 3.3 `test/poc/`: the owner cannot record a level without a burn — `setCrediter` and `credit` are absent
- [ ] 3.4 `script/Deploy.s.sol`, `script/config/example.json`, `test/Deploy.t.sol` and its tree: no adapter, no `setCrediter`, no `mntdDecimals`; verify with the full gates

## 4. Documentation

- [ ] 4.1 `CLAUDE.md`, `README.md`, `docs/HANDOVER.md` (contracts, decisions not to relitigate, accepted risks, portal notes), `docs/RUNBOOK.md`, `openspec/config.yaml` context: six contracts, `Activation` burns $MNTD; verify no text still names the adapter or the crediter
