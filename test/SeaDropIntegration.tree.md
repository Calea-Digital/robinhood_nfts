# SeaDrop integration — branching tree

Scope note: this tree covers the boundary between what OpenSea Studio configures and what
the collection enforces for itself. It is not a fifth contract; it pins behaviour that spans
`MintABear` and its `ERC721SeaDrop` base.

Only two functions on `ERC721SeaDrop` that matter here are `virtual`: `mintSeaDrop` and
`tokenURI`. `getMintStats`, `setMaxSupply`, `setBaseURI`, `setProvenanceHash`,
`setRoyaltyInfo`, `multiConfigure` and `burn` are all final. Anything the collection needs
to enforce against them happens in `_beforeTokenTransfers`, which is the one hook ERC721A
leaves open.

## Mint path

```
mintSeaDrop
├── when the caller is not an allowed SeaDrop
│   └── SeaDrop's own guard refuses it
└── when the caller is allowed
    ├── it mints sequentially from id 1
    └── it does not advance the transfer counter

getMintStats
├── it reports each wallet's own minted count, which drives per-wallet limits
└── burning cannot reset that count, because burning is refused
```

## Supply: where Studio and the cap meet

```
maxSupply
├── when configured below MAX_BEARS
│   └── SeaDrop's MintQuantityExceedsMaxSupply fires — the normal sold-out path
├── when configured above MAX_BEARS
│   ├── minting still stops at 4,444, with ExceedsMaxBears
│   └── getMintStats reports the configured value, not the real ceiling
└── it is owner-settable and Studio writes it through multiConfigure
```

**The one mismatch that cannot be fixed in code.** `getMintStats` is final, so the collection
cannot report a clamped ceiling to SeaDrop. Configure `maxSupply` above `MAX_BEARS` and
Studio's UI advertises a supply the token will not deliver; buyers past 4,444 pay gas for a
reverting transaction. The collection cannot be inflated either way — that is what the cap
guarantees — but the deploy runbook must set `maxSupply` to exactly 4,444, and nobody may
raise it afterwards.

## Metadata

```
multiConfigure
└── it applies maxSupply, baseURI, contractURI and provenanceHash

baseURI
├── it is stored and readable
└── it is never served: tokenURI is overridden and answers from the renderer
```

**Known clash.** A Studio-managed drop configures metadata through `baseURI`. This collection
serves metadata on-chain through a replaceable renderer, so `setBaseURI` succeeds and has no
effect. It is not an error and nothing reverts, which is what makes it worth writing down.

```
setProvenanceHash
├── recordAccounts does not count as minting, so provenance can still be set after it
└── after the first mint it reverts
```

## Secondary trading

```
royaltyInfo
└── it answers normally; nothing here touches ERC-2981

operator transfers
└── an approved-for-all operator can move a bear, which is how Seaport's conduit works

recordAccounts
└── recording the full supply blocks only the derived account addresses; holders,
    operators, marketplaces and fee recipients are unaffected

transferValidator
└── it stays unset, so the conduit and smart wallets can move bears
```

## ERC-165

```
supportsInterface
└── ERC-165, ERC-721, ERC-721 Metadata, ERC-2981, ERC-4906,
    ISeaDropTokenContractMetadata and INonFungibleSeaDropToken all read true
```

## Auditor obligations (not implemented here)

- Fork-1: a real mint through the canonical SeaDrop at
  `0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` on chain 4663, with a configured drop stage.
- **Unanswerable off-chain:** whether OpenSea Studio will attach to a self-deployed contract,
  and whether an on-chain `tokenURI` renders inside a Studio-managed drop. Both are listed in
  `docs/HANDOVER.md` as testnet unknowns.
