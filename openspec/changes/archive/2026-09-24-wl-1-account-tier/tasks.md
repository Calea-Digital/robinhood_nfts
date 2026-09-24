# Tasks

## 1. Specification

- [ ] 1.1 Archive this change into `openspec/specs/whitelist/spec.md`; verify WL-1 keeps its `**Kind:** work-item` line with the spec lint
- [ ] 1.2 Re-render `docs/SPECIFICATION.md`; verify the generated-prose check passes
- [ ] 1.3 Commit, then run `docs/tools/board.sh` (preview with `--dry` first); verify the MNT WL-1 Task body carries the new statement

## 2. Tree

- [ ] 2.1 `test/WhitelistClaim.tree.md` WL-1 note: the dollar amounts have no leaf, the account's tier order does (WL-3 claim tree, `test/poc/TierAcrossWallets.t.sol`); verify `forge test` unchanged
