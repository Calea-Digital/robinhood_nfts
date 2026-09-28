# Spec Delta

## MODIFIED Requirements

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
