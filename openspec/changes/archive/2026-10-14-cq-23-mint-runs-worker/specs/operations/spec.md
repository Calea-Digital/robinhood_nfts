## MODIFIED Requirements

### Requirement: OPS-1 — Addresses
**Kind:** work-item
The keys and wallets the system uses are recorded before mainnet deployment; the royalty receiver
is recorded before the first sale (COL-6).

| Role | What it does | Who holds it |
|---|---|---|
| Admin | owns every contract on every chain | MINT, `0x1530…6141` |
| Worker | carries openings to the draw and records payouts | MINT, a key MINT creates (CQ-23) |
| Royalty receiver | receives the 5% royalties (the pot) | MINT, `0xf7E7…0e63` |
| Prize wallet | holds and pays every prize | MINT, `0xf6c0…83e3` |
| Randomness subscription | pays for the draw's random numbers | Calea, invoicing MINT (CQ-17) |

*Technical note.* Admin `0x153052B43c8fD4ec01f14D1Edd8660778daa6141`, an EOA (MINT, 28 September
2026), owner of every contract on every chain (MINT, 12 October 2026, CQ-12). A later move to a
multisig goes through each contract's two-step handover (COL-10, ACT-12, RAF-14). Worker: an EOA MINT creates and funds with ETH on
Arbitrum One, holding `resolve` and `recordPayout` on `PrizeDraw` (CQ-23, RAF-18). Royalty receiver
`0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63`, the ERC-2981 receiver `→ CQ-15`. Prize wallet
`0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3`, an EOA (RAF-33). VRF subscription: the Chainlink
subscription `PrizeDraw` draws on, owned by a Calea wallet on Arbitrum One (CQ-17).

#### Scenario: The recorded keys are the deployed ones
- **WHEN** the mainnet deploy scripts run
- **THEN** the admin and worker addresses they read are the ones MINT recorded
- **AND** the royalty receiver is set in Studio before the first sale

### Requirement: OPS-5 — Handover
**Kind:** work-item
Calea deploys, configures, hands over ownership, verifies the source and delivers the runbook,
then holds no owner key. It keeps the randomness subscription, which it funds and invoices to
MINT (CQ-17) and can hand to MINT at any time. It keeps no contract role: MINT runs the worker
(CQ-23). Technical support runs until 19 November 2026 with
agreed response hours (DEL-10). The runbook covers:
- the deployment order (OPS-2);
- switching royalty enforcement off and on (OPS-6);
- pausing and opening burns around 29 October (ACT-15);
- loading the whitelist into Studio and checking it (WL-4);
- running a mystery-box cycle (RAF-18), and setting up, funding and running the worker;
- moving each contract's ownership to a new owner, such as a multisig (COL-10, ACT-12, RAF-14).

*Technical note.* The runbook is one document, backed by `forge script` tooling. MINT's admin
authorises the worker with `setWorker` (CQ-23). The ownership steps cover all four contracts: `MintABear`'s
`transferOwnership` then `acceptOwnership`, and the Solady handover on `Activation`, `MysteryBox`
and `PrizeDraw` (`requestOwnershipHandover` from the new owner, `completeOwnershipHandover` from
the owner within 48 hours), each with its read-back of `owner()`, and the same steps as a Safe
proposes them.

#### Scenario: Nothing stays with Calea
- **WHEN** handover completes
- **THEN** every contract's owner is MINT's admin, every source is verified and the runbook is delivered
- **AND** Calea holds no owner key and no contract role; it holds the randomness subscription (CQ-17)
