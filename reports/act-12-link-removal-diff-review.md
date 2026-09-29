# Differential review — ACT-12 (MNT-142): the Status link removed

Diff: `git diff tranche-1...779cd9b` on `mnt/ACT-12-link-removal`; 24 files, +146 / −872.
Strategy: DEEP (one contract changed; every changed file read). Reviewer: Claude Code, self-review
under `/mnt:done` step 2. Date: 2026-09-29.

## Scope and risk triage

| File | Risk | Why |
|---|---|---|
| `src/Activation.sol` | HIGH (by rule: role surface, removal) | functions, events, storage and a modifier removed |
| `test/Activation.t.sol`, `test/Activation.tree.md` | LOW | tests and tree follow the contract |
| `packages/contracts-client/src/*` | MEDIUM | public API of the library narrowed; off-chain |
| `packages/contracts-client/src/abi/activation.ts` | LOW | generated; `check:abi` passes |
| `CLAUDE.md`, `docs/HANDOVER.md`, client README, examples, tree | LOW | prose |

## Contract analysis

- **Removed:** `linkBear`, `unlinkBear`, `linkOf`, `BearLinked`, `BearUnlinked`, `_linkedBear`,
  `_linkedAtNonce`, and `whenNotPaused` (its only user was `linkBear`). Nothing else in `src/`,
  `script/` or `test/poc/` referenced them (grep).
- **Burn path unchanged:** no line of `burn`, `_requireNotPaused`, `cumulativeOf`, `levelOf`,
  `weightOf`, `snapshot`, `costToReach`, `thresholdFor`, `weightFor` or `_levelFor` changed. The
  check order `ContractPaused`, `ZeroAmount`, `NotBearOwner`, `AlreadyAtMaxLevel`, `Overshoot`,
  record-then-`burnFrom` and `nonReentrant` stand.
- **Pause and owner surface:** `setPaused` keeps `onlyOwner`; `renounceOwnership` still reverts
  `RenounceDisabled`; no function gained or lost an access check. The pause now gates `burn`
  alone, which is ACT-15's statement. The ACT-12 pin (21 functions, no fallback, no receive)
  confirms the surface from the artifact.
- **Storage:** `_records` 0, `lifetimeBurned` 1, `paused` 2 (`forge inspect`). Solady's `Ownable`
  and `ReentrancyGuard` keep their state in fixed hashed slots, so nothing collides.
  `Activation` is not upgradeable and not deployed, so the shift of `paused` from slot 4 to 2
  migrates nothing.
- **Git history of removed code:** the link code came from ACT-9 and its review fixes (the
  nonce pin that voids a link on transfer, unlink allowed while paused). Those fixes protected
  the link only; with the feature gone they have nothing left to protect. No other security fix
  is reverted.

## Client analysis

`readLink`, `linkCall`, `unlinkCall`, `readLinkStatus`, `linkPrompt`, `LINK_REVERTS`, the
facade's `bears.link/unlink/linkOf/linkStatus/linkPrompt`, the indexer's `links`/`linkOf`, and the
`NOT_LINKED` / `VOIDS_LINK` warnings are removed. `planBurn` and `planTransfer` make one read
fewer and still return every refusal the contract would make. This breaks the library's types for
anyone who used the link API. Nobody has: nothing is deployed and MINT has not integrated.

## Test coverage

229 contract tests and 125 client tests pass; coverage is 100% line, branch and function. The 13
contract tests and 8 client tests removed tested only the link. ACT-5, ACT-13 and ACT-15 now quote
their Scenarios verbatim (`check_scenario_quotes.py`: 6 failures left, all WL registry blocks and
DEL-6, which belong to `tasks.md` 2.6 and 6.2).

## Blast radius

On-chain: `MintABear` never calls `Activation`, so nothing there changes. Off-chain: the client
library (updated here) and MINT's future indexer, which keys on `BearActivated` and
`TransferNonceAdvanced`, both still emitted.

## Findings

None. Slither shows no new High or Critical: the 3 accepted `locked-ether` Mediums are unchanged.

## Limits

Self-review by the author of the change. The auditor's fork and invariant obligations (INV-4, 5,
7, 9, 15, 16; Fork-3) are unchanged, and INV-8 is retired with the link.
