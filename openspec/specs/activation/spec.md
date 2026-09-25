# Activation and burn route Specification

## Purpose
Holders need to burn $MNTD to raise a bear's level and weight, and MINT needs to read those weights for the royalty split, in a way no key can forge and every transfer resets — so that a level is always evidence of a burn by the current owner.

## Requirements

### Requirement: ACT-1 — One token, one collection
**Kind:** work-item
`Activation` holds one token reference, $MNTD, fixed in its constructor, and
uses it for one thing: burning the caller's own $MNTD in `burn` (ACT-7). It records burned
amounts per bear and derives level and weight from them. It reads `MintABear` (`ownerOf`,
`transferNonce`, `exists`); `MintABear` never calls it, so no defect in `Activation` can affect a
transfer. In plain terms: recording the level and burning the tokens are two steps of one
transaction, the record first — `Activation` adds the amount to the bear, then burns it from the
holder — and any revert undoes both.

#### Scenario: One token, one collection
- **WHEN** `Activation`'s code and constructor are inspected
- **THEN** its only calls to $MNTD are `decimals` in the constructor and `burnFrom` of the caller's own balance in `burn`, and it moves no other token
- **AND** it reads only `MintABear`'s `ownerOf`, `transferNonce` and `exists`

### Requirement: ACT-2 — Thresholds
**Kind:** work-item
Five cumulative thresholds `T1 < T2 < T3 < T4 < T5`, supplied to the
constructor in whole $MNTD and scaled there by the token's `decimals` into base units, which are
immutable; `DECIMALS` reads the value used. A bear's level is the highest `k` with
`cumulative ≥ Tk`, or 0. `thresholdFor(level)` and `costToReach(tokenId, level)` expose them in
base units. The figures are 1,666 / 3,333 / 8,333 / 16,666 / 41,666 $MNTD, read cumulatively:
each is the total a bear must have burned to stand at that level, so level 5 costs 41,666 $MNTD in
all (MINT, CQ-4).

| Level | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Total burned to reach it | 1,666 | 3,333 | 8,333 | 16,666 | 41,666 |

#### Scenario: Cumulative thresholds give the level
- **GIVEN** the thresholds 1,666 / 3,333 / 8,333 / 16,666 / 41,666 whole $MNTD and a token with 18 decimals
- **WHEN** a bear's cumulative reaches 8,333 $MNTD
- **THEN** `levelOf` reads 3 and `costToReach(id, 4)` reads 8,333 × 10^18

### Requirement: ACT-3 — Weights
**Kind:** work-item
Six royalty weights for levels 0–5, basis 100, supplied to the constructor
and immutable: `100 / 110 / 125 / 145 / 170 / 200` (1.00× to 2.00×), confirmed by MINT.
`weightFor(level)` returns the table entry; `weightOf(tokenId)` returns the weight of the bear's
current level.

#### Scenario: Weights follow the level
- **GIVEN** the weights 100 / 110 / 125 / 145 / 170 / 200
- **WHEN** a bear at level 3 is read
- **THEN** `weightOf` returns 145 and `weightFor(5)` returns 200

### Requirement: ACT-4 — Burn record
**Kind:** work-item
`burn(uint256 tokenId, uint128 amount)` reverts unless: not paused
(`ContractPaused`); `amount > 0` (`ZeroAmount`); `ownerOf(tokenId) == msg.sender`
(`NotBearOwner`); the bear is below level 5 (`AlreadyAtMaxLevel`); `amount ≤ costToReach(tokenId,
5)` (`Overshoot`, ACT-8). Effects, in order: the cumulative for the bear's current counter value
increases by `amount`; `lifetimeBurned` increases by `amount`; `BearActivated(tokenId, burner,
previousLevel, newLevel, amount, cumulative)` is emitted; then `MNTD.burnFrom(msg.sender, amount)`.
The owner check and the counter are read in the same call as the record, so a burn is never
recorded for a bear its burner does not hold. `burn` is non-reentrant: a call made from inside the
token's `burnFrom` is refused.

#### Scenario: A burn is recorded once
- **GIVEN** the owner of a bear below level 5 who has approved `Activation` on $MNTD
- **WHEN** the owner calls `burn(tokenId, amount)`
- **THEN** the cumulative and `lifetimeBurned` grow by `amount`, `BearActivated` is emitted and the owner's $MNTD falls by `amount`
- **AND** a `burn` made from inside the token's `burnFrom` reverts

### Requirement: ACT-5 — Reset
**Kind:** work-item
Cumulative and level read as zero, the weight reads the level-0 weight (ACT-3) and the link
reads `(0, 0)` whenever the counter value they were recorded at differs from the current
`transferNonce`. The reset is a consequence of the transfer (COL-3), not an action: it cannot
be skipped and cannot block a transfer. Return transfers reset like any other.

#### Scenario: A transfer resets everything
- **GIVEN** a bear at level 2 with a Status link
- **WHEN** it is transferred to another wallet
- **THEN** `levelOf` and `cumulativeOf` read zero, `weightOf` reads `weightFor(0)` and `linkOf` reads `(0, 0)`, with no call into `Activation`

### Requirement: ACT-6 — Lifetime
**Kind:** work-item
`lifetimeBurned(tokenId)` accumulates every burn ever recorded for a bear
and never resets.

#### Scenario: Lifetime never resets
- **GIVEN** a bear burned for twice with a transfer in between
- **WHEN** `lifetimeBurned` is read
- **THEN** it is the sum of both burns

### Requirement: ACT-7 — Burn route
**Kind:** work-item
$MNTD is native to Robinhood Chain (MINT, CQ-2): its canonical supply is
issued there and `burnFrom` reduces it, so a burn removes supply outright and needs nothing said
about it publicly. `Activation` takes its address as an immutable constructor argument; a
different token address means a new `Activation`, so the address must be final before deployment
(`→ CQ-2`). The holder approves `Activation` on $MNTD once and calls `burn(tokenId, amount)`
(ACT-4), which records the burn and calls `MNTD.burnFrom(msg.sender, amount)` in the same
transaction. Requirements on $MNTD: an ERC-20 on 4663 exposing `decimals()` and
`burnFrom(address, uint256)` (OpenZeppelin `ERC20Burnable`) that reverts rather than returning
false on failure. A bridged or mint-and-burn representation, a burn on another chain with an
attested record on 4663, and cross-chain messaging are all out. MINT's staking sits beside the
token on the same chain and touches nothing here. The token's `burnFrom`, `decimals` and the
finality of its address are still to be confirmed against the deployed contract (`→ CQ-2`).

#### Scenario: Record and burn in one transaction
- **GIVEN** the holder has approved `Activation` on $MNTD
- **WHEN** the holder calls `burn(tokenId, amount)` for a bear below level 5
- **THEN** the burn is recorded and `burnFrom` executes in one transaction, and `BearActivated` is emitted
- **AND** a call by a non-owner reverts with `NotBearOwner`

### Requirement: ACT-8 — Overshoot
**Kind:** work-item
`burn` refuses any amount beyond what level 5 needs, so no $MNTD is
destroyed for nothing. The portal sizes each burn with `costToReach(tokenId, targetLevel)`,
which returns the exact remainder or zero.

#### Scenario: Nothing is burned for nothing
- **GIVEN** a bear whose `costToReach(id, 5)` reads x
- **WHEN** the holder calls `burn(id, x + 1)`
- **THEN** it reverts with `Overshoot` and no $MNTD is burned

### Requirement: ACT-9 — Status link
**Kind:** work-item
`linkBear(tokenId)`, owner of the bear only, one nomination per wallet,
recorded with the current counter value; `unlinkBear()` clears it and is safe to call when
nothing is linked; `linkOf(wallet) → (tokenId, level)` returns `(0, 0)` when nothing is linked
or the bear has since moved. A wallet aggregates royalty weight across all its bears (ACT-10)
but carries exactly one Status boost; the boost's value, and how the links of an account's
several wallets combine, are MINT's, off-chain (`→ CQ-21`).

#### Scenario: One nomination per wallet
- **GIVEN** a wallet owning a bear at level 2
- **WHEN** it calls `linkBear(tokenId)`
- **THEN** `linkOf(wallet)` reads `(tokenId, 2)`
- **AND** after the bear moves it reads `(0, 0)`

### Requirement: ACT-10 — Snapshot view
**Kind:** work-item
`snapshot(uint256[] ids) → (address owner, uint8 level, uint16
weight)[]`, returning zeroes for ids that do not exist. MINT's royalty accounting counts, at each
closing block, every bear that has an owner among ids `1..4444`: a wallet's weight is the sum over
its bears, and the total eligible weight is the sum over all bears whose owner is not the canonical
dead address `0x000000000000000000000000000000000000dEaD` (COL-8). Because transfers reset weight
without any call into `Activation`, there is no on-chain running total; the sum is taken off-chain.
The reference script (DEL-6) reads the inputs from an archive node at the closing block, in either
of two ways that agree:
- owners from the collection's `Transfer` events and weights from `weightOf`, for owned ids only,
  since `weightOf` answers the level-0 weight for an id never minted;
- `snapshot`, paged by a gas budget. Each id's owner lookup walks back to the start of its mint
  batch, so one call over the whole range is not dependable (56.2M gas at two bears per wallet).

The script refuses inputs that miss a minted bear, and its allocations plus the rounding carried to
the next distribution equal the funding. MINT credits the resulting shares to getminted.io accounts
through its wallet (§2).

#### Scenario: The snapshot answers for any ids
- **WHEN** `snapshot([1, 2, 4445])` is read
- **THEN** it returns owner, level and weight for ids 1 and 2 and zeroes for the id that does not exist

### Requirement: ACT-11 — Pause
**Kind:** work-item
The owner may pause. While paused, `burn` and `linkBear` revert; reads,
`unlinkBear` and every transfer are unaffected. No $MNTD is burned while paused; this is how
burns stay closed between deployment and the switch-on date (§8). The pause admits no exemption —
no address may burn while it is on — so the mainnet rehearsal against real $MNTD runs in a window
the owner opens and closes again (§8). `renounceOwnership` reverts for every caller, so the pause
can always be set and lifted.

#### Scenario: Pause closes burns and links only
- **GIVEN** the owner has paused
- **WHEN** a holder calls `burn` or `linkBear`
- **THEN** both revert with `ContractPaused`
- **AND** reads, `unlinkBear` and every transfer still succeed

### Requirement: ACT-12 — Roles
**Kind:** work-item
Owner (MINT admin): `setPaused` and ownership transfer; `renounceOwnership`
reverts. A bear's owner: `burn` for that bear, `linkBear`, `unlinkBear`. Nothing else is
administrable: the token, thresholds, weights and records are immutable, and no address can record
a level without burning. There is no freeze or clawback path into a bear anywhere (MINT, CQ-16).

#### Scenario: Only the owner administers
- **WHEN** a non-owner calls `setPaused`, or anyone calls `renounceOwnership`
- **THEN** it reverts
- **AND** no function anywhere changes the token, thresholds, weights or a bear's record other than its owner's `burn`

### Requirement: ACT-13 — Events
**Kind:** work-item
`BearActivated(tokenId, burner, previousLevel, newLevel, amount,
cumulative)` (ACT-4), `BearLinked(wallet, tokenId)`, `BearUnlinked(wallet, tokenId)`,
`PausedSet(paused)`.

#### Scenario: Events carry the documented arguments
- **WHEN** a burn, a link, an unlink and a pause happen
- **THEN** `BearActivated`, `BearLinked`, `BearUnlinked` and `PausedSet` are emitted with the documented arguments

### Requirement: ACT-14 — Reads
**Kind:** work-item
`levelOf`, `cumulativeOf`, `lifetimeBurned`, `weightOf`, `weightFor`,
`thresholdFor`, `costToReach`, `linkOf`, `snapshot`, `paused`, `BEARS`, `MNTD`, `DECIMALS`.

#### Scenario: Every read answers
- **WHEN** every listed read is called for a bear that has been burned for
- **THEN** each returns without reverting
- **AND** `BEARS` and `MNTD` return the deployed addresses and `DECIMALS` the token's decimals
