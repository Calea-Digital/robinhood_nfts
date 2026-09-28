# WhitelistImport — branching tree

Scope note: invariants (INV-N) and fork tests are recorded here as obligations for the
auditor. They are deliberately not implemented as developer unit leaves. Leaves that satisfy
a requirement's Scenario cite it (`WL-n`, `openspec/specs/whitelist/spec.md`).

INV-N and Fork-N are numbered once across all trees and never reused: `MintABear` INV-1…3 (INV-1 retired), `Activation` INV-4…9 (INV-6 retired) and INV-15…16, `WhitelistClaim` INV-10…14, `WhitelistImport` INV-17…20; Fork-1 (real SeaDrop mint), Fork-2 (real validator V3), Fork-3 (real $MNTD `burnFrom`).

`WhitelistImport` is WL-7, the owner-imported variant of the registry; `WhitelistClaim` (WL-3) is
the voucher variant, and MINT deploys one of the two (CQ-18). `WhitelistImport` is never audited
(MINT, 28 September 2026): the invariants below are recorded for completeness, not booked.

## The freeze (WL-7)

```
import then freeze
└── given closeAt not passed, the owner adds A (2) and B (1), and closeAt then passes
    ├── claimsOf(A) reads 2, claimsOf(B) reads 1, spotsLeft reads 997 (WL-7)
    └── addAllocations, removeAllocations and setCloseAt each revert with ListFrozen (WL-7)
frozen()
├── false before closeAt and at exactly closeAt: a write at closeAt succeeds
└── true from closeAt + 1
```

## addAllocations(wallets, counts)

```
addAllocations
├── when the caller is not the owner: it reverts with Unauthorized
├── when the list is frozen: it reverts with ListFrozen
├── when the arrays differ in length: it reverts with LengthMismatch
└── for each row in turn
    ├── when the wallet is the zero address: it reverts with ZeroWallet
    ├── when the count is zero: it reverts with ZeroCount
    ├── when the wallet would hold more than MAX_PER_WALLET
    │   ├── a count of 3 at once: it reverts with WalletLimit
    │   ├── 1 on top of 2 held: it reverts with WalletLimit
    │   ├── a count of 255 on top of 2: it reverts with WalletLimit, not an overflow panic
    │   └── one wallet named twice in the batch, 2 then 1: it reverts with WalletLimit
    ├── when the running total would exceed TOTAL_SPOTS: it reverts with SoldOut
    │   └── 500 wallets of 2 fill the list; one more allocation reverts with SoldOut
    └── otherwise
        ├── AllocationsAdded(wallet, count, total) is emitted, total the wallet's new holding
        ├── a new wallet is appended to the list; a wallet at 1 given 1 more is not listed twice
        └── spotsLeft falls by the batch's sum
a batch with one bad row changes nothing: no count, no row, no event
an empty batch changes nothing and succeeds
```

When several checks fail at once, the first in the order `Unauthorized`, `ListFrozen`,
`LengthMismatch`, then per row `ZeroWallet`, `ZeroCount`, `WalletLimit`, `SoldOut` names the
revert.

## removeAllocations(wallets)

```
removeAllocations
├── when the caller is not the owner: it reverts with Unauthorized
├── when the list is frozen: it reverts with ListFrozen
├── when a wallet holds no allocations: it reverts with NotListed
│   └── a wallet named twice: the second is not listed, and the whole call reverts
└── otherwise
    ├── claimsOf(wallet) reads 0, spotsLeft rises by its count, AllocationsRemoved is emitted
    ├── the last row moves into the gap: claimants stays dense, each listed wallet once
    ├── removing the last row, and the only row, leaves the list consistent
    └── a removed wallet can be added again, and is listed once
```

## setCloseAt(closeAt)

```
setCloseAt
├── when the caller is not the owner: it reverts with Unauthorized
├── when the list is frozen: it reverts with ListFrozen
├── when the new close is in the past: it reverts with InvalidWindow
└── otherwise: CloseSet is emitted and closeAt reads the new value
    ├── a later close extends the import
    └── a close at the current timestamp freezes the list from the next second
```

## Constructor and ownership

```
constructor
├── when the owner is the zero address: it reverts with NewOwnerIsZeroAddress
├── when closeAt is in the past: it reverts with InvalidWindow
└── otherwise: owner and closeAt are the constructor's, CloseSet is emitted, spotsLeft is 1,000

transferOwnership
└── the new owner holds addAllocations, removeAllocations and setCloseAt; the previous owner does not

renounceOwnership
└── it reverts with RenounceDisabled for every caller, the owner included
```

## Reads (shared with WhitelistClaim)

```
reads
├── TOTAL_SPOTS is 1,000; MAX_PER_WALLET is 2
└── claimants(offset, limit)
    ├── when the list is empty, it returns no rows
    ├── when the page runs past the end, it is short
    ├── when offset is at or past the end, it is empty rather than reverting
    └── rows carry allocations == claimsOf, totalling TOTAL_SPOTS - spotsLeft
```

The export and the Studio compare over this registry are `test/WhitelistExport.t.sol`'s
(`WhitelistExport.tree.md`); the deploy entry point is `test/Deploy.t.sol`'s.

## Invariants (auditor's obligations — documented, not implemented)

- INV-17: `TOTAL_SPOTS - spotsLeft()` equals the sum of `claimsOf` over every wallet.
- INV-18: `claimsOf(w) ≤ MAX_PER_WALLET` for every `w`, and `spotsLeft()` never goes below zero.
- INV-19: `claimants` lists each wallet with `claimsOf(w) > 0` exactly once, with
  `allocations == claimsOf(w)`, and no other wallet.
- INV-20: once `frozen()` is true it stays true, and no state of the list changes afterwards.
