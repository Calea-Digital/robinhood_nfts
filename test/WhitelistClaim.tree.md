# WhitelistClaim — branching tree

Scope note: invariants (INV-N) and fork tests are recorded here as obligations for the
auditor. They are deliberately not implemented as developer unit leaves. Leaves that satisfy
a requirement's Scenario cite it (`WL-n`, `openspec/specs/whitelist/spec.md`).

## claim(voucher, signature)

```
claim
├── when msg.sender is not voucher.wallet
│   └── it reverts with NotClaimant, before and after the wallet's own claim (WL-3)
└── when msg.sender is voucher.wallet
    ├── when the signature does not recover to signer
    │   ├── signed by another key: it reverts with BadSigner
    │   ├── account, allocation or deadline altered after signing: it reverts with BadSigner
    │   ├── neither 64 nor 65 bytes: it reverts with BadSigner, never matching a zero signer
    │   └── signed for another deployment: it reverts with BadSigner (the domain binds the contract)
    └── when the signature recovers to signer (65 bytes, or 64 in EIP-2098 form)
        ├── when block.timestamp > deadline
        │   └── it reverts with Expired; at exactly the deadline it succeeds
        └── when block.timestamp ≤ deadline
            ├── when the window is not open (before openAt or after closeAt)
            │   └── it reverts with CampaignClosed
            └── when the window is open
                ├── when all TOTAL_SPOTS are claimed
                │   └── it reverts with SoldOut and changes nothing
                └── when spots are left
                    ├── when the wallet holds MAX_PER_WALLET
                    │   └── it reverts with WalletLimit
                    ├── when allocationIndex ≠ claimsOf(wallet) + 1
                    │   ├── out of order (2 first, or 0): it reverts with WrongAllocation
                    │   └── a spent voucher presented again: it reverts with WrongAllocation
                    ├── when the account has claimed MAX_PER_ACCOUNT
                    │   └── it reverts with AccountLimit
                    └── otherwise
                        ├── spotsLeft falls by one, claimsOf(W) reads 1, WhitelistClaimed is emitted (WL-3)
                        ├── the account's count increases
                        ├── the wallet is appended to the claimant list on its first claim only
                        └── spotNumber counts from 1 across the campaign
```

When several checks fail at once, the first in the order `NotClaimant`, `BadSigner`, `Expired`,
`CampaignClosed`, `SoldOut`, `WalletLimit`, `WrongAllocation`, `AccountLimit` names the revert.

## Reads

```
reads
├── TOTAL_SPOTS is 1,000; MAX_PER_WALLET and MAX_PER_ACCOUNT are 2
├── spotsLeft starts at 1,000
├── signer, openAt, closeAt and owner are the constructor's values
├── eip712Domain names "WhitelistClaim" version "1" on this chain at this address
└── claimants(offset, limit)
    ├── when the list is empty, it returns no rows
    ├── when the page runs past the end, it is short
    └── when offset is at or past the end, it is empty rather than reverting
```

## Owner functions

```
setSigner
├── when the caller is not the owner: it reverts with Unauthorized
├── when the signer is the zero address: it reverts with ZeroSigner
└── otherwise: SignerSet is emitted, the previous signer's vouchers revert with BadSigner

setWindow
├── when the caller is not the owner: it reverts with Unauthorized
├── when openAt ≥ closeAt: it reverts with InvalidWindow
└── otherwise: WindowSet is emitted and openAt / closeAt read the new values

constructor
├── when the owner is the zero address: it reverts with NewOwnerIsZeroAddress
├── when the signer is the zero address: it reverts with ZeroSigner
└── when openAt ≥ closeAt: it reverts with InvalidWindow

transferOwnership
└── the new owner holds setSigner and setWindow; the previous owner does not
```

No function removes, reassigns or adds a claim; there is nothing to test for it but its absence
from the interface.

## Invariants (auditor's obligations — documented, not implemented)

- INV-1: `TOTAL_SPOTS - spotsLeft()` equals the sum of `claimsOf` over every wallet, and the
  sum of `accountClaims` over every account.
- INV-2: `spotsLeft()` never increases, and never goes below zero.
- INV-3: `claimsOf(w) ≤ MAX_PER_WALLET` and `accountClaims(a) ≤ MAX_PER_ACCOUNT` for every
  `w` and `a`.
- INV-4: `claimants` lists each wallet with `claimsOf(w) > 0` exactly once, with
  `allocations == claimsOf(w)`, and no other wallet.
- INV-5: every successful claim was sent by `voucher.wallet` with a signature recovering to the
  `signer` in force at that moment, inside the window and before the voucher's deadline.
