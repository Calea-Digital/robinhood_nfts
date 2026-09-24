# Activation — branching tree

Scope note: invariants (INV-N) and fork tests are recorded here as obligations for the
auditor. They are deliberately not implemented as developer unit leaves. Leaves that satisfy
a requirement's Scenario cite it (`ACT-n`, `openspec/specs/activation/spec.md`).

INV-N and Fork-N are numbered once across all trees and never reused: `MintABear` INV-1…3 (INV-1 retired), `Activation` INV-4…9 (INV-6 retired) and INV-15…16, `WhitelistClaim` INV-10…14; Fork-1 (real SeaDrop mint), Fork-2 (real validator V3), Fork-3 (real $MNTD `burnFrom`).

## One token, one collection (ACT-1)

```
Activation
├── calls $MNTD twice only: decimals, a read, in the constructor, and burnFrom of the caller's own
│   balance in burn; it sends no value and moves no other token (ACT-1)
├── calls nothing else but MintABear, and only its views ownerOf, transferNonce and exists —
│   across construction, burn, link, unlink and every read (ACT-1)
└── has no crediter
```

## burn(tokenId, amount)

```
burn
├── when paused
│   └── it reverts with ContractPaused and burns nothing
├── when amount is zero
│   └── it reverts with ZeroAmount
├── when the caller does not own the bear (an unrelated wallet, an approved operator)
│   └── it reverts with NotBearOwner and burns nothing (ACT-7)
├── when the bear is at level 5
│   └── it reverts with AlreadyAtMaxLevel and burns nothing
├── when amount > costToReach(tokenId, 5)
│   ├── costToReach(id, 5) + 1 reverts with Overshoot: balance, supply and cumulative unchanged (ACT-8)
│   └── burning costToReach(id, k) for k = 1…5 lands exactly on each level; 41,666 burned in all
├── when the token refuses (no allowance, too little balance)
│   └── the whole call reverts: nothing is recorded
├── when called again from inside the token's burnFrom
│   └── it reverts with Reentrancy and the whole call is undone, within the level-5 limit or not (ACT-4)
└── otherwise
    ├── the burn is recorded and burnFrom executes in one transaction; BearActivated is emitted;
    │   the holder's balance and the token supply fall by amount; a non-owner is refused (ACT-7)
    ├── cumulative and lifetimeBurned grow by amount, BearActivated is emitted and the owner's
    │   $MNTD falls by amount (ACT-4)
    ├── BearActivated(tokenId, burner, previousLevel, newLevel, amount, cumulative)
    ├── burns accumulate across calls
    ├── one burn spanning several thresholds jumps to the highest cleared
    └── one base unit short of a threshold stays below it; the last unit crosses it
```

When several checks fail at once, the first in the order `ContractPaused`, `ZeroAmount`,
`NotBearOwner`, `AlreadyAtMaxLevel`, `Overshoot` names the revert.

## Thresholds (ACT-2)

```
thresholds
├── 1,666 / 3,333 / 8,333 / 16,666 / 41,666 whole $MNTD with an 18-decimal token: a cumulative of
│   8,333 $MNTD reads level 3 and costToReach(id, 4) reads 8,333 × 10^18 (ACT-2)
├── read cumulatively: 41,666 in one burn and 41,666 level by level both stand at level 5
└── costToReach at a cumulative of 8,333: 0 for levels 0–3, the threshold less 8,333 for 4 and 5
```

Thresholds are constructor values with no setter (ACT-12 pins that nothing changes them).

## Weights (ACT-3)

```
weights
├── 100 / 110 / 125 / 145 / 170 / 200: a bear at level 3 reads weightOf 145; weightFor(5) reads 200 (ACT-3)
└── weightOf rises with each threshold crossed, and reads 100 again once the bear is sold
```

## Reset on transfer

```
after the bear is transferred
├── a bear at level 2 with a Status link: levelOf and cumulativeOf read 0, weightOf reads
│   weightFor(0), linkOf reads (0, 0), and the transfer made no call into Activation (ACT-5)
├── cumulativeOf and levelOf read 0; weightOf reads the level-0 weight
├── lifetimeBurned is unchanged; burned for twice with a transfer between, it is the sum of both (ACT-6)
├── across several owners and a return, lifetimeBurned sums every burn while cumulativeOf holds
│   only the current holding's
├── the new owner's burns start from 0
├── a transfer there and back does not restore the level
└── linkOf for the previous owner reads (0, 0)
```

## Linking

```
linkBear
├── when the caller does not own the bear: it reverts with NotBearOwner
├── when paused: it reverts with ContractPaused
└── otherwise: BearLinked; linkOf reads (tokenId, level); a second nomination replaces the first
    ├── a wallet owning a bear at level 2 reads (tokenId, 2); after the bear moves, (0, 0) (ACT-9)
    ├── the link's level follows later burns without a new nomination
    └── a wallet with several bears carries one link; the others count only as weight

unlinkBear
├── clears the nomination with BearUnlinked, without moving the bear
├── works while paused
└── with no nomination: does nothing, reverts nothing, emits nothing

linkOf
└── with no nomination: (0, 0)
```

## Views

```
thresholdFor: level 0 → 0; levels 1–5 → the constructor's whole figures in base units; above 5 → InvalidLevel
weightFor:    levels 0–5 → 100 / 110 / 125 / 145 / 170 / 200; above 5 → InvalidLevel
weightOf:     the weight of the bear's current level (100 unactivated, 145 at level 3)
costToReach:  the exact remainder, or 0 once reached; above 5 → InvalidLevel
every listed read answers for a bear that has been burned for; BEARS and MNTD are the deployed
              addresses and DECIMALS the token's decimals (ACT-14)
snapshot:     owner, level and weight for existing ids; zeroes for an id that does not exist
              snapshot([1, 2, 4445]): owner, level and weight for 1 and 2, zeroes for 4445 (ACT-10)
              a bear at 0x…dEaD is reported with that owner; per-wallet sums and the eligible total
              without it are taken off-chain from one snapshot
              an empty list returns an empty array; id 0 reads zeroes
```

## Events (ACT-13)

```
events, checked in the recorded logs against the documented signatures
├── BearActivated(tokenId, burner, previousLevel, newLevel, amount, cumulative) on a burn
├── BearLinked(wallet, tokenId) on a link; BearUnlinked(wallet, tokenId) on an unlink
└── PausedSet(paused) on a pause — each call emits exactly that one event (ACT-13)
```

## Construction

```
constructor
├── when the collection or the token is the zero address: it reverts with ZeroAddress
├── when the first threshold is zero, or thresholds are not strictly ascending: ThresholdsNotAscending
├── when weights are not strictly ascending: WeightsNotAscending
├── the thresholds are scaled by the token's decimals: a 6-decimal token reads DECIMALS 6 and
│   thresholdFor(1) = 1,666 × 10^6
├── decimals that would take a threshold past uint128: it reverts rather than truncating
└── otherwise: BEARS, MNTD and DECIMALS are set, the deployer owns it, not paused
```

## Ownership

```
Roles (ACT-12)
├── a non-owner's setPaused, and anyone's renounceOwnership, revert (ACT-12)
├── the complete external interface, read from the artifact, is exactly the pinned list — no
│   setter for the token, thresholds, weights or records, no freeze, no clawback, no way to
│   record a level but burn (ACT-12)
└── every owner function run in turn leaves the token, thresholds, weights and a bear's record unchanged

setPaused
├── by the owner: PausedSet each time; burns resume after unpausing
├── while paused, burn and linkBear revert with ContractPaused and no $MNTD is burned; reads,
│   unlinkBear and a transfer succeed (ACT-11)
├── no exemption: the owner's own burn and link revert while paused
├── the rehearsal window: only a burn between the owner's unpause and pause lands
└── by anyone else: Unauthorized

renounceOwnership
└── by the owner, paused or not, and by anyone else: RenounceDisabled; the owner can still pause
```

## Regression (test/poc/ForgedLevelRegression.t.sol)

```
the tranche-1 review's forged-level PoC, kept inverted (ACT-1, ACT-12)
└── setCrediter and credit are absent: the owner cannot record a level without a burn
```

## Auditor obligations (not implemented here)

- INV-4: `levelOf(id)` always equals the highest threshold cleared by `cumulativeOf(id)`.
- INV-5: `lifetimeBurned` never decreases, and equals the sum of all burns for the bear.
- INV-6: retired with the crediter's refs; the number is not reused.
- INV-7: a level recorded before a transfer is never readable after it.
- INV-8: `linkOf(wallet)` returns a non-zero bear only while that wallet owns it. Holds
  because every transfer advances the counter the link is pinned to.
- INV-9: a burn is recorded only when the caller owns the bear at the current counter value.
- INV-15: the sum of `amount` over every `BearActivated` equals the fall in $MNTD total supply
  caused by `Activation`, and the sum of every bear's `lifetimeBurned`.
- INV-16: no `burn` leaves a bear's cumulative above `thresholdFor(5)`.
- Fork-3: against the deployed $MNTD on 4663 (or its 46630 twin), `burnFrom` behaves as
  OpenZeppelin `ERC20Burnable` does — spends allowance, reduces supply, reverts on failure (CQ-2).
