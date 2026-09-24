# MintABear — branching tree

Scope note: invariants (INV-N) and fork tests are recorded here as obligations for the
auditor. They are deliberately not implemented as developer unit leaves. Leaves that satisfy
a requirement's Scenario cite it (`COL-n`, `openspec/specs/collection/spec.md`).

INV-N and Fork-N are numbered once across all trees and never reused: `MintABear` INV-1…3 (INV-1 retired), `Activation` INV-4…9, `WhitelistClaim` INV-10…14, `DirectBurnAdapter` INV-15…16; Fork-1 (real SeaDrop mint), Fork-2 (real validator V3), Fork-3 (real $MNTD `burnFrom`).

## _beforeTokenTransfers

```
_beforeTokenTransfers
├── when the mint would pass MAX_BEARS (COL-2)
│   ├── it reverts with ExceedsMaxBears
│   ├── it reverts even when the owner has raised maxSupply
│   ├── when maxSupply is at exactly 4,444, SeaDrop's own sold-out check refuses first
│   └── when a batch straddles the cap
│       └── the whole batch is refused, never partly filled
├── when to is the zero address (burn, COL-8)
│   ├── and the caller is the owner
│   │   └── it reverts with BurnDisabled
│   ├── and the caller is an approved operator
│   │   └── it reverts with BurnDisabled
│   ├── and the caller is neither
│   │   └── ERC721A's approval check refuses it before the hook
│   └── it leaves supply, ownership and the transfer counter untouched
├── when from is the zero address (mint)
│   ├── it does not advance the transfer counter: every freshly minted bear reads 0 (COL-3)
│   └── it emits no TransferNonceAdvanced
└── when from is not the zero address (transfer)
    ├── it advances that bear's transfer counter by exactly one (COL-3)
    │   ├── on a sale or gift, a return to a previous owner, a self-transfer and an operator move alike
    │   ├── per bear: the other bears in a batch still read 0
    │   └── it never decreases and nothing resets it
    ├── it emits TransferNonceAdvanced(tokenId, nonce) in the same transaction as Transfer (COL-4)
    │   ├── whether or not the bear has a level
    │   ├── with nonce equal to the counter after the transfer
    │   └── on every transfer: sale, gift, return to a previous owner, operator move
    └── it accepts any non-zero destination; there is no account guard (COL-9)
```

## transferFrom / safeTransferFrom (COL-8)

```
transferFrom
├── when to is the zero address
│   ├── it reverts with BurnDisabled, ahead of ERC721A's own TransferToZeroAddress
│   ├── safeTransferFrom, both overloads, answers the same because it routes through here
│   └── totalSupply, the owner and the transfer counter are unchanged
└── when to is the canonical dead address
    └── it is an ordinary transfer: the bear stays in the supply (the royalty split
        excludes the address off-chain, ACT-10)
```

## Regression (test/poc/BurnStrandsAccount.t.sol)

```
the pre-audit burn PoC, kept inverted (COL-8)
├── the owner's burn reverts with BurnDisabled
├── an approved operator's burn reverts with BurnDisabled
└── supply and ownership are unchanged afterwards
```

## Token-bound accounts (COL-9)

```
no token-bound accounts
├── the entry points accountOf, deployAccount, recordAccounts, isBearAccount,
│   ACCOUNT_IMPLEMENTATION and ACCOUNT_SALT are not in the ABI
├── the standard's account surface — token, state, isValidSigner, execute — is not in the ABI,
│   and supportsInterface is false for IERC6551Account and IERC6551Executable
├── the canonical registry address appears nowhere in the deployed bytecode
└── an address the registry would derive for a bear is an ordinary destination
```

## Metadata (COL-5)

```
tokenURI
├── when the bear does not exist
│   └── it reverts with URIQueryForNonexistentToken
├── when baseURI ends with a slash
│   ├── it returns baseURI followed by the id
│   └── raising the bear's level changes nothing in it
├── when baseURI has no trailing slash
│   └── it returns baseURI alone — SeaDrop's pre-reveal shape
└── when baseURI is empty
    └── it returns the empty string

setBaseURI
└── when the caller is not the owner
    └── it reverts with OnlyOwner
```

## Reads (COL-12)

```
reads
├── ownerOf, exists, totalSupply, maxSupply, MAX_BEARS, transferNonce, tokenURI, royaltyInfo,
│   getTransferValidator and getMintStats all answer for a minted bear
└── exists
    ├── it is false for id 0, for the next unminted id and for ids beyond the supply
    └── it stays true after a transfer: it follows minting, not ownership
```

## Events (COL-13)

```
events
├── Transfer(from, to, tokenId), Approval(owner, approved, tokenId) and
│   ApprovalForAll(owner, operator, approved) are ERC721A's, unchanged
├── TransferNonceAdvanced(tokenId, nonce) fires with Transfer on every non-mint transfer (COL-4)
├── TransferValidatorUpdated(oldValidator, newValidator) fires on every validator change (COL-7)
│   └── setting the same value again reverts with SameTransferValidator, so no empty event
└── SeaDrop configuration events are the base's own and are not re-tested here
```

## Creator token and enforced royalties (COL-7)

```
transfer validator
├── it starts unset; the deploy script sets Limit Break V3 (OPS-2)
├── setTransferValidator is owner-only and emits TransferValidatorUpdated(old, new)
├── getTransferValidationFunction returns validateTransfer's selector, not a view
├── supportsInterface advertises ICreatorToken and the legacy id
└── with V3's zero-state policy set (modelled by MockTransferValidator)
    ├── a transfer the holder initiates passes
    ├── an authorised caller — a SignedZone-authorised OpenSea fill, a Payment Processor venue — settles a sale
    ├── an operator from any other venue reverts, and the counter does not move
    ├── minting is unaffected: the validator is consulted for transfers only
    ├── the burn refusal is unaffected
    └── setTransferValidator(address(0)) lifts enforcement and setting V3 again restores it (OPS-6)
```

## Ownership (COL-10)

```
ownership
├── the deployer (Calea) is the owner at construction
├── transferOwnership(admin) emits PotentialOwnerUpdated and moves nothing until acceptance
│   ├── to the zero address it reverts with NewOwnerIsZeroAddress
│   └── by a non-owner it reverts with OnlyOwner
├── acceptOwnership by the admin emits OwnershipTransferred and makes the admin the owner
│   ├── by anyone else it reverts with NotNextOwner
│   └── after cancelOwnershipTransfer it reverts with NotNextOwner
└── afterwards Calea holds no role: every owner function refuses the deployer, and the admin
    operates the drop while SeaDrop still mints
```

## Supply and numbering (COL-2)

```
supply
├── it starts token ids at 1
├── MAX_BEARS reads 4,444 and is a constant
├── minting exactly to the cap succeeds, and the supply is then exactly 4,444
├── when a mint would exceed maxSupply
│   └── it reverts with SeaDrop's MintQuantityExceedsMaxSupply(total, maxSupply)
└── maxSupply stays owner-settable, which is why MAX_BEARS and not maxSupply is the
    guarantee the collection actually makes
```

## Auditor obligations (not implemented here)

- INV-1: retired with the account guard (COL-9); the number is not reused.
- INV-2: `transferNonce` is monotonically non-decreasing for every bear.
- INV-3: `totalSupply` never exceeds `MAX_BEARS` and never decreases, for any value of the
  owner-settable `maxSupply`.
- Fork-1: minting through the real SeaDrop contract on Robinhood Chain.
- Fork-2: the real Limit Break validator V3 at `0x721C002B0059009a671D00aD1700c9748146cd1B` on
  chain 4663 with its zero-state policy (security level 0, list 0, OpenSea's SignedZone
  `0x000056F7000000EcE9003ca63978907a00FFD100` as authorizer): a holder transfer passes, a
  SignedZone-restricted Seaport fill passes, a Seaport fill from another venue reverts. The OpenSea
  Conduit is not deployed on 4663 and orders use conduitKey 0, so the caller V3 sees on a fill is
  Seaport 1.6 `0x0000000000000068F116a894984e2DB1123eB395`, authorised by the SignedZone on the
  validator; the SignedZone does not move the bear. SeaDrop calls `validateTransfer` through a
  `view` interface — a STATICCALL — while `getTransferValidationFunction` reports it as non-view,
  so the authorised fill must succeed under STATICCALL. The unit leaves above model the policy with
  `MockTransferValidator`, whose one list stands for both whitelisted operators and authorised
  callers; only a fork can confirm the real one.
