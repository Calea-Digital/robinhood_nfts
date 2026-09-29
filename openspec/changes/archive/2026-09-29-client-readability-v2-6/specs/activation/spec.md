# Spec Delta

## MODIFIED Requirements

### Requirement: ACT-1 — One token, one collection
**Kind:** work-item
Activation works with one token, $MNTD, fixed when it is deployed, and one collection. It reads
who owns a bear and its transfer count. The collection never calls it, so a problem in
Activation can never block a transfer. Recording a burn and burning the tokens happen in one
transaction: if either fails, neither happens.

*Technical note.* `Activation` holds one token reference, $MNTD, fixed in its constructor, and
uses it for one thing: burning the caller's own $MNTD in `burn` (ACT-7). It records burned
amounts per bear and derives level and weight from them. It reads `MintABear` (`ownerOf`,
`transferNonce`, `exists`); `MintABear` never calls it. The record comes first: `Activation` adds
the amount to the bear, then burns it from the holder, and any revert undoes both.

#### Scenario: One token, one collection
- **WHEN** `Activation`'s code and constructor are inspected
- **THEN** its only calls to $MNTD are `decimals` in the constructor and `burnFrom` of the caller's own balance in `burn`, and it moves no other token
- **AND** it reads only `MintABear`'s `ownerOf`, `transferNonce` and `exists`

### Requirement: ACT-2 — Thresholds
**Kind:** work-item
A bear's level comes from the total $MNTD burned for it: 1,666 for level 1, then 3,333, 8,333,
16,666 and 41,666 for level 5. The figures are totals, so level 5 costs 41,666 in all (MINT,
CQ-4). They are fixed at deployment.

| Level | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Total burned to reach it | 1,666 | 3,333 | 8,333 | 16,666 | 41,666 |

*Technical note.* Five cumulative thresholds `T1 < T2 < T3 < T4 < T5`, supplied to the
constructor in whole $MNTD and scaled there by the token's `decimals` into base units, which are
immutable; `DECIMALS` reads the value used. A bear's level is the highest `k` with
`cumulative ≥ Tk`, or 0. `thresholdFor(level)` and `costToReach(tokenId, level)` expose them in
base units.

#### Scenario: Cumulative thresholds give the level
- **GIVEN** the thresholds 1,666 / 3,333 / 8,333 / 16,666 / 41,666 whole $MNTD and a token with 18 decimals
- **WHEN** a bear's cumulative reaches 8,333 $MNTD
- **THEN** `levelOf` reads 3 and `costToReach(id, 4)` reads 8,333 × 10^18

### Requirement: ACT-3 — Weights
**Kind:** work-item
Each level has a royalty weight: 1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00 for levels 0–5 (MINT,
CQ-5), fixed at deployment. A level-5 bear earns twice a level-0 bear's share.

*Technical note.* Basis 100: `100 / 110 / 125 / 145 / 170 / 200`, supplied to the constructor and
immutable. `weightFor(level)` returns the table entry; `weightOf(tokenId)` returns the weight of
the bear's current level.

#### Scenario: Weights follow the level
- **GIVEN** the weights 100 / 110 / 125 / 145 / 170 / 200
- **WHEN** a bear at level 3 is read
- **THEN** `weightOf` returns 145 and `weightFor(5)` returns 200

### Requirement: ACT-4 — Burn record
**Kind:** work-item
Only a bear's current owner can burn for it. The burn is refused while burning is paused, for a
zero amount, for a bear already at level 5, and for more than level 5 needs (ACT-8). A successful
burn records the amount against the bear and publishes it (ACT-13). A burn can never land on a
bear its burner doesn't hold.

*Technical note.* `burn(uint256 tokenId, uint128 amount)` reverts unless: not paused
(`ContractPaused`); `amount > 0` (`ZeroAmount`); `ownerOf(tokenId) == msg.sender`
(`NotBearOwner`); the bear is below level 5 (`AlreadyAtMaxLevel`); `amount ≤ costToReach(tokenId,
5)` (`Overshoot`, ACT-8). Effects, in order: the cumulative for the bear's current counter value
increases by `amount`; `lifetimeBurned` increases by `amount`; `BearActivated(tokenId, burner,
previousLevel, newLevel, amount, cumulative)` is emitted; then `MNTD.burnFrom(msg.sender, amount)`.
The owner check and the counter are read in the same call as the record. `burn` is
non-reentrant: a call made from inside the token's `burnFrom` is refused.

#### Scenario: A burn is recorded once
- **GIVEN** the owner of a bear below level 5 who has approved `Activation` on $MNTD
- **WHEN** the owner calls `burn(tokenId, amount)`
- **THEN** the cumulative and `lifetimeBurned` grow by `amount`, `BearActivated` is emitted and the owner's $MNTD falls by `amount`
- **AND** a `burn` made from inside the token's `burnFrom` reverts

### Requirement: ACT-5 — Reset
**Kind:** work-item
When a bear changes hands, its level and burned total read zero and its weight reads the level-0
weight (ACT-3), including when it returns to a previous owner. The reset follows from the
transfer itself (COL-3), so it can't be skipped and can't block a transfer.

*Technical note.* Cumulative and level read as zero whenever the counter value they were recorded
at differs from the current `transferNonce`; nothing is written on transfer.

#### Scenario: A transfer resets everything
- **GIVEN** a bear at level 2
- **WHEN** it is transferred to another wallet
- **THEN** `levelOf` and `cumulativeOf` read zero and `weightOf` reads `weightFor(0)`, with no call into `Activation`

### Requirement: ACT-6 — Lifetime
**Kind:** work-item
Separately, every bear keeps a lifetime total of everything ever burned for it, which never
resets.

*Technical note.* `lifetimeBurned(tokenId)` accumulates every burn ever recorded for a bear.

#### Scenario: Lifetime never resets
- **GIVEN** a bear burned for twice with a transfer in between
- **WHEN** `lifetimeBurned` is read
- **THEN** it is the sum of both burns

### Requirement: ACT-7 — Burn route
**Kind:** work-item
$MNTD is native to Robinhood Chain, so a burn removes supply outright (MINT, CQ-2). The holder
approves Activation on $MNTD once, then burns in one click. The token's address is fixed when
Activation is deployed, so a different address means a new Activation. No bridge, other chain or
cross-chain messaging is involved. MINT's staking sits beside the token and touches nothing here
(`→ CQ-2`).

*Technical note.* `Activation` takes the token's address as an immutable constructor argument.
`burn(tokenId, amount)` (ACT-4) records the burn and calls `MNTD.burnFrom(msg.sender, amount)` in
the same transaction. Requirements on $MNTD: an ERC-20 on 4663 exposing `decimals()` and
`burnFrom(address, uint256)` (OpenZeppelin `ERC20Burnable`, as the reference token) that reverts
rather than returning false on failure. A bridged or mint-and-burn representation, and a burn on
another chain with an attested record on 4663, are out.

#### Scenario: Record and burn in one transaction
- **GIVEN** the holder has approved `Activation` on $MNTD
- **WHEN** the holder calls `burn(tokenId, amount)` for a bear below level 5
- **THEN** the burn is recorded and `burnFrom` executes in one transaction, and `BearActivated` is emitted
- **AND** a call by a non-owner reverts with `NotBearOwner`

### Requirement: ACT-8 — Overshoot
**Kind:** work-item
A burn above what level 5 still needs is refused, so no $MNTD is destroyed for nothing. The page
sizes each burn to the exact amount for the target level.

*Technical note.* `burn` reverts with `Overshoot` above `costToReach(tokenId, 5)`; the portal
sizes each burn with `costToReach(tokenId, targetLevel)`, which returns the exact remainder or
zero.

#### Scenario: Nothing is burned for nothing
- **GIVEN** a bear whose `costToReach(id, 5)` reads x
- **WHEN** the holder calls `burn(id, x + 1)`
- **THEN** it reverts with `Overshoot` and no $MNTD is burned

### Requirement: ACT-10 — Snapshot view
**Kind:** work-item
At each royalty closing, MINT's split counts every owned bear: a wallet's weight is the sum over
its bears, and bears held by the dead address are left out (COL-8). The total is taken off-chain,
because transfers reset weights without any call to Activation. Calea's reference script
reproduces the split from an archive node, refuses inputs that miss a bear, and its shares plus
the rounding carried forward equal the funding. MINT credits the shares to getminted.io accounts
(§2).

*Technical note.* `snapshot(uint256[] ids) → (address owner, uint8 level, uint16 weight)[]`,
returning zeroes for ids that do not exist. The split counts every bear with an owner among ids
`1..4444`, excluding the canonical dead address
`0x000000000000000000000000000000000000dEaD`. The reference script (DEL-6) reads the inputs at the
closing block in either of two ways that agree: owners from the collection's `Transfer` events
and weights from `weightOf`, for owned ids only, since `weightOf` answers the level-0 weight for
an id never minted; or `snapshot`, paged by a gas budget. Each id's owner lookup walks back to the
start of its mint batch, so one call over the whole range is not dependable (56.2M gas at two
bears per wallet).

#### Scenario: The snapshot answers for any ids
- **WHEN** `snapshot([1, 2, 4445])` is read
- **THEN** it returns owner, level and weight for ids 1 and 2 and zeroes for the id that does not exist

### Requirement: ACT-15 — Pause
**Kind:** work-item
MINT's admin can pause burning, and only burning: reads and transfers carry on. Activation is
deployed paused and opens on 29 October (§8). The pause has no exemptions, so the mainnet
rehearsal runs in a window the admin opens and closes again. Ownership can't be given up, so the
pause can always be set and lifted.

*Technical note.* `setPaused(bool)`, owner-only; while paused `burn` reverts with
`ContractPaused`. `renounceOwnership` reverts for every caller.

#### Scenario: Pause closes burns only
- **GIVEN** the owner has paused
- **WHEN** a holder calls `burn`
- **THEN** it reverts with `ContractPaused`
- **AND** reads and every transfer still succeed

### Requirement: ACT-12 — Roles
**Kind:** work-item
MINT's admin can only pause and hand over ownership. A bear's owner can burn for it. Nothing else
can be changed: the token, thresholds, weights and records are fixed, and no one can record a
level without a burn. There is no freeze or clawback (MINT, CQ-16). Which bear carries an
account's Status boost is MINT's, kept off-chain against the holder's Privy account (MINT, CQ-21).

*Technical note.* Owner (MINT's admin): `setPaused` and ownership transfer; `renounceOwnership`
reverts. A bear's owner: `burn` for that bear. The external interface is pinned by the ACT-12
test: a function added fails the suite until the specification allows it.

#### Scenario: Only the owner administers
- **WHEN** a non-owner calls `setPaused`, or anyone calls `renounceOwnership`
- **THEN** it reverts
- **AND** no function anywhere changes the token, thresholds, weights or a bear's record other than its owner's `burn`

### Requirement: ACT-13 — Events
**Kind:** work-item
Every burn publishes the bear, the burner, the old and new level, the amount and the new total.
Every pause change is published.

*Technical note.* `BearActivated(tokenId, burner, previousLevel, newLevel, amount, cumulative)`
(ACT-4) and `PausedSet(paused)`.

#### Scenario: Events carry the documented arguments
- **WHEN** a burn and a pause happen
- **THEN** `BearActivated` and `PausedSet` are emitted with the documented arguments

### Requirement: ACT-14 — Reads
**Kind:** work-item
The page can read for free: a bear's level, burned total, lifetime total and weight; the weights
and thresholds; the cost to reach a level; the snapshot; and whether burning is paused.

*Technical note.* `levelOf`, `cumulativeOf`, `lifetimeBurned`, `weightOf`, `weightFor`,
`thresholdFor`, `costToReach`, `snapshot`, `paused`, `BEARS`, `MNTD`, `DECIMALS`.

#### Scenario: Every read answers
- **WHEN** every listed read is called for a bear that has been burned for
- **THEN** each returns without reverting
- **AND** `BEARS` and `MNTD` return the deployed addresses and `DECIMALS` the token's decimals
