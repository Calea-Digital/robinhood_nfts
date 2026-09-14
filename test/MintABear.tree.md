# MintABear — branching tree

Scope note: invariants (INV-N) and fork tests are recorded here as obligations for the
auditor. They are deliberately not implemented as developer unit leaves.

## _beforeTokenTransfers

```
_beforeTokenTransfers
├── when the mint would pass MAX_BEARS
│   ├── it reverts with ExceedsMaxBears
│   ├── it reverts even when the owner has raised maxSupply
│   └── when a batch straddles the cap
│       └── the whole batch is refused, never partly filled
├── when to is the zero address (burn)
│   ├── and the caller is the owner
│   │   └── it reverts with BurnDisabled
│   ├── and the caller is an approved operator
│   │   └── it reverts with BurnDisabled
│   ├── it leaves supply, ownership and the transfer counter untouched
│   └── it leaves the bear's account owned and its contents reachable
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

## accountOf / deployAccount / recordAccounts

```
accountOf
└── it returns the canonical ERC-6551 address for the pinned implementation and salt

deployAccount
├── when the bear does not exist
│   └── it reverts with BearDoesNotExist
├── when the account has never been deployed
│   └── it deploys at exactly the address accountOf predicted
└── when the account already exists
    └── it returns the same address without reverting

recordAccounts
├── when the range starts at zero
│   └── it reverts with InvalidTokenRange
├── when the range end precedes its start
│   └── it reverts with InvalidTokenRange
├── when the range runs past maxSupply
│   └── it reverts with InvalidTokenRange
├── when maxSupply has not been set yet
│   └── it still works, because the bound is MAX_BEARS and not the setting
└── when the range is valid
    ├── it marks every id in the range and none outside it
    ├── it emits AccountsRecorded with the range
    ├── it accepts any caller, not only the owner
    ├── it is idempotent across repeat calls
    ├── it closes the pre-mint window for ids that have not minted yet
    └── it does not block ordinary minting or transfers
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

## Construction

```
constructor
├── when the account implementation is the zero address
│   └── it reverts with AccountImplementationIsZeroAddress
├── when the renderer is the zero address
│   └── it reverts with RendererIsZeroAddress
└── otherwise
    └── it stores both addresses exactly as passed
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

- INV-1: no bear is ever owned by any address in `isBearAccount`. Holds once
  `recordAccounts` has covered the full supply; before that, a bear can be sent to the
  account address of an id that has not minted yet. `test_withoutRecording_preMintWindowIsOpen`
  pins the untreated behaviour deliberately. Because the range is bounded by `MAX_BEARS`
  rather than by `maxSupply`, one pass covers the collection for good.
- INV-2: `transferNonce` is monotonically non-decreasing for every bear.
- INV-3: `totalSupply` never exceeds `MAX_BEARS` and never decreases, for any value of the
  owner-settable `maxSupply`.
- Fork-1: minting through the real SeaDrop contract on Robinhood Chain.
