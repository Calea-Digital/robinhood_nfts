# MintABear: response to the security audit

- **Report:** `audit/Mint-Security-Audit-Report.md` (branch `audit/security-review`, commit
  `446e999`), reviewing `tranche-1` at `8429298`.
- **Response date:** 2026-10-06.
- **Fixes:** on `tranche-1`, merged `--no-ff`, one Defect per finding on the YouTrack board (MNT).

| ID | Severity | Status | Defect | Merge |
|---|---|---|---|---|
| L-01 | Low | Fixed | MNT-147 | `1b6e547` |
| L-02 | Low | Fixed | MNT-148 | `401df52` |
| L-03 | Low | Fixed | MNT-149 | `d2b7ac0` |
| I-01 | Informational | Acknowledged, documented; root check scheduled | MNT-150 | `aa0b3c3` |
| I-02 | Informational | Fixed | MNT-151 | `7c8219a` |
| I-03 | Informational | Fixed | MNT-152 | `3f41109` |

We confirmed every finding against the reviewed commit.

## [L-01] A single-step ownership transfer can leave `Activation` paused permanently: Fixed

We took a stronger approach than the one recommended. `Activation` is now constructed already
configured and owned by the admin, so the deploy hands nothing over, and single-step transfer is
removed entirely.

- **Constructor.** It is now `Activation(owner, bears, mntd, thresholdsWhole, weights)`. A zero
  owner is refused with `NewOwnerIsZeroAddress`. The contract is paused from construction and emits
  `PausedSet(true)`. `script/Deploy.s.sol` calls nothing after construction, so the deployer never
  owns `Activation`.
- **Ownership.** `transferOwnership` reverts with `TwoStepHandoverOnly` for every caller. Ownership
  moves only through Solady's `requestOwnershipHandover`, sent by the new owner, followed by the
  owner's `completeOwnershipHandover` within 48 hours. The external interface is unchanged, and the
  ACT-12 interface pin still lists 21 functions.
- **Runbook.** `docs/RUNBOOK.md` now has "Rotating the owner" and a proof-of-control step at
  deployment.
- **Specification.** ACT-12, ACT-15 and OPS-2 are updated (OpenSpec change
  `act-two-step-ownership`).
- **Validation.**
  - `test/poc/WrongAdminRotation.t.sol` keeps the report's scenario inverted. While paused, ownership
    sent by either route to an address that never asked for it reverts, the owner can still
    unpause, and levels stand.
  - Unit tests cover construction, a zero owner, transfer refused for owner and stranger, a
    completed handover, and an expired request.
  - The self-review is in `reports/act-12-audit-l01-diff-review.md`.

## [L-02] `buildAllowList` accepts a wallet listed twice: Fixed

- **Client.** `buildAllowList` refuses a wallet that appears in more than one row, compared without
  regard to case, with `ClientRefusal` code `DUPLICATE_WALLET`. The code is in the error table.
- **`compare`.** Its CSV mode (`tasks.md` 2.6, MNT-141) carries the same refusal as a requirement.
- **Runbook.** It no longer claims a repeated wallet mints under one row only.
- **Validation.** A vitest case lists a wallet twice, once as written and once in another case,
  and both lists are refused.

## [L-03] The split's events mode checks presence, not current ownership: Fixed

- **Client.** `rowsFromEvents` reads `ownerOf(id)` at the closing block alongside `weightOf`. If a
  bear's last recipient in the logs differs from its on-chain owner, it refuses with
  `SPLIT_OWNER_MISMATCH`, naming the id, both addresses and the block.
- **Validation.**
  - A vitest case uses a transport that drops the resale `Transfer` of one bear. Every bear is still
    present, but the call is refused.
  - With the comparison disabled, the case fails.

## [I-01] The registries are unused and the live whitelist has no root check: Acknowledged

- **Registries.** `WhitelistClaim` and `WhitelistImport` stay in the repository as an undeployed
  fallback, in case the whitelist returns on-chain. `docs/RUNBOOK.md` and the client README now say
  so explicitly.
- **Root check.** The check of Studio's root against MINT's final CSV is scheduled before the
  whitelist freeze (27 October): `compare`'s CSV mode is `tasks.md` 2.6 (MNT-141), and the client's
  CSV path is 6.2 (MNT-143).

## [I-02] `IBurnableMNTD` is declared inside `Activation.sol`: Fixed

The interface now lives in `src/interfaces/IBurnableMNTD.sol`, with NatSpec. The ABI is
unchanged.

## [I-03] Source comments mix process notes and project references into the NatSpec: Fixed

- **NatSpec.** In `MintABear`, `IMintABear` and `Activation` it now states only behaviour,
  parameters and errors. We removed the Slither output, specification ids, names of people,
  products and services, example values and design history.
- **Stale line.** The outdated Status-link sentence on `IMintABear.transferNonce` is corrected.
- **Design notes.** The rationale moved to `docs/DESIGN.md`.
- **Out of scope.** The undeployed registries were not changed.

## State after the fixes

- **Forge:**
  - `forge fmt --check` is clean.
  - `forge build --sizes` has no warnings.
  - `forge test` passes 235/235, including under `FOUNDRY_PROFILE=ci`.
  - Coverage is 100% for lines, statements, branches and functions.
- **Slither:** no High or Critical. The three accepted `locked-ether` Mediums are unchanged and are
  explained in `docs/DESIGN.md` and `docs/HANDOVER.md`.
- **Client library:** `check:abi`, typecheck, build and vitest (127/127) all pass.
