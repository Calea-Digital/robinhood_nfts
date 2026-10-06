# Tasks

## 1. Spec

- [ ] 1.1 Lint the delta; archive; render the prose; commit; board (verify: `board.sh` read-back passes)

## 2. Code (MNT-147, branch `mnt/ACT-12-audit-l01`)

- [ ] 2.1 `Activation`: owner as the first constructor argument (zero refused), paused from construction, `transferOwnership` reverts `TwoStepHandoverOnly` (verify: new ACT-12 and ACT-15 tests)
- [ ] 2.2 `Deploy.s.sol` `deployActivation`: no call after construction (verify: `test/Deploy.t.sol`)
- [ ] 2.3 Tests, trees, `test/poc/WrongAdminRotation.t.sol`; runbook rotation procedure; CLAUDE.md; client ABI and fixture (verify: forge gates, client suite)
