# Activation and burn route Specification

## Purpose
Holders need to burn $MNTD to raise a bear's level and weight, and MINT needs to read those weights for the royalty split, in a way no key can forge and every transfer resets — so that a level is always evidence of a burn by the current owner.

## Requirements

### Requirement: ACT-1 — Token-agnostic
**Kind:** work-item
`Activation` holds no reference to $MNTD and never moves tokens. It
records credited burn amounts per bear and derives level and weight from them. It reads
`MintABear` (`ownerOf`, `transferNonce`, `exists`); `MintABear` never calls it, so no defect in
`Activation` can affect a transfer. In plain terms: burning the tokens and recording the level
are two steps of one transaction. The adapter burns the holder's $MNTD, then tells `Activation`
"this wallet burned this amount for this bear"; `Activation` accepts that message from the
adapter alone. If $MNTD ever changes address or chain, only the adapter changes.

#### Scenario: Activation knows no token
- **WHEN** `Activation`'s code and constructor are inspected
- **THEN** it holds no $MNTD reference and moves no tokens
- **AND** it reads only `MintABear`'s `ownerOf`, `transferNonce` and `exists`

### Requirement: ACT-2 — Thresholds
**Kind:** work-item
Five cumulative thresholds `T1 < T2 < T3 < T4 < T5`, in $MNTD base units,
supplied to the constructor and immutable. A bear's level is the highest `k` with
`cumulative ≥ Tk`, or 0. `thresholdFor(level)` and `costToReach(tokenId, level)` expose them.
The figures are 1,666 / 3,333 / 8,333 / 16,666 / 41,666 $MNTD, read cumulatively: each is the
total a bear must have burned to stand at that level, so level 5 costs 41,666 $MNTD in all
(MINT, CQ-4).

| Level | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Total burned to reach it | 1,666 | 3,333 | 8,333 | 16,666 | 41,666 |

The constructor receives this row in base units, which fixes $MNTD's `decimals` before
deployment (`→ CQ-2`).

#### Scenario: Cumulative thresholds give the level
- **GIVEN** the thresholds 1,666 / 3,333 / 8,333 / 16,666 / 41,666 in base units
- **WHEN** a bear's cumulative reaches 8,333
- **THEN** `levelOf` reads 3 and `costToReach(id, 4)` reads 8,333

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

### Requirement: ACT-4 — Credit
**Kind:** work-item
`credit(uint256 tokenId, address burner, uint128 amount, uint64 nonce,
bytes32 ref)` is callable only by the `crediter` (`NotCrediter`, ACT-7). It reverts unless: not
paused (`ContractPaused`); `amount > 0` (`ZeroAmount`); `ownerOf(tokenId) == burner`
(`NotBearOwner`); `transferNonce(tokenId) == nonce` (`StaleNonce`); `ref` has not been used
(`RefAlreadyUsed`). Both ownership checks passing means `burner` has owned the bear continuously
since `nonce` was read — a burn is never credited to a bear that changed hands in between. Effects:
the cumulative for the current counter value increases by `amount`; `lifetimeBurned` increases by
`amount`; `ref` is marked used; `BearActivated(tokenId, burner, previousLevel, newLevel, amount,
cumulative, ref)` is emitted.

#### Scenario: A credit is recorded once
- **GIVEN** the crediter calls `credit` for a bear the burner owns, with the current nonce and a fresh `ref`
- **WHEN** the call executes
- **THEN** the cumulative and `lifetimeBurned` grow by `amount` and `BearActivated` is emitted
- **AND** a second call with the same `ref` reverts with `RefAlreadyUsed`

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
`lifetimeBurned(tokenId)` accumulates every credit ever made to a bear and
never resets.

#### Scenario: Lifetime never resets
- **GIVEN** a bear credited twice with a transfer in between
- **WHEN** `lifetimeBurned` is read
- **THEN** it is the sum of both credits

### Requirement: ACT-7 — Crediter and route
**Kind:** work-item
Exactly one `crediter` address, set by the owner (`setCrediter`,
event `CrediterSet`). $MNTD is deployed on Robinhood Chain (MINT), so the crediter is the
**`DirectBurnAdapter`** on 4663. The holder approves the adapter on $MNTD once and calls
`burn(tokenId, amount)`; the adapter reverts unless `ownerOf(tokenId) == msg.sender`
(`NotOwner`), the bear is below level 5 (`AlreadyAtMaxLevel`) and
`amount ≤ costToReach(tokenId, 5)` (`Overshoot`); it then calls `MNTD.burnFrom(msg.sender,
amount)` and `Activation.credit(tokenId, msg.sender, amount, transferNonce(tokenId), ref)` in
the same transaction, with `ref` a per-adapter burn number, and emits `BurnedForBear(ref,
tokenId, burner, amount)`. The adapter has no owner and no settings; a new token address means a
new adapter and one `setCrediter` call. Requirements on $MNTD: an ERC-20 on 4663 exposing
`burnFrom(address, uint256)` (OpenZeppelin `ERC20Burnable`) with `decimals` fixed before
`Activation` is deployed. $MNTD is **native** to Robinhood Chain: its canonical supply is issued
there and `burnFrom` reduces it, so a burn removes supply outright and needs nothing said about
it publicly (MINT, CQ-2). A bridged or mint-and-burn representation, a burn on another chain
with an attested credit on 4663, and cross-chain messaging are all out. MINT's staking sits
beside the token on the same chain and touches nothing here: `Activation` reads only
`MintABear`, and the adapter only $MNTD. The token's `burnFrom` and `decimals` are still to be
confirmed against the deployed contract (`→ CQ-2`).

#### Scenario: Burn and credit in one transaction
- **GIVEN** the holder has approved the adapter on $MNTD
- **WHEN** the holder calls `burn(tokenId, amount)` for a bear below level 5
- **THEN** `burnFrom` and `credit` execute in one transaction and `BurnedForBear` is emitted
- **AND** a call by a non-owner reverts with `NotOwner`

### Requirement: ACT-8 — Overshoot
**Kind:** work-item
The adapter refuses any amount beyond what level 5 needs, so no $MNTD is
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
but carries exactly one Status boost; the boost's value is MINT's, off-chain.

#### Scenario: One nomination per wallet
- **GIVEN** a wallet owning a bear at level 2
- **WHEN** it calls `linkBear(tokenId)`
- **THEN** `linkOf(wallet)` reads `(tokenId, 2)`
- **AND** after the bear moves it reads `(0, 0)`

### Requirement: ACT-10 — Snapshot view
**Kind:** work-item
`snapshot(uint256[] ids) → (address owner, uint8 level, uint16
weight)[]`, returning zeroes for ids that do not exist. MINT's royalty accounting reads it for
`1..4444` at each closing block; a wallet's weight is the sum over its bears and the total
eligible weight is the sum over all bears whose owner is not the canonical dead address
`0x000000000000000000000000000000000000dEaD` (COL-8). Because transfers reset weight without any
call into `Activation`, there is no on-chain running total; the sum is taken off-chain from
this view. A reference script reproducing the split, dead-address exclusion included, is
delivered (DEL-6); MINT credits the resulting shares to getminted.io accounts through its
wallet (§2).

#### Scenario: The snapshot answers for any ids
- **WHEN** `snapshot([1, 2, 4445])` is read
- **THEN** it returns owner, level and weight for ids 1 and 2 and zeroes for the id that does not exist

### Requirement: ACT-11 — Pause
**Kind:** work-item
The owner may pause. While paused, `credit` and `linkBear` revert; reads,
`unlinkBear` and every transfer are unaffected. The adapter's `burn` therefore reverts while
paused and no $MNTD is burned; this is how burns stay closed between deployment and the
switch-on date (§8). The pause admits no exemption — no address may burn while it is on — so
the mainnet rehearsal against real $MNTD runs in a window the owner opens and closes again
(§8). `renounceOwnership` is refused while paused, so a pause can always be lifted.

#### Scenario: Pause closes credits and links only
- **GIVEN** the owner has paused
- **WHEN** the crediter calls `credit` or a holder calls `linkBear`
- **THEN** both revert with `ContractPaused`
- **AND** reads, `unlinkBear` and every transfer still succeed

### Requirement: ACT-12 — Roles
**Kind:** work-item
Owner (MINT admin): `setCrediter`, `setPaused`, ownership transfer. Nothing
else is administrable: thresholds, weights and records are immutable; the adapter has no owner.
There is no freeze or clawback path into a bear anywhere (MINT, CQ-16).

#### Scenario: Only the owner administers
- **WHEN** a non-owner calls `setCrediter` or `setPaused`
- **THEN** it reverts
- **AND** no function anywhere changes thresholds, weights or a bear's record

### Requirement: ACT-13 — Events
**Kind:** work-item
`BearActivated` (ACT-4), `BearLinked(wallet, tokenId)`,
`BearUnlinked(wallet, tokenId)`, `CrediterSet(previous, current)`, `PausedSet(paused)`;
adapter: `BurnedForBear(ref, tokenId, burner, amount)`.

#### Scenario: Events carry the documented arguments
- **WHEN** a credit, a link, an unlink, a crediter change and a pause happen
- **THEN** `BearActivated`, `BearLinked`, `BearUnlinked`, `CrediterSet` and `PausedSet` are emitted with the documented arguments

### Requirement: ACT-14 — Reads
**Kind:** work-item
`levelOf`, `cumulativeOf`, `lifetimeBurned`, `weightOf`, `weightFor`,
`thresholdFor`, `costToReach`, `linkOf`, `snapshot`, `paused`, `crediter`, `BEARS`; adapter:
`MNTD`, `ACTIVATION`, `burnCount`.

#### Scenario: Every read answers
- **WHEN** every listed read is called for a credited bear
- **THEN** each returns without reverting
- **AND** `BEARS`, `MNTD` and `ACTIVATION` return the deployed addresses
