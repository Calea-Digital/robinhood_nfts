# Spec Delta

## MODIFIED Requirements

### Requirement: OPS-1 — Addresses
**Kind:** work-item
The control keys are recorded before mainnet deployment, and the royalty receiver before the
first sale (COL-6). `→ CQ-12`, `→ CQ-15`.

| Role | Holds | Address or holder |
|---|---|---|
| Admin | owner of every contract on every chain | `0x153052B43c8fD4ec01f14D1Edd8660778daa6141`, an EOA (MINT, 28 September 2026; for every contract, still to confirm) |
| Worker | `resolve` and `recordPayout` on `PrizeDraw` | EOA, funded on Arbitrum; operated by Calea (assumed, `→ CQ-23`) |
| Royalty receiver | ERC-2981 receiver — the pot | `0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63` (MINT, 28 September 2026) |
| Prize wallet | every prize, on every prize chain (RAF-33) | `0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3`, an EOA (MINT, 28 September 2026) |
| VRF subscription | the Chainlink subscription `PrizeDraw` draws on | MINT (assumed, `→ CQ-17`) |

#### Scenario: The recorded keys are the deployed ones
- **WHEN** the mainnet deploy scripts run
- **THEN** the admin and worker addresses they read are the ones MINT recorded
- **AND** the royalty receiver is set in Studio before the first sale

### Requirement: OPS-2 — Deployment order
**Kind:** work-item
Every address a contract needs at birth is a constructor argument, so a contract is correct
from its first block and is never deployed-but-unconfigured (MINT, CQ-12).
The calls made after construction are settings
and hand-overs, each in the order listed: `setMaxSupply`, `setTransferValidator`,
`setPaused(true)` and ownership transfers. Each contract is deployed before the page that
depends on it is published.

**Robinhood Chain:**
- `MintABear(name, symbol, [SeaDrop])` → `setMaxSupply(4444)` → `setTransferValidator(V3)`
  (COL-7) → two-step ownership transfer → provenance, `baseURI` and royalties set by Iñigo
  through Studio, before the drop page is published (COL-5, COL-6, COL-10).
- `Activation(bears, mntd, thresholds, weights)`, thresholds in whole $MNTD (ACT-2) →
  `setPaused(true)` until the switch-on date → ownership; requires $MNTD on 4663.
- `MysteryBox(owner, bears)`.

**Arbitrum One:** `PrizeDraw(owner, coordinator, subscriptionId, keyHash, worker, playable)` →
added as the subscription's consumer. No contract is deployed on a prize chain (RAF-33).

#### Scenario: Correct from the first block
- **WHEN** the deploy script runs on a fresh chain
- **THEN** each contract is created with its constructor arguments in the listed order and is never left deployed-but-unconfigured
- **AND** no address is set after construction; every call after construction is a listed setting or ownership transfer, in the listed order

### Requirement: OPS-4 — Rehearsal on testnets (46630, Arbitrum Sepolia, Sepolia)
**Kind:** work-item
The rehearsal covers these paths:
- Studio attaches to and manages a self-deployed, validated `MintABear`.
- Both mint paths: OpenSea and the getminted.io mirror.
- The whitelist: a CSV from MINT's register loaded into Studio, `compare` passing against it, and
  a two-per-wallet allowlist mint.
- A burn through `Activation` against $MNTD on 46630, through to a recorded level.
- Two mystery-box cycles:
  - exclusion;
  - scheduling on 46630 and Arbitrum Sepolia;
  - boxes opened;
  - relays, words and outcomes, including one open that wins and one that does not;
  - a win paid from a prize wallet on 46630 or Sepolia and recorded with `recordPayout`;
  - a bear opened again in the second cycle.
- An OpenSea testnet listing of the validated collection.

On mainnet, before the drop page is published: one team bear listed and sold on OpenSea (COL-7).

#### Scenario: Every path is rehearsed
- **WHEN** the rehearsal runs on 46630, Arbitrum Sepolia and Sepolia
- **THEN** each listed path completes end to end, including one open that wins and one that does not

### Requirement: OPS-5 — Handover
**Kind:** work-item
Calea deploys, configures, transfers ownership, verifies source, and delivers the runbook. After
that it holds no owner key. The one role it may keep is the worker's, if Calea operates the
worker (`→ CQ-23`); `setWorker` lets MINT's admin take that role back at any time. Technical
support runs through 19 November 2026 with agreed response hours (DEL-10).

The runbook is one document, produced via `forge script` tooling. It covers:
- the deploy order (OPS-2);
- the enforcement toggle (OPS-6);
- `Activation`'s pause and unpause around the burn switch-on date (ACT-15);
- loading MINT's whitelist CSV into Studio and checking it (WL-4);
- the mystery-box cycle and worker sequence (RAF-18).

#### Scenario: Nothing stays with Calea
- **WHEN** handover completes
- **THEN** every contract's owner is MINT's admin, every source is verified and the runbook is delivered
- **AND** Calea holds no owner key, and no role other than the worker's where CQ-23 gives it one
