# Activation — branching tree

Scope note: invariants (INV-N) and fork tests are recorded here as obligations for the
auditor. They are deliberately not implemented as developer unit leaves.

## burn

```
burn
├── when the amount is zero
│   └── it reverts with ZeroAmount
├── when the caller is not the current owner
│   ├── and the caller is an approved operator
│   │   └── it reverts with NotBearOwner
│   └── and the caller is unrelated
│       └── it reverts with NotBearOwner
├── when the contract is paused
│   └── it reverts with ContractPaused
├── when the bear is already at level 5
│   └── it reverts with AlreadyAtMaxLevel
└── when the caller is the current owner
    ├── and the amount is below the first threshold
    │   └── it banks the amount and the level stays 0
    ├── and the amount reaches a threshold exactly
    │   └── it raises the level to that threshold's level
    ├── and the amount spans several thresholds at once
    │   └── it raises the level to the highest threshold cleared
    ├── it accumulates across separate calls
    ├── it burns exactly the amount from the caller's balance
    ├── it increases lifetimeBurned
    └── it emits BearActivated with previous and new level
```

## Reset on transfer

```
after the bear is transferred
├── levelOf reads 0
├── cumulativeOf reads 0
├── lifetimeBurned is unchanged
├── a burn by the new owner starts accumulating from 0
└── linkOf for the previous owner reads (0, 0)
```

## Linking

```
linkBear
├── when the caller does not own the bear
│   └── it reverts with NotBearOwner
├── when the contract is paused
│   └── it reverts with ContractPaused
└── when the caller owns the bear
    ├── it records the nomination against the current transfer count
    └── when the wallet had already nominated another bear
        └── it replaces the previous nomination

unlinkBear
└── it clears the nomination without moving the bear
```

## Views

```
costToReach
├── when the target level is already reached
│   └── it returns 0
└── otherwise
    └── it returns the exact remaining amount

thresholdFor
├── level 0 returns 0
└── levels 1 to 5 return the configured thresholds
```

## Construction

```
constructor
├── when the thresholds are not strictly ascending
│   └── it reverts with ThresholdsNotAscending
├── when the first threshold is zero
│   └── it reverts with ThresholdsNotAscending
└── otherwise
    └── it scales every threshold by the token's decimals
```

## Auditor obligations (not implemented here)

- INV-4: `levelOf(id)` always equals the highest threshold cleared by `cumulativeOf(id)`.
- INV-5: `lifetimeBurned` never decreases.
- INV-6: the sum of all burns equals the reduction in $MNTD total supply.
- INV-7: a level recorded before a transfer is never readable after it.
