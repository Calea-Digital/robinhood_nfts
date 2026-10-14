## MODIFIED Requirements

### Requirement: RAF-14 — Roles
**Kind:** work-item
**MINT's admin** records the team bears, schedules cycles, sets the worker and pauses either
contract. Ownership can't be given up. **The worker** carries openings to the draw and records
payouts (who runs it `→ CQ-23`). **Anyone** can open a box with a bear they hold, apply outcomes
whose random numbers have arrived, and read everything. No role can open a box for a holder,
change an outcome or move a bear.

*Technical note.* Owner: on `MysteryBox` `excludeRange`, `scheduleCycle`, `setPaused`; on
`PrizeDraw` `scheduleCycle`, `setWorker`, `setPaused`. Ownership moves on both only by Solady's
two-step handover: the new owner's `requestOwnershipHandover`, then the owner's
`completeOwnershipHandover` within 48 hours; `transferOwnership` reverts with
`TwoStepHandoverOnly` and `renounceOwnership` with `RenounceDisabled` on both. Worker: `resolve` and `recordPayout` on `PrizeDraw`.
Anyone: `open` on `MysteryBox`, `applyOutcomes` on `PrizeDraw`. The VRF coordinator alone
delivers words.

#### Scenario: Roles hold
- **WHEN** a non-owner calls `excludeRange`, `scheduleCycle` or `setWorker`, or a non-worker calls `resolve` or `recordPayout`
- **THEN** each reverts
- **AND** `open` needs no role but the bear's ownership
