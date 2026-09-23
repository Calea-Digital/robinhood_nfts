# Activation — branching tree

Scope note: invariants (INV-N) and fork tests are recorded here as obligations for the
auditor. They are deliberately not implemented as developer unit leaves. Leaves that satisfy
a requirement's Scenario cite it (`ACT-n`, `openspec/specs/activation/spec.md`).

## Token-agnostic (ACT-1)

```
Activation
├── holds no $MNTD reference: no token getter, no burn entry point, no token in the constructor (ACT-1)
├── moves no tokens and sends no value (ACT-1)
└── calls nothing but MintABear, and only its views ownerOf, transferNonce and exists —
    across construction, credit, link, unlink and every read (ACT-1)
```

## credit(tokenId, burner, amount, nonce, ref)

```
credit
├── when the caller is not the crediter (the owner and the holder included)
│   └── it reverts with NotCrediter
└── when the caller is the crediter
    ├── when paused
    │   └── it reverts with ContractPaused
    ├── when amount is zero
    │   └── it reverts with ZeroAmount
    ├── when burner does not own the bear (an approved operator, an unrelated wallet)
    │   └── it reverts with NotBearOwner
    ├── when transferNonce ≠ nonce (the bear moved, even if it came back)
    │   └── it reverts with StaleNonce
    ├── when this crediter already recorded ref
    │   └── it reverts with RefAlreadyUsed and records nothing twice
    └── otherwise
        ├── cumulative and lifetimeBurned grow by amount, BearActivated is emitted, and the same
        │   ref again reverts with RefAlreadyUsed, leaving both unchanged (ACT-4)
        ├── the level follows the cumulative
        ├── BearActivated(tokenId, burner, previousLevel, newLevel, amount, cumulative, ref)
        ├── credits accumulate across calls
        ├── one credit spanning several thresholds jumps to the highest cleared
        ├── one base unit short of a threshold stays below it; the last unit crosses it
        └── past level 5 it is still recorded — refusing it is the adapter's job (ACT-8)
```

When several checks fail at once, the first in the order `NotCrediter`, `ContractPaused`,
`ZeroAmount`, `NotBearOwner`, `StaleNonce`, `RefAlreadyUsed` names the revert.

## Thresholds (ACT-2)

```
thresholds
├── 1,666 / 3,333 / 8,333 / 16,666 / 41,666 in base units: a cumulative of 8,333 reads level 3
│   and costToReach(id, 4) reads 8,333 (ACT-2)
├── read cumulatively: 41,666 in one credit and 41,666 level by level both stand at level 5
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
├── lifetimeBurned is unchanged; credited twice with a transfer between, it is the sum of both (ACT-6)
├── across several owners and a return, lifetimeBurned sums every credit while cumulativeOf holds
│   only the current holding's
├── the new owner's credits start from 0
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
    ├── the link's level follows later credits without a new nomination
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
thresholdFor: level 0 → 0; levels 1–5 → the constructor's base units, unscaled; above 5 → InvalidLevel
weightFor:    levels 0–5 → 100 / 110 / 125 / 145 / 170 / 200; above 5 → InvalidLevel
weightOf:     the weight of the bear's current level (100 unactivated, 145 at level 3)
costToReach:  the exact remainder, or 0 once reached; above 5 → InvalidLevel
snapshot:     owner, level and weight for existing ids; zeroes for an id that does not exist
              snapshot([1, 2, 4445]): owner, level and weight for 1 and 2, zeroes for 4445 (ACT-10)
              a bear at 0x…dEaD is reported with that owner; per-wallet sums and the eligible total
              without it are taken off-chain from one snapshot
              an empty list returns an empty array; id 0 reads zeroes
```

## Events (ACT-13)

```
events, checked in the recorded logs against the documented signatures
├── BearActivated(tokenId, burner, previousLevel, newLevel, amount, cumulative, ref) on a credit
├── BearLinked(wallet, tokenId) on a link; BearUnlinked(wallet, tokenId) on an unlink
├── CrediterSet(previous, current) on a crediter change
└── PausedSet(paused) on a pause — each call emits exactly that one event (ACT-13)
```

## Construction

```
constructor
├── when the collection is the zero address: it reverts with ZeroAddress
├── when the first threshold is zero, or thresholds are not strictly ascending: ThresholdsNotAscending
├── when weights are not strictly ascending: WeightsNotAscending
└── otherwise: BEARS is the collection, the deployer owns it, not paused, no crediter until set
```

## Ownership

```
Roles (ACT-12)
├── a non-owner's setCrediter and setPaused revert (ACT-12)
├── the complete external interface, read from the artifact, is exactly the pinned list — no
│   setter for thresholds, weights or records, no freeze, no clawback (ACT-12)
├── every owner function run in turn leaves thresholds, weights and a bear's record unchanged
└── the adapter's interface is burn plus MNTD, ACTIVATION and burnCount: no owner, no settings

setCrediter
├── by the owner: CrediterSet(previous, current); the new crediter credits, the old one cannot
│   └── refs are per crediter: a replacement numbering from 1 is accepted; each crediter's spent refs stay spent
└── by anyone else: Unauthorized

setPaused
├── by the owner: PausedSet each time; credits resume after unpausing
├── while paused, credit and linkBear revert with ContractPaused; reads, unlinkBear and a transfer
│   succeed (ACT-11)
├── no exemption: the owner's own linkBear and any credit revert while paused
└── by anyone else: Unauthorized

renounceOwnership
├── while paused: CannotRenounceWhilePaused, so a pause can always be lifted
├── while running: succeeds and the crediter still credits
└── by anyone else: Unauthorized
```

## Auditor obligations (not implemented here)

- INV-4: `levelOf(id)` always equals the highest threshold cleared by `cumulativeOf(id)`.
- INV-5: `lifetimeBurned` never decreases, and equals the sum of all credits to the bear.
- INV-6: every `(crediter, ref)` is credited at most once.
- INV-7: a level recorded before a transfer is never readable after it.
- INV-8: `linkOf(wallet)` returns a non-zero bear only while that wallet owns it. Holds
  because every transfer advances the counter the link is pinned to.
- INV-9: a credit is recorded only when `burner` owned the bear at counter value `nonce` and
  still does; with the adapter (ACT-7), the sum of credits equals the $MNTD it burned.
