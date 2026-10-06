# Design notes

This page records why the contracts are built the way they are. The source NatSpec says what each
element does; the specification (`openspec/`, rendered in `docs/SPECIFICATION.md`) says what is
required.

## MintABear

**ERC-721C through SeaDrop.** `ERC721SeaDrop` implements `ICreatorToken`. The deploy script sets
the transfer validator to Limit Break's V3 with its zero-state policy, so a holder's own transfers
always pass and a sale a marketplace operates settles only through OpenSea or a Payment Processor
venue. A sale arranged outside a marketplace pays no creator earnings. One owner call lifts or
restores enforcement (`docs/RUNBOOK.md`, "Transfer enforcement"). The SeaDrop mint path,
`getMintStats`, metadata and royalty interfaces are left as SeaDrop ships them, following OpenSea's
integration guidance: `tokenURI(id)` is `baseURI` followed by `id`, and `baseURI`, provenance and
royalties are set through OpenSea Studio.

**The transfer counter.** `Activation` stores a level alongside the `transferNonce` value it was
recorded at, and treats it as void once the counter moves. The reset is a consequence of the
transfer rather than an action that must succeed, so it can neither be skipped nor block the
transfer. The token never calls `Activation`; a callback from the token would fail open.

**No burn.** `ERC721SeaDrop.burn` is `external` and not `virtual`, so it cannot be overridden.
Every burn passes through `_beforeTokenTransfers` with `to == address(0)`, which no transfer
reaches, so the hook refuses it with `BurnDisabled`. ERC721A's `transferFrom` checks the zero
address before the hook runs and would answer `TransferToZeroAddress`; `MintABear` overrides
`transferFrom` so every way of destroying a bear gives the same error.

**`MAX_BEARS`.** The inherited `maxSupply` starts at zero and the owner, or Studio through
`multiConfigure`, can raise it at any time. `MAX_BEARS` is a constant checked on the mint path, so
the 4,444 ceiling is a property of the code rather than of the configuration.

**Ownership is never renounced.** Studio's configuration, `baseURI`, royalties and the validator
lift and restore are owner settings. The inherited `TwoStepOwnable.renounceOwnership` would freeze
them for good and, because it does not clear `potentialOwner`, would leave a pending offer through
which a renounced collection could be claimed again.

**No token-bound accounts.** ERC-6551 can be added later without any change to `MintABear`: the
canonical registry derives an account address from `(chainId, tokenContract, tokenId)` for any
ERC-721.

## Activation

**One token, one collection.** $MNTD is fixed in the constructor, and the only thing done with it
is burning the caller's own balance. A different token address means a new `Activation`. $MNTD is
outside this codebase, so its `burnFrom` is untrusted: it must revert on failure.

**Record, then burn.** The record is written and `BearActivated` emitted before `burnFrom`. A
token that calls back during `burnFrom` meets `nonReentrant`, and any revert undoes both steps.

**Levels from a running total.** Reaching level 5 in one burn or in twenty is the same thing.
Thresholds are given in whole tokens and scaled by the token's `decimals` at construction.

**Ownership is never renounced**, so the pause can always be set and lifted.

**Slither `locked-ether`.** Solady's ownership functions are `payable` (a gas saving). Anyone can
call `requestOwnershipHandover` and `cancelOwnershipHandover`, so anyone could lock their own ETH
by attaching value to them. Nothing withdraws it and nothing else accepts ETH. The finding is
accepted; the same applies to `WhitelistClaim` and `WhitelistImport`.
