## MODIFIED Requirements

### Requirement: COL-7 — Enforced royalties
**Kind:** work-item
Royalties are enforced from deployment. A marketplace sale settles only through OpenSea or a
Payment Processor venue, and royalties are collected on every such sale; orders from other
venues fail. A holder's own transfers always pass, so a sale arranged outside a marketplace
(directly, or through an escrow) pays no royalty. No setting that lets holders move their own
bears can prevent that. OpenSea does not support Robinhood Chain's testnet, so its handling is
proven on mainnet before the drop page is published: Studio takes over the collection, and one
team bear is listed and sold. If OpenSea cannot fill
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
