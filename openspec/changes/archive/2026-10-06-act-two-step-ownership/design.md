# Design

## Context

`Activation` inherits Solady `Ownable`. Solady's `transferOwnership` is immediate. Its handover is
two-step: the new owner calls `requestOwnershipHandover()`, which expires after 48 hours, and the
current owner calls `completeOwnershipHandover(newOwner)`. The deploy script constructed
`Activation` with the deployer as owner, called `setPaused(true)` and then
`transferOwnership(admin)`.

## Goals / Non-Goals

**Goals:** after deployment, ownership can't reach an address that has not acted, and the deploy
leaves Calea with no role at any point.

**Non-Goals:** changing `MintABear`'s ownership, which already uses SeaDrop's `TwoStepOwnable`.

## Decisions

- **Owner and pause in the constructor.** `Activation` is correct from its first block, and the
  deploy makes no call afterwards (OPS-2). A wrong admin at deployment is caught by the runbook's
  read-back while nothing has been burned, and the remedy is a free redeploy. The alternative was
  a Calea-owned deploy followed by a handover the admin requests. It was rejected because Calea
  would hold the role until the admin acted.
- **`transferOwnership` reverts with `TwoStepHandoverOnly`.** The function is overridden rather than
  removed, so the external interface (ACT-12 pin) is unchanged and callers get a named error.
- **A zero owner is refused with Solady's `NewOwnerIsZeroAddress`**, as `WhitelistClaim` and
  `WhitelistImport` already do. Solady's `_initializeOwner` accepts zero.

## Risks / Trade-offs

- A rotation needs two transactions within 48 hours, one from each side. A request that expires is
  simply made again.
