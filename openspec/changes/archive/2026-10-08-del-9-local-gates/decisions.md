# Decisions Delta

## RESOLVED Decisions

### CQ-14 — Monorepo placement and CI
- **Statement:** Monorepo and CI
- **State:** resolved
- **Status note:** MINT, 29 September 2026; repository named; no CI, 8 October 2026
- **Rationale:** the repository is `https://github.com/mintdotio/NFT`, with Calea's layout: `packages/contracts` as `@mint/contracts` beside `packages/contracts-client`, Foundry dependencies as git submodules. Calea runs the gates locally before each pull request; the repository has no CI for the contracts.
- **Blocks:** DEL-9

**Recorded as (8 October 2026).** No CI in the repository; Calea runs the gates locally before
each PR (DEL-9).
