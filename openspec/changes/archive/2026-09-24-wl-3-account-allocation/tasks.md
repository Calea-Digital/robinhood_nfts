# Tasks

## 1. Specification

- [ ] 1.1 Archive this change into `openspec/specs/whitelist/spec.md`; verify WL-3 keeps its `**Kind:** work-item` line with the spec lint
- [ ] 1.2 Re-render `docs/SPECIFICATION.md`; verify the generated-prose check passes
- [ ] 1.3 Commit, then run `docs/tools/board.sh` (preview with `--dry` first); verify the MNT WL-3 Task body carries the new Scenario

## 2. Implementation

- [ ] 2.1 `src/WhitelistClaim.sol`: `WrongAllocation` against `accountClaims(account) + 1`, `AccountLimit` before it, `renounceOwnership` reverts; verify with `forge test --match-path test/WhitelistClaim.t.sol`
- [ ] 2.2 Tests and trees: vouchers numbered by account; the Scenario test quotes the new AND clause; the two-wallets-one-tier case inverted in `test/poc/`; the check-order test follows; verify the Scenario-quote check and the tree leaves
- [ ] 2.3 `CLAUDE.md`, `docs/HANDOVER.md`, `docs/RUNBOOK.md` state the account's numbering and the refusal; verify no text still says the index is the wallet's
