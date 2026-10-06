# Spec Delta

## MODIFIED Requirements

### Requirement: ACT-15 — Pause
**Kind:** work-item
MINT's admin can pause burning, and only burning: reads and transfers carry on. Activation is
deployed paused and opens on 29 October (§8). The pause has no exemptions, so the mainnet
rehearsal runs in a window the admin opens and closes again. Ownership can't be given up, so the
pause can always be set and lifted.

*Technical note.* `paused` is true from construction. `setPaused(bool)`, owner-only; while paused
`burn` reverts with `ContractPaused`. `renounceOwnership` reverts for every caller.

#### Scenario: Pause closes burns only
- **GIVEN** the owner has paused
- **WHEN** a holder calls `burn`
- **THEN** it reverts with `ContractPaused`
- **AND** reads and every transfer still succeed

### Requirement: ACT-12 — Roles
**Kind:** work-item
MINT's admin can only pause and hand over ownership. A bear's owner can burn for it. Nothing else
can be changed: the token, thresholds, weights and records are fixed, and no one can record a
level without a burn. Ownership moves only to an address that has asked for it, so it can never
reach an address nobody controls. There is no freeze or clawback (MINT, CQ-16). Which bear carries an
account's Status boost is MINT's, kept off-chain against the holder's Privy account (MINT, CQ-21).

*Technical note.* Owner (MINT's admin, the constructor's `owner`; zero is refused with
`NewOwnerIsZeroAddress`): `setPaused` and the two-step handover — the new owner calls
`requestOwnershipHandover()`, then the owner calls `completeOwnershipHandover(newOwner)` within 48
hours. `transferOwnership` reverts with `TwoStepHandoverOnly` and `renounceOwnership` with
`RenounceDisabled`, for every caller. A bear's owner: `burn` for that bear. The external interface is pinned by the ACT-12
test: a function added fails the suite until the specification allows it.

#### Scenario: Only the owner administers
- **WHEN** a non-owner calls `setPaused`, or anyone calls `renounceOwnership` or `transferOwnership`
- **THEN** it reverts
- **AND** no function anywhere changes the token, thresholds, weights or a bear's record other than its owner's `burn`
