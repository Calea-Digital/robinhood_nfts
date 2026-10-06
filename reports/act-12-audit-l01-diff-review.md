# Differential review: ACT-12 (MNT-147), Activation's two-step ownership (audit L-01)

- **Diff:** `git diff tranche-1..688772b` on `mnt/ACT-12-audit-l01`. 21 files, +408 / −63. That
  includes the archived OpenSpec change and the rendered specification.
- **Strategy:** DEEP. One contract and the deploy script changed, and every changed file was read.
- **Reviewer:** Claude Code, self-review. **Date:** 2026-10-06.

## Scope and risk triage

| File | Risk | Why |
|---|---|---|
| `src/Activation.sol` | HIGH (by rule: role surface) | The constructor gains the owner and an initial pause. `transferOwnership` is overridden. |
| `script/Deploy.s.sol` | HIGH (by rule: deployment roles) | The calls after construction are removed. |
| `test/*`, the trees, `test/poc/WrongAdminRotation.t.sol` | LOW | The tests follow the contract. |
| `packages/contracts-client/src/abi/activation.ts`, `test/setup/fixture.ts` | LOW | The ABI is generated (`check:abi` passes); the fixture is test-only. |
| `openspec/`, `docs/`, `CLAUDE.md` | LOW | Prose only. |

## Contract analysis

These are the only code lines that changed:

- **`constructor(owner_, bears_, mntd_, thresholdsWhole, weights_)`**
  - A zero `owner_` reverts with `NewOwnerIsZeroAddress`. Solady's `_initializeOwner` would accept
    zero, and `_guardInitializeOwner` is not overridden, so the explicit check is needed. It runs
    before the `ZeroAddress` check.
  - `_initializeOwner(owner_)` emits `OwnershipTransferred(0, owner_)`.
  - `paused = true` and `PausedSet(true)` are set in the same frame. No path exists where the
    contract is live and unpaused before the owner acts.
- **`transferOwnership(address)`** is `public payable override` and always reverts with
  `TwoStepHandoverOnly`.
  - Solady's version carried `onlyOwner`; the override drops it. A stranger therefore gets
    `TwoStepHandoverOnly` instead of `Unauthorized`. No state changes either way, and both cases
    are tested.
  - Solady's `completeOwnershipHandover` calls `_setOwner` directly, not `transferOwnership`, so
    the handover is unaffected. This was checked in `lib/solady/src/auth/Ownable.sol:222-238`.
- **The handover itself** is unchanged Solady.
  - `requestOwnershipHandover` is open to anyone. It only records the caller's own expiry, 48 hours
    from `_ownershipHandoverValidFor`.
  - `completeOwnershipHandover` is `onlyOwner` and needs an unexpired request from that exact
    address. A griefer can only create requests for themselves, which the owner ignores.
  - `cancelOwnershipHandover` clears only the caller's own request.
- **Unchanged:**
  - The burn path, `setPaused` (`onlyOwner`) and `renounceOwnership` (reverts).
  - Storage: `_records` 0, `lifetimeBurned` 1, `paused` 2 (`forge inspect`).
  - The ACT-12 interface pin: 21 functions, no fallback, no receive.
  - Slither: the same 3 accepted `locked-ether` Mediums. The new override is `payable`, like the
    Solady functions it replaces, and reverts, so it cannot lock ETH.

## Deploy script

- `deployActivation` now constructs `Activation(cfg.admin, …)` and calls nothing afterwards. The
  deployer never owns `Activation`, so Calea never holds a role in it.
- `_require(cfg.admin, "admin")` still runs first. The contract's own zero-owner check is a second
  guard.
- `test/Deploy.t.sol` asserts exactly one write (construction), plus `owner() == admin` and
  `paused()`.

## Blast radius

- `new Activation(` appears in `script/Deploy.s.sol`, `test/BaseTest.t.sol`,
  `test/Activation.t.sol` and the client fixture, and all are updated.
- Nothing in `src/`, `script/` or the client library calls `Activation.transferOwnership`. The
  client's surface test lists it under owner-only functions, and it is still in the ABI.

## Residual risk

- A wrong `admin` at deployment still leaves an `Activation` that cannot be recovered. It is paused,
  however, and no level has been recorded yet. The runbook's read-back (`owner()` and the admin's
  `setPaused(true)` proof of control) catches it, and a redeploy costs nothing. This is the case
  the audit itself rated as acceptable.
- A Safe admin must send `requestOwnershipHandover` itself, as a Safe transaction, before any
  rotation. The runbook documents this.

## Findings

None.
