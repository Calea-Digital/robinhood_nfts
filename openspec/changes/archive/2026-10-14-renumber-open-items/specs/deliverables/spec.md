## MODIFIED Requirements

### Requirement: DEL-8 — Audit tranches
**Kind:** informative
Tranche 1 is the collection and Activation. Tranche 2 is the mystery box and the draw, once the
team-bear ids arrive (O1). The whitelist has no contract, so none of it is audited (WL-8). Iñigo
accepts each tranche after Calea and MINT sign off, and anything not accepted stays switched off
in the page.

*Technical note.* Tranche 1: `MintABear` and `Activation`. Tranche 2: `MysteryBox` and
`PrizeDraw`, once CQ-20's remaining values are supplied. `WhitelistClaim` and `WhitelistImport`
are built but not deployed.

#### Scenario: Tranche membership is fixed
- **WHEN** a contract's audit tranche is looked up
- **THEN** it is tranche 1 for `MintABear` and `Activation`, tranche 2 for `MysteryBox` and `PrizeDraw`

### Requirement: DEL-10 — Commercial items for Rayco's agreement
**Kind:** commercial
Listed so nothing is implied:
- prize logic, the cycles and the win rule;
- weight interfaces;
- Studio and frontend assistance;
- mainnet execution and handover on every chain;
- technical support through 19 November with agreed response hours;
- beyond the statement of work's single-chain design:
  - **whitelist support**: the check, the mint proofs and a review of the claim rules (WL-4,
    WL-8);
  - the **cross-chain draw**: the draw on Arbitrum, relaying each opening, and the payout
    record;
  - the admin-page calls in the client library.

Two items are priced only if MINT confirms them:
- **running the worker** after 19 November, if Calea runs it (O4, `→ CQ-23`);
- **holding and invoicing the randomness subscription**, if MINT doesn't (O3, `→ CQ-17`).

#### Scenario: Every item is in the agreement
- **WHEN** Rayco's agreement is drawn up
- **THEN** each listed item appears in it
