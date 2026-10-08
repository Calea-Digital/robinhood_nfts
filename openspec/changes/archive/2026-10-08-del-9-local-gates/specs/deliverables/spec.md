# Spec Delta

## MODIFIED Requirements

### Requirement: DEL-9 — Repository
**Kind:** work-item
The contracts go into MINT's repository, `github.com/mintdotio/NFT`, as their own package beside
the client library (MINT, 28 and 29 September 2026). The repository has no CI for them: Calea
builds, formats and tests them locally before every pull request into the staging branch, and
again at review. The contracts go in as each tranche is accepted. The client library's mint and
whitelist calls, and the whitelist check (WL-4), are needed before the whitelist stage.

*Technical note.* `https://github.com/mintdotio/NFT`: `packages/contracts` (`@mint/contracts`)
beside `packages/contracts-client`. `packages/contracts` is a Foundry package with a thin
`package.json`, so `pnpm -r build|test|check` reach it, and its Foundry dependencies are git
submodules. The local gates are `forge fmt --check`, `forge build --sizes` with no warning,
`forge test`, the coverage gate and Slither, run before every pull request into `release/1.1`
(CQ-14).

#### Scenario: The package sits in the monorepo
- **WHEN** the contracts land in the monorepo
- **THEN** `pnpm -r build|test|check` reach the Foundry package and the forge gates pass locally before every pull request into the staging branch
