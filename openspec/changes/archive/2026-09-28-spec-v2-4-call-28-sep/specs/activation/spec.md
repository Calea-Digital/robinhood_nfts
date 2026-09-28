# Spec Delta

## ADDED Requirements

### Requirement: ACT-15 — Pause
**Kind:** work-item
The owner may pause. While paused, `burn` reverts; reads and every transfer are unaffected. No
$MNTD is burned while paused, which is how burns stay closed between deployment and the
switch-on date (§8). The pause admits no exemption: no address may burn while it is on. So the
mainnet rehearsal against real $MNTD runs in a window the owner opens and closes again (§8).
`renounceOwnership` reverts for every caller, so the pause can always be set and lifted.

#### Scenario: Pause closes burns only
- **GIVEN** the owner has paused
- **WHEN** a holder calls `burn`
- **THEN** it reverts with `ContractPaused`
- **AND** reads and every transfer still succeed

## MODIFIED Requirements

### Requirement: ACT-5 — Reset
**Kind:** work-item
Cumulative and level read as zero, and the weight reads the level-0 weight (ACT-3), whenever
the counter value they were recorded at differs from the current `transferNonce`. The reset is
a consequence of the transfer (COL-3), not an action: it cannot be skipped and cannot block a
transfer. Return transfers reset like any other.

#### Scenario: A transfer resets everything
- **GIVEN** a bear at level 2
- **WHEN** it is transferred to another wallet
- **THEN** `levelOf` and `cumulativeOf` read zero and `weightOf` reads `weightFor(0)`, with no call into `Activation`

### Requirement: ACT-12 — Roles
**Kind:** work-item
Owner (MINT's admin): `setPaused` and ownership transfer; `renounceOwnership` reverts. A bear's
owner: `burn` for that bear. Nothing else is administrable: the token, thresholds, weights and
records are immutable, and no address can record a level without burning. There is no freeze or
clawback path into a bear anywhere (MINT, CQ-16). Which bear carries an account's Status boost
is MINT's, recorded against the holder's Privy account off-chain (MINT, CQ-21); `Activation`
records levels only.

#### Scenario: Only the owner administers
- **WHEN** a non-owner calls `setPaused`, or anyone calls `renounceOwnership`
- **THEN** it reverts
- **AND** no function anywhere changes the token, thresholds, weights or a bear's record other than its owner's `burn`

### Requirement: ACT-13 — Events
**Kind:** work-item
`BearActivated(tokenId, burner, previousLevel, newLevel, amount, cumulative)` (ACT-4) and
`PausedSet(paused)`.

#### Scenario: Events carry the documented arguments
- **WHEN** a burn and a pause happen
- **THEN** `BearActivated` and `PausedSet` are emitted with the documented arguments

### Requirement: ACT-14 — Reads
**Kind:** work-item
`levelOf`, `cumulativeOf`, `lifetimeBurned`, `weightOf`, `weightFor`, `thresholdFor`,
`costToReach`, `snapshot`, `paused`, `BEARS`, `MNTD`, `DECIMALS`.

#### Scenario: Every read answers
- **WHEN** every listed read is called for a bear that has been burned for
- **THEN** each returns without reverting
- **AND** `BEARS` and `MNTD` return the deployed addresses and `DECIMALS` the token's decimals

## REMOVED Requirements

### Requirement: ACT-9 — Status link
**Reason:** MINT assigns Status links to holders' Privy accounts off-chain (call, 28 September 2026), so `Activation` records none.
**Migration:** See ACT-12; MINT's Status reads `levelOf` for the bear the account names.

### Requirement: ACT-11 — Pause
**Reason:** The pause no longer closes links, which are removed (ACT-9); restated without them.
**Migration:** See ACT-15.
