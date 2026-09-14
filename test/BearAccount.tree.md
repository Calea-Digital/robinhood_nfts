# BearAccount — branching tree

Scope note: invariants (INV-N) and fork tests are recorded here as obligations for the
auditor. They are deliberately not implemented as developer unit leaves.

`BearAccount` overrides exactly one function of Solady's `ERC6551` — the ERC-1271 domain.
Everything below is inherited behaviour, tested because the product requirement ("its own
onchain wallet to hold/move MNTD, ETH, NFTs") is discharged entirely by that inherited code
against this particular deployment: the canonical registry's proxy, pointing straight at the
implementation, on chain 4663.

## Ownership

```
owner / token / isValidSigner
├── it returns the current holder of the bear
├── when the bear is transferred
│   └── control moves with it, with no action by either party
├── token() names this chain, this collection and this bear
└── isValidSigner
    ├── the current owner is valid
    ├── a non-owner is not
    └── after a sale the seller stops being valid and the buyer starts
```

## Asset custody

```
custody
├── ETH
│   └── it holds a balance and the owner can move it out
├── $MNTD
│   └── it holds a balance and the owner can move it out via execute
├── outside NFTs
│   ├── it holds them and the owner can move them out
│   └── it accepts them via safeTransferFrom, so wallets can deposit normally
└── when the bear changes hands
    ├── the contents stay put
    ├── the seller can no longer move them
    └── the buyer can
```

## Execution

```
execute
├── when the caller does not hold the bear
│   └── it reverts with Unauthorized
├── when the caller is an operator approved to transfer the bear
│   └── it reverts with Unauthorized — moving the bear is not spending its assets
├── when the operation is DELEGATECALL (1)
│   └── it reverts with OperationNotSupported
├── when the operation is CREATE (2) or CREATE2 (3)
│   └── it reverts with OperationNotSupported
├── when the inner call fails
│   └── the revert is bubbled up, not swallowed
└── when the operation is CALL (0) and the caller is the owner
    ├── it performs the call
    └── it advances state()

executeBatch
└── it performs several calls in one transaction
```

## Immutability

```
upgradeToAndCall
└── it reverts with UnauthorizedCallContext, because the registry proxy hardcodes the
    implementation rather than holding it in a UUPS storage slot

the implementation contract itself
└── owner() reads address(0), so it cannot be driven directly
```

## ERC-1271 / ERC-165

```
eip712Domain
├── it carries name "MintABear" and version "1"
├── it is bound to this account's address and this chain
└── it differs between two bears, so a signature cannot cross from one to another

supportsInterface
├── ERC-165, ERC-6551 and ERC-6551 Executable read true
└── IERC721Receiver and IERC1155Receiver read false, although receipt works

fallback
└── an unrecognised selector reverts, after burning a large share of forwarded gas
```

## Auditor obligations (not implemented here)

- INV-8: `owner()` always equals `MintABear.ownerOf(tokenId)` for the bound bear, or
  `address(0)` when that call fails.
- INV-9: no caller other than the current owner can move value out of an account.
- INV-10: the account implementation is never upgraded, for any bear, ever.
- **Delegated, not tested here:** the full ERC-7739 / ERC-1271 nested signature scheme, and
  `_hasOwnershipCycle` at depth. Both are Solady's, exercised by Solady's own suite. The
  auditor should review the pin (`lib/solady` at `acd959a`, v0.1.26) rather than assume our
  tests cover them.
- Fork-1: a real registry deployment on chain 4663, confirming the registry bytecode etched
  in `BaseTest` matches the deployed one.
