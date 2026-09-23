# WhitelistClaim — branching tree

Scope note: invariants (INV-N) and fork tests are recorded here as obligations for the
auditor. They are deliberately not implemented as developer unit leaves. Leaves that satisfy
a requirement's Scenario cite it (`WL-n`, `openspec/specs/whitelist/spec.md`).

INV-N and Fork-N are numbered once across all trees and never reused: `MintABear` INV-1…3 (INV-1 retired), `Activation` INV-4…9, `WhitelistClaim` INV-10…14, `DirectBurnAdapter` INV-15…16; Fork-1 (real SeaDrop mint), Fork-2 (real validator V3), Fork-3 (real $MNTD `burnFrom`).

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

## Campaign rules (WL-1)

```
rules
├── two per wallet, two per account
│   └── a wallet and an account each at one: allocation 2 succeeds, both read 2, a third for
│       either reverts with WalletLimit / AccountLimit (WL-1)
├── one call per allocation: allocation 1 now, allocation 2 days later; the wallet is listed once
├── an account spread over wallets is capped at two, whichever wallets it uses
├── a wallet's limit counts allocations, not accounts: two accounts may give one wallet its two
└── the last spot: one claim takes spot 1,000, the next reverts with SoldOut and leaves nothing
```

The eligibility thresholds ($50 / $100, the Season 1 back-credit) are MINT's data (WL-2): the
contract sees only the signed voucher, so a threshold has no leaf here.

## Export into the mint (WL-4)

```
export
├── when the campaign has closed
│   ├── claimants read page by page returns every wallet once, in order of its first claim,
│   │   with allocations == claimsOf, totalling TOTAL_SPOTS - spotsLeft (WL-4)
│   └── the allowlist built from those rows (leaf = keccak256(abi.encode(wallet, mintParams)),
│       maxTotalMintableByWallet = allocations) and set on SeaDrop carries the same rows (WL-4)
│       ├── each wallet mints exactly its allocations; one more is refused per wallet
│       ├── a wallet not in the export is refused with InvalidProof
│       └── a row claimed with a higher limit than exported is refused with InvalidProof
└── when the campaign sold out before closing
    └── 500 rows of two allocations, totalling 1,000
```

Not a unit leaf: that OpenSea Studio's CSV import produces the same root as the rows above is
rehearsal item 3 on 46630 (`docs/HANDOVER.md`, "Unknowns to settle by rehearsal").

## Timing (WL-5)

```
window
├── with the close at least 48 hours before the whitelist stage
│   └── a claim before openAt, after closeAt, or at the stage's start reverts with CampaignClosed (WL-5)
├── a claim at exactly openAt and at exactly closeAt succeeds
├── setWindow moves the gate: a claim outside the old window and inside the new one succeeds;
│   moving closeAt back closes the campaign; claims already made stay
└── the registry is deployed with its signer and window set before openAt
```

The 48-hour gap and the dates themselves (proposed 6–26 October, CQ-1 / CQ-18) are deployment
values: the registry does not know when the whitelist stage opens, so the gap is checked by the
deploy script and the runbook (OPS-2), not by the contract.

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

- INV-10: `TOTAL_SPOTS - spotsLeft()` equals the sum of `claimsOf` over every wallet, and the
  sum of `accountClaims` over every account.
- INV-11: `spotsLeft()` never increases, and never goes below zero.
- INV-12: `claimsOf(w) ≤ MAX_PER_WALLET` and `accountClaims(a) ≤ MAX_PER_ACCOUNT` for every
  `w` and `a`.
- INV-13: `claimants` lists each wallet with `claimsOf(w) > 0` exactly once, with
  `allocations == claimsOf(w)`, and no other wallet.
- INV-14: every successful claim was sent by `voucher.wallet` with a signature recovering to the
  `signer` in force at that moment, inside the window and before the voucher's deadline.
