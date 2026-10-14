## MODIFIED Requirements

### Requirement: OPS-1 — Addresses
**Kind:** work-item
The keys and wallets the system uses are recorded before mainnet deployment; the royalty receiver
is recorded before the first sale (COL-6).

| Role | What it does | Who holds it |
|---|---|---|
| Admin | owns every contract on every chain | MINT, `0x1530…6141` (to confirm for every contract, O1) |
| Worker | carries openings to the draw and records payouts | Calea, assumed (O5) |
| Royalty receiver | receives the 5% royalties (the pot) | MINT, `0xf7E7…0e63` |
| Prize wallet | holds and pays every prize | MINT, `0xf6c0…83e3` |
| Randomness subscription | pays for the draw's random numbers | MINT, assumed (O4) |

*Technical note.* Admin `0x153052B43c8fD4ec01f14D1Edd8660778daa6141`, an EOA (MINT, 28 September
2026), owner of every contract on every chain `→ CQ-12`. Worker: an EOA funded on Arbitrum,
holding `resolve` and `recordPayout` on `PrizeDraw` `→ CQ-23`. Royalty receiver
`0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63`, the ERC-2981 receiver `→ CQ-15`. Prize wallet
`0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3`, an EOA (RAF-33). VRF subscription: the Chainlink
subscription `PrizeDraw` draws on `→ CQ-17`.

#### Scenario: The recorded keys are the deployed ones
- **WHEN** the mainnet deploy scripts run
- **THEN** the admin and worker addresses they read are the ones MINT recorded
- **AND** the royalty receiver is set in Studio before the first sale
