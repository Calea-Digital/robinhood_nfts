# MintABear — branching tree

Scope note: invariants (INV-N) and fork tests are recorded here as obligations for the
auditor. They are deliberately not implemented as developer unit leaves. Leaves that satisfy
a requirement's Scenario cite it (`COL-n`, `openspec/specs/collection/spec.md`).

## _beforeTokenTransfers

```
_beforeTokenTransfers
├── when the mint would pass MAX_BEARS
│   ├── it reverts with ExceedsMaxBears
│   ├── it reverts even when the owner has raised maxSupply
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
│   ├── it does not advance the transfer counter
│   └── it emits no TransferNonceAdvanced
└── when from is not the zero address (transfer)
    ├── it advances that bear's transfer counter by exactly one
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

## Token-bound accounts (COL-9)

```
no token-bound accounts
├── the entry points accountOf, deployAccount, recordAccounts, isBearAccount,
│   ACCOUNT_IMPLEMENTATION and ACCOUNT_SALT are not in the ABI
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

## Supply and numbering

```
supply
├── it starts token ids at 1
├── MAX_BEARS reads 4,444 and is a constant
├── minting exactly to the cap succeeds
├── when a mint would exceed maxSupply
│   └── it reverts
└── maxSupply stays owner-settable, which is why MAX_BEARS and not maxSupply is the
    guarantee the collection actually makes
```

## Auditor obligations (not implemented here)

- INV-1: retired with the account guard (COL-9); the number is not reused.
- INV-2: `transferNonce` is monotonically non-decreasing for every bear.
- INV-3: `totalSupply` never exceeds `MAX_BEARS` and never decreases, for any value of the
  owner-settable `maxSupply`.
- Fork-1: minting through the real SeaDrop contract on Robinhood Chain.
