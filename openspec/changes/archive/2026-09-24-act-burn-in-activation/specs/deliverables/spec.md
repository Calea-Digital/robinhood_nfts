# Spec Delta

## MODIFIED Requirements

### Requirement: DEL-8 — Audit tranches
**Kind:** informative
Tranche 1: `MintABear`, `WhitelistClaim` and `Activation`. Tranche 2:
`MysteryBox`, `PrizeVault` and `PrizeDraw`, once CQ-9's remaining questions and CQ-20 are
answered. Iñigo accepts after Calea and MINT sign off; anything not accepted stays disabled in the
UI.

#### Scenario: Tranche membership is fixed
- **WHEN** a contract's audit tranche is looked up
- **THEN** it is tranche 1 for `MintABear`, `WhitelistClaim` and `Activation`, and tranche 2 for `MysteryBox`, `PrizeVault` and `PrizeDraw`
