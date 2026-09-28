# Spec Delta

## MODIFIED Requirements

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
