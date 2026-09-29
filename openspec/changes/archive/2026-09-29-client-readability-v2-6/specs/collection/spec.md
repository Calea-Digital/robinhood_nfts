# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: COL-7 — Creator token and enforced royalties`
- TO: `### Requirement: COL-7 — Enforced royalties`

## MODIFIED Requirements

### Requirement: COL-1 — Base
**Kind:** work-item
The collection is a standard OpenSea drop contract, so Studio runs the drop, mint pages,
metadata and royalties unchanged. Only OpenSea's official mint contract can mint.

*Technical note.* `MintABear` extends OpenSea's `ERC721SeaDrop` with its mint path,
`getMintStats`, metadata and royalty interfaces unchanged. Canonical SeaDrop
`0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` is the only allowed minter; the drop is configured
and operated through Studio by MINT (COL-11).

#### Scenario: Only SeaDrop mints
- **GIVEN** the collection deployed with canonical SeaDrop as its only allowed minter
- **WHEN** any other address calls the mint path
- **THEN** the call reverts and no bear is minted

### Requirement: COL-2 — Supply
**Kind:** work-item
At most 4,444 bears, fixed in the code. Team, treasury, partner and whitelist bears all come
out of the same 4,444. Studio's supply setting is set to exactly 4,444 and cannot raise the cap.
No bear can be destroyed (COL-8), so the supply is exactly 4,444 once minted out.

*Technical note.* `MAX_BEARS = 4444` is a constant enforced on the mint path; a mint that would
exceed it reverts with `ExceedsMaxBears`. The inherited `maxSupply` is a Studio setting (COL-11)
set to exactly 4,444: `MAX_BEARS` refuses the mint whatever `maxSupply` says, so raising it would
only advertise a supply the token will not deliver, and buyers past the cap would pay for
reverted transactions.

#### Scenario: A mint past the cap reverts
- **GIVEN** 4,444 bears minted
- **WHEN** SeaDrop mints one more, whatever `maxSupply` says
- **THEN** the transaction reverts with `ExceedsMaxBears`

### Requirement: COL-3 — Transfer counter
**Kind:** work-item
Every bear counts its transfers: sales, gifts, moves between the holder's own wallets, and
returns to a previous owner. Minting doesn't count, and the count never resets. A new count is
what resets the bear's level and weight (ACT-5).

*Technical note.* `transferNonce(tokenId)` increments on every transfer except mint and never
resets.

#### Scenario: A transfer advances the counter, a mint does not
- **GIVEN** a bear whose `transferNonce` reads n
- **WHEN** it is transferred to another wallet
- **THEN** `transferNonce` reads n + 1
- **AND** a freshly minted bear reads 0

### Requirement: COL-4 — Reset event
**Kind:** work-item
Every transfer publishes a reset signal in the same transaction, whether or not the bear had a
level, so getminted.io and indexers see the reset at once.

*Technical note.* `TransferNonceAdvanced(uint256 indexed tokenId, uint64 nonce)` is emitted for
every non-mint transfer, in the same transaction as `Transfer`. Anything `Activation` recorded at
the previous counter value is void once it fires.

#### Scenario: The reset event fires on every non-mint transfer
- **WHEN** a bear is transferred, whether or not it has a level
- **THEN** `TransferNonceAdvanced(tokenId, nonce)` is emitted in the same transaction as `Transfer`

### Requirement: COL-5 — Metadata
**Kind:** work-item
Standard OpenSea metadata, set in Studio, with the provenance committed before the mint opens.
Artwork is fixed, and a bear's level never changes its metadata. Placeholder, reveal and hosting
are MINT's.

*Technical note.* `baseURI` is set through Studio and `tokenURI(id) = baseURI + id`; the
provenance hash is committed with `setProvenanceHash` before the mint opens.

#### Scenario: Metadata is base URI plus id
- **GIVEN** `baseURI` set through Studio
- **WHEN** `tokenURI(id)` is read
- **THEN** it returns `baseURI` followed by `id`
- **AND** raising the bear's level changes nothing in it

### Requirement: COL-6 — Royalties
**Kind:** work-item
5% of every sale goes to MINT's royalty pot `0xf7E7…0e63`, which is neither the admin wallet
nor the prize wallet (RAF-33). Iñigo sets it in Studio any time before the first sale, so it
doesn't hold up deployment.

*Technical note.* ERC-2981 through SeaDrop's `setRoyaltyInfo`: 500 basis points to
`0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63` (CQ-15).

#### Scenario: Royalty info reads 5% to the pot
- **GIVEN** royalty info set in Studio to 500 basis points and the pot address
- **WHEN** `royaltyInfo(id, salePrice)` is read
- **THEN** it returns the pot address and 5% of `salePrice`

### Requirement: COL-7 — Enforced royalties
**Kind:** work-item
Royalties are enforced from deployment. A marketplace sale settles only through OpenSea or a
Payment Processor venue, and royalties are collected on every such sale; orders from other
venues fail. A holder's own transfers always pass, so a sale arranged outside a marketplace
(directly, or through an escrow) pays no royalty. No setting that lets holders move their own
bears can prevent that. OpenSea's handling on Robinhood Chain is proven first on testnet with
Studio, then by selling one team bear before the drop page is published. If OpenSea cannot fill
orders, one owner call lifts enforcement and one restores it (OPS-6).

*Technical note.* `MintABear` implements `ICreatorToken` (ERC-721C) and is deployed with
`setTransferValidator(0x721C002B0059009a671D00aD1700c9748146cd1B)`, Limit Break validator V3 on
4663, under the validator's zero-state policy: security level 0 (operator whitelist,
holder-initiated transfers always allowed, no receiver constraint) and list 0 (the Payment
Processor whitelist, with OpenSea's SignedZone `0x000056F7000000EcE9003ca63978907a00FFD100` as
authorizer). A Seaport order from any venue but OpenSea's SignedZone-restricted orders reverts.
Security levels 5 and above also restrict contract receivers and are never used. The lift is
`setTransferValidator(address(0))`; every change emits `TransferValidatorUpdated`.

#### Scenario: Holder transfers pass, foreign Seaport orders revert
- **GIVEN** the validator set to V3 with the zero-state policy
- **WHEN** a holder transfers a bear directly
- **THEN** the transfer passes
- **AND** a Seaport order from a venue other than OpenSea's SignedZone reverts

### Requirement: COL-8 — No burn
**Kind:** work-item
No bear can be destroyed, by anyone, its owner included, so the supply never falls. A bear sent
to an address nobody controls stays in the supply. Nobody can open a mystery box with it
(RAF-28), and it is left out of the royalty split (ACT-10).

*Technical note.* The transfer hook refuses `to == address(0)` with `BurnDisabled`, so
`ERC721SeaDrop.burn` always reverts and `totalSupply` never falls; the royalty snapshot excludes
the canonical dead address `0x…dEaD`.

#### Scenario: No bear can be destroyed
- **WHEN** anyone, the owner included, calls `burn` or transfers a bear to the zero address
- **THEN** it reverts with `BurnDisabled`
- **AND** `totalSupply` is unchanged

### Requirement: COL-9 — No token-bound accounts
**Kind:** work-item
Bears don't come with wallets of their own (ERC-6551). These can be added later without
changing the collection. The one thing that can't be added later is a guard against sending a
bear into a bear's own wallet.

*Technical note.* The canonical registry `0x000000006551c19487814612e58FE06813775758` derives an
account address from `(chainId, tokenContract, tokenId)` for any ERC-721, so accounts need no
change to `MintABear`.

#### Scenario: No token-bound account code
- **WHEN** the deployed `MintABear` is inspected
- **THEN** it holds no ERC-6551 account code, no account guard and no registry call

### Requirement: COL-10 — Ownership
**Kind:** work-item
Calea deploys the collection and hands ownership to MINT's admin in two steps, before the drop
page is published: Calea offers and the admin accepts. Calea keeps no role. Ownership can never
be given up, because an ownerless collection would freeze every Studio setting and the
royalty-enforcement switch.

*Technical note.* The inherited two-step process: `transferOwnership`, then `acceptOwnership`
from the admin. `renounceOwnership` reverts for every caller, the owner included: an ownerless
collection would freeze Studio's drop configuration, `baseURI`, royalties and the
transfer-validator lift and restore (OPS-6), and a pending ownership offer would survive it.

#### Scenario: Two-step transfer to MINT's admin
- **GIVEN** Calea has called `transferOwnership(admin)`
- **WHEN** the admin calls `acceptOwnership`
- **THEN** the admin is the owner
- **AND** Calea holds no role, and `renounceOwnership` reverts for the admin as for anyone else

### Requirement: COL-11 — What Studio owns
**Kind:** informative
Studio sets the mint stages, dates and prices; allowlists and per-wallet limits, including the
whitelist stage loaded from MINT's final list (WL-4); the payout address; the supply setting
(COL-2); metadata and provenance (COL-5); and royalties (COL-6). A "guaranteed" stage is
guaranteed by the order of stages (it must close before the next opens), not by the contract.

*Technical note.* Studio writes these through SeaDrop's owner calls, `multiConfigure` among them.

#### Scenario: Studio settings involve no Calea code
- **WHEN** a stage, allowlist, `maxSupply`, `baseURI`, provenance or royalty setting changes
- **THEN** it changes in OpenSea Studio through the inherited SeaDrop surface, with no Calea contract code involved

### Requirement: COL-12 — Reads
**Kind:** work-item
The page can read for free: who owns a bear, whether it exists, the supply and the cap, its
transfer count, metadata, royalty info, the enforcement setting and a wallet's mint stats, plus
the standard NFT reads.

*Technical note.* `ownerOf`, `exists(tokenId)`, `totalSupply`, `maxSupply`, `MAX_BEARS`,
`transferNonce`, `tokenURI`, `royaltyInfo`, `getTransferValidator`, `getMintStats`, plus the
ERC-721 and SeaDrop standard surface.

#### Scenario: Every read answers
- **WHEN** `ownerOf`, `exists`, `totalSupply`, `maxSupply`, `MAX_BEARS`, `transferNonce`, `tokenURI`, `royaltyInfo`, `getTransferValidator` and `getMintStats` are called for a minted bear
- **THEN** each returns without reverting
- **AND** `exists(id)` is false for an unminted id

### Requirement: COL-13 — Events
**Kind:** work-item
The collection publishes the standard transfer and approval events, Studio's configuration
events, the reset signal (COL-4) and every change to royalty enforcement (COL-7).

*Technical note.* `Transfer`, `Approval`, `ApprovalForAll`; SeaDrop configuration events;
`TransferNonceAdvanced` (COL-4); `TransferValidatorUpdated` (COL-7).

#### Scenario: Events carry the documented arguments
- **WHEN** a bear is transferred and the validator is changed
- **THEN** `Transfer`, `TransferNonceAdvanced` and `TransferValidatorUpdated` are emitted with the documented arguments
