# Spec Delta

## MODIFIED Requirements

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
