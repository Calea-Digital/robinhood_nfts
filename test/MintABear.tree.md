# MintABear — branching tree

Scope note: invariants (INV-N) and fork tests are recorded here as obligations for the
auditor. They are deliberately not implemented as developer unit leaves.

## _beforeTokenTransfers

```
_beforeTokenTransfers
├── when from is the zero address (mint)
│   ├── it records each minted bear's canonical account address
│   ├── it does not advance the transfer counter
│   └── when the destination is an already-recorded bear account
│       └── it reverts with TransferToBearAccount
└── when from is not the zero address (transfer)
    ├── it advances that bear's transfer counter by exactly one
    ├── when the destination is a deployed bear account
    │   └── it reverts with TransferToBearAccount
    └── when the destination is a bear account that was never deployed
        └── it reverts with TransferToBearAccount
```

## accountOf / deployAccount

```
accountOf
└── it returns the canonical ERC-6551 address for the pinned implementation and salt

deployAccount
├── when the bear does not exist
│   └── it reverts
├── when the account has never been deployed
│   └── it deploys at exactly the address accountOf predicted
└── when the account already exists
    └── it returns the same address without reverting
```

## tokenURI / setRenderer

```
tokenURI
├── when the bear does not exist
│   └── it reverts with URIQueryForNonexistentToken
└── when the bear exists
    └── it returns whatever the renderer returns

setRenderer
├── when the caller is not the owner
│   └── it reverts
├── when the new renderer is the zero address
│   └── it reverts with RendererIsZeroAddress
└── when the caller is the owner
    └── it replaces the renderer and emits RendererUpdated
```

## Supply and numbering

```
supply
├── it starts token ids at 1
└── when a mint would exceed maxSupply
    └── it reverts
```

## Auditor obligations (not implemented here)

- INV-1: no bear is ever owned by any address in `isBearAccount`.
- INV-2: `transferNonce` is monotonically non-decreasing for every bear.
- INV-3: `totalSupply` never exceeds 4,444.
- Fork-1: minting through the real SeaDrop contract on Robinhood Chain.
