# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: OPS-4 — Rehearsal on testnets (46630, Sepolia, Curtis, Base Sepolia)`
- TO: `### Requirement: OPS-4 — Rehearsal on testnets (46630, Arbitrum Sepolia, Sepolia)`

## MODIFIED Requirements

### Requirement: OPS-1 — Addresses
**Kind:** work-item
The control keys are recorded before mainnet deployment, and the royalty receiver before the
first sale (COL-6). `→ CQ-12`, `→ CQ-15`.

| Role | Holds | Address or holder |
|---|---|---|
| Admin | owner of every contract on every chain | `0x153052B43c8fD4ec01f14D1Edd8660778daa6141`, an EOA (MINT, 28 September 2026; for every contract, still to confirm) |
| Worker | `resolve` and `recordPayout` on `PrizeDraw` | EOA, funded on Arbitrum; operated by Calea (assumed, `→ CQ-23`) |
| Eligibility signer | `WhitelistClaim.signer`, only if WL-3 is deployed | Backend key held by MINT; rotatable by the admin |
| Royalty receiver | ERC-2981 receiver — the pot | `0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63` (MINT, 28 September 2026) |
| Prize wallet | every prize, on every prize chain (RAF-33) | `0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3`, an EOA (MINT, 28 September 2026) |
| VRF subscription | the Chainlink subscription `PrizeDraw` draws on | MINT (assumed, `→ CQ-17`) |

#### Scenario: The recorded keys are the deployed ones
- **WHEN** the mainnet deploy scripts run
- **THEN** the admin, worker and signer addresses they read are the ones MINT recorded
- **AND** the royalty receiver is set in Studio before the first sale

### Requirement: OPS-2 — Deployment order
**Kind:** work-item
Every address a contract needs at birth is a constructor argument, so a contract is correct
from its first block and is never deployed-but-unconfigured (MINT, CQ-12).
`WhitelistClaim.setSigner` exists so the admin can rotate the signer; the first signer is a
constructor argument, and it stays owner-only. The calls made after construction are settings
and hand-overs, each in the order listed: `setMaxSupply`, `setTransferValidator`,
`setPaused(true)` and ownership transfers. Each contract is deployed before the page that
depends on it is published.

**Robinhood Chain:**
- `MintABear(name, symbol, [SeaDrop])` → `setMaxSupply(4444)` → `setTransferValidator(V3)`
  (COL-7) → two-step ownership transfer → provenance, `baseURI` and royalties set by Iñigo
  through Studio, before the drop page is published (COL-5, COL-6, COL-10).
- Before the campaign opens, one of the two whitelist registries, with MINT's admin as `owner`
  (`→ CQ-18`): `WhitelistClaim(owner, signer, openAt, closeAt)` or
  `WhitelistImport(owner, closeAt)`.
- `Activation(bears, mntd, thresholds, weights)`, thresholds in whole $MNTD (ACT-2) →
  `setPaused(true)` until the switch-on date → ownership; requires $MNTD on 4663.
- `MysteryBox(owner, bears)`.

**Arbitrum One:** `PrizeDraw(owner, coordinator, subscriptionId, keyHash, worker, playable)` →
added as the subscription's consumer. No contract is deployed on a prize chain (RAF-33).

#### Scenario: Correct from the first block
- **WHEN** the deploy script runs on a fresh chain
- **THEN** each contract is created with its constructor arguments in the listed order and is never left deployed-but-unconfigured
- **AND** no address is set after construction; every call after construction is a listed setting or ownership transfer, in the listed order

### Requirement: OPS-3 — Verification
**Kind:** work-item
Sourcify for 4663 and 46630, because mainnet Blockscout's API sits behind a bot challenge.
Arbiscan (Etherscan's API) for Arbitrum One and Arbitrum Sepolia.

#### Scenario: Source is verified where the chain allows
- **WHEN** a contract is deployed on 4663 or 46630
- **THEN** its source is verified through Sourcify and readable there

### Requirement: OPS-4 — Rehearsal on testnets (46630, Arbitrum Sepolia, Sepolia)
**Kind:** work-item
The rehearsal covers these paths:
- Studio attaches to and manages a self-deployed, validated `MintABear`.
- Both mint paths: OpenSea and the getminted.io mirror.
- The whitelist, for the registry MINT picks (CQ-18): from a voucher, or from the CSV import, to
  the exported allowlist and a two-per-wallet allowlist mint.
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
- `Activation`'s pause and unpause around the burn switch-on date (ACT-11);
- the whitelist export or import (WL-4, WL-7);
- the mystery-box cycle and worker sequence (RAF-18).

#### Scenario: Nothing stays with Calea
- **WHEN** handover completes
- **THEN** every contract's owner is MINT's admin, every source is verified and the runbook is delivered
- **AND** Calea holds no owner key, and no role other than the worker's where CQ-23 gives it one

### Requirement: OPS-7 — Chain constraints
**Kind:** informative
On Robinhood Chain `block.number` is the L1 height, so contracts and scripts key on timestamps.
Sequencer-level compliance screening can block an individual holder's transactions, so nothing
in the system requires a holder to act by a deadline for the system to stay correct: a box left
unopened in a cycle is a shot not taken, and nothing else depends on it. Robinhood Chain applies
an Arbitrum-style per-transaction gas limit, which is why no call in this system loops over the
collection. Randomness is not available on Robinhood Chain or ApeChain, which is why the draw
runs on Arbitrum One.

#### Scenario: The design honours the chain
- **WHEN** the contracts are reviewed against the chain's constraints
- **THEN** no logic keys on `block.number`, no call loops over the collection, and no correctness depends on a holder acting by a deadline
