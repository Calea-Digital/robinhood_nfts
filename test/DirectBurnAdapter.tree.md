# DirectBurnAdapter — branching tree

Scope note: invariants (INV-N) and fork tests are recorded here as obligations for the
auditor. They are deliberately not implemented as developer unit leaves. Leaves that satisfy
a requirement's Scenario cite it (`ACT-n`, `openspec/specs/activation/spec.md`).

## burn(tokenId, amount)

```
burn
├── when the caller does not own the bear (an unrelated wallet, an approved operator)
│   └── it reverts with NotOwner and burns nothing (ACT-7)
└── when the caller owns the bear
    ├── when the bear is at level 5
    │   └── it reverts with AlreadyAtMaxLevel and burns nothing
    ├── when amount > costToReach(tokenId, 5)
    │   ├── costToReach(id, 5) + 1 reverts with Overshoot: balance, supply and cumulative unchanged (ACT-8)
    │   └── exactly costToReach(tokenId, 5) passes and lands on level 5
    ├── burning costToReach(id, k) for k = 1…5 lands exactly on each level; 41,666 burned in all
    ├── when Activation is paused
    │   ├── credit reverts with ContractPaused and no $MNTD is burned
    │   └── the rehearsal window: only a burn between the owner's unpause and pause lands (ACT-11)
    ├── when amount is zero
    │   └── credit reverts with ZeroAmount
    ├── when the adapter is no longer the crediter
    │   └── credit reverts with NotCrediter and no $MNTD is burned
    ├── when the token refuses (no allowance, too little balance)
    │   └── the whole call reverts, the credit with it
    └── otherwise
        ├── credit and burnFrom execute in one transaction; BearActivated and BurnedForBear are
        │   emitted; the holder's balance and the token supply fall by amount (ACT-7)
        └── ref is the adapter's burn number: 1, 2, … and burnCount follows
```

## Hostile token

```
when burnFrom calls back into the holder, who burns again from inside it
├── the nested burn sees the cumulative already raised: past level 5 it reverts with Overshoot
│   and the whole transaction is undone
└── within the limit, both burns are credited and both amounts burned — no credit without its burn
```

## Reads and construction

```
MNTD, ACTIVATION: the constructor's addresses; burnCount starts at 0
constructor: a zero token or Activation address reverts with ZeroAddress
no owner() and no setter exist
```

## Auditor obligations (not implemented here)

- INV-1: the sum of `amount` over every `BurnedForBear` equals the fall in $MNTD total supply
  caused by the adapter, and equals the sum of the adapter's credits in `Activation`.
- INV-2: no `burn` leaves a bear's cumulative above `thresholdFor(5)`.
- Fork-1: against the deployed $MNTD on 4663 (or its 46630 twin), `burnFrom` behaves as
  OpenZeppelin `ERC20Burnable` does — spends allowance, reduces supply (CQ-2).
