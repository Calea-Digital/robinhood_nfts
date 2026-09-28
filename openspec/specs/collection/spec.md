# Collection contract — MintABear Specification

## Purpose
MINT needs a 4,444-bear collection on Robinhood Chain that its team runs from OpenSea Studio, that collects royalties on every sale, and whose every transfer visibly resets a bear's activation — so that everything else in the system can trust ownership and the transfer counter alone.

## Requirements

### Requirement: COL-1 — Base
**Kind:** work-item
`MintABear` extends OpenSea's `ERC721SeaDrop` with its mint path,
`getMintStats`, metadata and royalty interfaces unchanged. Canonical SeaDrop
`0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` is the only allowed minter. The drop is configured
and operated through OpenSea Studio by MINT (COL-11).

#### Scenario: Only SeaDrop mints
- **GIVEN** the collection deployed with canonical SeaDrop as its only allowed minter
- **WHEN** any other address calls the mint path
- **THEN** the call reverts and no bear is minted

### Requirement: COL-2 — Supply
**Kind:** work-item
`MAX_BEARS = 4444` is a constant enforced on the mint path; a mint that would
exceed it reverts with `ExceedsMaxBears`. The inherited `maxSupply` is a Studio setting (COL-11)
and is set to exactly 4,444: `MAX_BEARS` refuses the mint whatever `maxSupply` says, so raising it
cannot increase the supply delivered — it would only advertise a supply the token will not deliver,
and buyers past the cap would pay for reverted transactions. Team, treasury, partner and whitelist
bears all come out of the same 4,444. Because no bear can be destroyed (COL-8), the supply is
exactly 4,444 once minted out.

#### Scenario: A mint past the cap reverts
- **GIVEN** 4,444 bears minted
- **WHEN** SeaDrop mints one more, whatever `maxSupply` says
- **THEN** the transaction reverts with `ExceedsMaxBears`

### Requirement: COL-3 — Transfer counter
**Kind:** work-item
`transferNonce(tokenId)` increments on every transfer except mint — sales, gifts,
self-initiated moves and return transfers to a previous owner alike — and never resets. It is
the mechanism by which every ownership change resets level and weight (ACT-5).

#### Scenario: A transfer advances the counter, a mint does not
- **GIVEN** a bear whose `transferNonce` reads n
- **WHEN** it is transferred to another wallet
- **THEN** `transferNonce` reads n + 1
- **AND** a freshly minted bear reads 0

### Requirement: COL-4 — Reset event
**Kind:** work-item
`TransferNonceAdvanced(uint256 indexed tokenId, uint64 nonce)` is
emitted for every non-mint transfer, in the same transaction as `Transfer`. It is the
activation-reset event: anything `Activation` recorded at the previous counter value is void
once it fires. It fires whether or not a level existed.

#### Scenario: The reset event fires on every non-mint transfer
- **WHEN** a bear is transferred, whether or not it has a level
- **THEN** `TransferNonceAdvanced(tokenId, nonce)` is emitted in the same transaction as `Transfer`

### Requirement: COL-5 — Metadata
**Kind:** work-item
Standard SeaDrop metadata: `baseURI` set through Studio,
`tokenURI(id) = baseURI + id`, provenance hash committed with `setProvenanceHash` before the
mint opens. Placeholder JSON, reveal and hosting are MINT's. Artwork is immutable and metadata
does not vary with level.

#### Scenario: Metadata is base URI plus id
- **GIVEN** `baseURI` set through Studio
- **WHEN** `tokenURI(id)` is read
- **THEN** it returns `baseURI` followed by `id`
- **AND** raising the bear's level changes nothing in it

### Requirement: COL-6 — Royalties
**Kind:** work-item
ERC-2981 through SeaDrop's `setRoyaltyInfo`: **5% (500 basis points)**,
receiver the royalty-pot address MINT names, distinct from the admin and from the prize wallet (RAF-33). Set
by Iñigo in Studio at any point before the first sale; it does not hold up deployment. `→ CQ-15`
(receiver).

#### Scenario: Royalty info reads 5% to the pot
- **GIVEN** royalty info set in Studio to 500 basis points and the pot address
- **WHEN** `royaltyInfo(id, salePrice)` is read
- **THEN** it returns the pot address and 5% of `salePrice`

### Requirement: COL-7 — Creator token and enforced royalties
**Kind:** work-item
`MintABear` implements `ICreatorToken` (ERC-721C)
and is deployed with the transfer validator **set**:
`setTransferValidator(0x721C002B0059009a671D00aD1700c9748146cd1B)`, Limit Break validator V3 on
4663, with the validator's zero-state policy — security level 0 (operator whitelist,
holder-initiated transfers always allowed, no receiver constraint) and list 0 (Limit Break
Payment Processor whitelist with OpenSea's SignedZone `0x000056F7000000EcE9003ca63978907a00FFD100`
as authorizer). Consequence: a transfer the holder makes itself always passes; a sale a marketplace
operates settles only through OpenSea (SignedZone-restricted orders) or a Payment Processor
marketplace, and creator earnings are collected on every such sale; a Seaport order from any
other venue reverts. Because the holder's own transfers pass, a sale arranged outside a
marketplace — directly, or through an escrow contract the holder sends the bear to — pays no
creator earnings; every level that lets holders move their own bears allows it.
Security levels 5 and above additionally restrict contract receivers and are not used. OpenSea's
handling of a validated collection on this chain has not been observed, so the switch is proven
in two steps: on testnet 46630 with Studio (OPS-4), and on mainnet with a listing and sale of a
team bear before the drop page is published. If OpenSea cannot fill orders, one owner call,
`setTransferValidator(address(0))`, lifts enforcement until OpenSea confirms, and one call
restores it (OPS-6). Every change emits `TransferValidatorUpdated`.

#### Scenario: Holder transfers pass, foreign Seaport orders revert
- **GIVEN** the validator set to V3 with the zero-state policy
- **WHEN** a holder transfers a bear directly
- **THEN** the transfer passes
- **AND** a Seaport order from a venue other than OpenSea's SignedZone reverts

### Requirement: COL-8 — No burn
**Kind:** work-item
The transfer hook refuses `to == address(0)` with `BurnDisabled`, so
`ERC721SeaDrop.burn` always reverts and no bear can be destroyed by anyone, its owner included;
`totalSupply` never falls. A bear sent to an address nobody controls (for example `0x…dEaD`)
remains a bear in the supply: nobody can open a mystery box with it (RAF-28), and the royalty
snapshot excludes the canonical dead address (ACT-10).

#### Scenario: No bear can be destroyed
- **WHEN** anyone, the owner included, calls `burn` or transfers a bear to the zero address
- **THEN** it reverts with `BurnDisabled`
- **AND** `totalSupply` is unchanged

### Requirement: COL-9 — No token-bound accounts
**Kind:** work-item
ERC-6551 is not part of the collection. It can be added later
without any change to `MintABear`: the canonical registry
`0x000000006551c19487814612e58FE06813775758` derives an account address from
`(chainId, tokenContract, tokenId)` for any ERC-721. The one property that cannot be retrofitted
is a token-side guard against sending a bear into a bear's account.

#### Scenario: No token-bound account code
- **WHEN** the deployed `MintABear` is inspected
- **THEN** it holds no ERC-6551 account code, no account guard and no registry call

### Requirement: COL-10 — Ownership
**Kind:** work-item
Deployed by Calea; ownership transferred to MINT's admin address by the
inherited two-step process (`transferOwnership`, then `acceptOwnership` from the admin) before
the drop page is published. Calea retains no role. The collection always has an owner:
`renounceOwnership` reverts for every caller, the owner included, because an ownerless collection
would freeze every owner setting — Studio's drop configuration, `baseURI`, royalties and the
transfer-validator lift and restore (OPS-6) — and a pending ownership offer would survive it.

#### Scenario: Two-step transfer to MINT's admin
- **GIVEN** Calea has called `transferOwnership(admin)`
- **WHEN** the admin calls `acceptOwnership`
- **THEN** the admin is the owner
- **AND** Calea holds no role, and `renounceOwnership` reverts for the admin as for anyone else

### Requirement: COL-11 — What Studio owns
**Kind:** informative
Mint stages, dates and pricing; allowlists and per-wallet limits,
including the whitelist stage loaded from `WhitelistClaim` (WL-4); payout address; `maxSupply`
(COL-2); `baseURI` and provenance (COL-5); royalty info (COL-6); `multiConfigure`. A
"guaranteed" stage is guaranteed by stage sequencing — the guaranteed window must close before
the next window opens — not by the contract.

#### Scenario: Studio settings involve no Calea code
- **WHEN** a stage, allowlist, `maxSupply`, `baseURI`, provenance or royalty setting changes
- **THEN** it changes in OpenSea Studio through the inherited SeaDrop surface, with no Calea contract code involved

### Requirement: COL-12 — Reads
**Kind:** work-item
`ownerOf`, `exists(tokenId)`, `totalSupply`, `maxSupply`, `MAX_BEARS`,
`transferNonce`, `tokenURI`, `royaltyInfo`, `getTransferValidator`, `getMintStats`, plus the
ERC-721 and SeaDrop standard surface.

#### Scenario: Every read answers
- **WHEN** `ownerOf`, `exists`, `totalSupply`, `maxSupply`, `MAX_BEARS`, `transferNonce`, `tokenURI`, `royaltyInfo`, `getTransferValidator` and `getMintStats` are called for a minted bear
- **THEN** each returns without reverting
- **AND** `exists(id)` is false for an unminted id

### Requirement: COL-13 — Events
**Kind:** work-item
Standard `Transfer`, `Approval`, `ApprovalForAll`; SeaDrop configuration
events; `TransferNonceAdvanced` (COL-4); `TransferValidatorUpdated` (COL-7).

#### Scenario: Events carry the documented arguments
- **WHEN** a bear is transferred and the validator is changed
- **THEN** `Transfer`, `TransferNonceAdvanced` and `TransferValidatorUpdated` are emitted with the documented arguments
