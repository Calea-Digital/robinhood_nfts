# Tasks

## 1. Specification

- [ ] 1.1 Archive into `openspec/specs/whitelist/spec.md`; verify WL-7 keeps `**Kind:** work-item` with the spec lint
- [ ] 1.2 Re-render `docs/SPECIFICATION.md`; add WL-7 to `openspec/changes/tranche-1/tasks.md`; commit; `docs/tools/board.sh`

## 2. Implementation (MNT Task for WL-7)

- [ ] 2.1 `src/WhitelistImport.sol` with its tree and deterministic tests at 100% line and branch coverage
- [ ] 2.2 `Deploy.s.sol` `runWhitelistImport`, `WhitelistExport.s.sol` over either registry, tests
- [ ] 2.3 DEL-6 client module `whitelistImport` (CSV parse, batching, owner calls, reads), ABI regenerated, tests
