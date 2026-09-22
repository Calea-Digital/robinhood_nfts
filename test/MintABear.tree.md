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
├── when to is the zero address (burn)
│   ├── and the caller is the owner
│   │   └── it reverts with BurnDisabled
│   ├── and the caller is an approved operator
│   │   └── it reverts with BurnDisabled
│   └── it leaves supply, ownership and the transfer counter untouched
├── when from is the zero address (mint)
│   └── it does not advance the transfer counter
└── when from is not the zero address (transfer)
    ├── it advances that bear's transfer counter by exactly one
    └── it accepts any non-zero destination; there is no account guard (COL-9)
```

## Token-bound accounts (COL-9)

```
no token-bound accounts
├── the entry points accountOf, deployAccount, recordAccounts, isBearAccount,
│   ACCOUNT_IMPLEMENTATION and ACCOUNT_SALT are not in the ABI
├── the canonical registry address appears nowhere in the deployed bytecode
└── an address the registry would derive for a bear is an ordinary destination
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
├── when the renderer is the zero address
│   └── it reverts with RendererIsZeroAddress
└── otherwise
    └── it stores the renderer exactly as passed
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
