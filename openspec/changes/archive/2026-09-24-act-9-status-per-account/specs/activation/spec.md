# Spec Delta

## MODIFIED Requirements

### Requirement: ACT-9 — Status link
**Kind:** work-item
`linkBear(tokenId)`, owner of the bear only, one nomination per wallet,
recorded with the current counter value; `unlinkBear()` clears it and is safe to call when
nothing is linked; `linkOf(wallet) → (tokenId, level)` returns `(0, 0)` when nothing is linked
or the bear has since moved. A wallet aggregates royalty weight across all its bears (ACT-10)
but carries exactly one Status boost; the boost's value, and how the links of an account's
several wallets combine, are MINT's, off-chain (`→ CQ-21`).

#### Scenario: One nomination per wallet
- **GIVEN** a wallet owning a bear at level 2
- **WHEN** it calls `linkBear(tokenId)`
- **THEN** `linkOf(wallet)` reads `(tokenId, 2)`
- **AND** after the bear moves it reads `(0, 0)`
