## MODIFIED Requirements

### Requirement: RAF-27 — Every bear plays, and the prize pool
**Kind:** work-item
Every one of the 4,444 bears plays, the team's 222 included, and a team bear can win like any
other (MINT, 12 October 2026, CQ-20). No bear is ever left out. A cycle's odds depend on two
numbers: the 4,444 bears and the cycle's number of prizes. Before each cycle MINT publishes
its prize list: each prize's chain, token and id or amount, in order. The n-th prize won in a
cycle is entry n of the list. On Robinhood Chain and Arbitrum One only the count and the list's
fingerprint are on-chain. The prizes themselves are sent from MINT's prize wallet to the prize
vault on each prize chain, and each vault accepts the cycle's list only when it matches the
fingerprint and every prize on its chain is already held (RAF-35, CQ-22).

*Technical note.* `MysteryBox(owner, bears)` has no exclusion: `PLAYABLE` reads `MAX_BEARS`,
4,444, and `PrizeDraw` is deployed with `PLAYABLE` 4,444. The prize list's hash is the cycle's
`manifestHash` (RAF-32); `MysteryBox` and `PrizeDraw` cannot check it against a balance, and
`PrizeVault.registerCycle` does, refusing with `ManifestMismatch` or `Unfunded` (RAF-35).

#### Scenario: Opening freezes the odds
- **GIVEN** a box deployed with no other call
- **WHEN** the owner schedules the first cycle
- **THEN** `PLAYABLE` reads 4,444 on both chains, and the holder of bear 1, a team bear, can open it
