# Operations, roles and handover Specification

## Purpose
MINT receives contracts that are correct from their first block, verified on every chain, and handed over with every key, role and a runbook. Running them after 19 November needs nothing from Calea.

## Requirements

### Requirement: OPS-1 — Addresses
**Kind:** work-item
The keys and wallets the system uses are recorded before mainnet deployment; the royalty receiver
is recorded before the first sale (COL-6).

| Role | What it does | Who holds it |
|---|---|---|
| Admin | owns every contract on every chain | MINT, `0x1530…6141` (to confirm for every contract, O1) |
| Worker | carries openings to the draw and records payouts | Calea, assumed (O5) |
| Royalty receiver | receives the 5% royalties (the pot) | MINT, `0xf7E7…0e63` |
| Prize wallet | holds and pays every prize | MINT, `0xf6c0…e3e3` |
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

### Requirement: OPS-2 — Deployment order
**Kind:** work-item
Every address a contract needs is given when it is deployed, so each contract is correct from its
first block and never live but unconfigured (MINT, CQ-12). Only settings and handovers follow,
and each contract is deployed before the page that depends on it goes live.
- **Robinhood Chain:** the collection comes first. Its supply is set to 4,444, royalty
  enforcement is switched on and ownership goes to MINT, then Iñigo sets provenance, metadata and
  royalties in Studio before the drop page goes live (COL-5, COL-6, COL-10). Next comes
  Activation, deployed paused until 29 October once $MNTD is on the chain. Then the mystery box.
- **Arbitrum One:** the draw, added to the randomness subscription.

Nothing is deployed on a prize chain (RAF-33).

*Technical note.* The calls after construction are, in order, `setMaxSupply`,
`setTransferValidator` and ownership transfers. Robinhood Chain:
`MintABear(name, symbol, [SeaDrop])` → `setMaxSupply(4444)` → `setTransferValidator(V3)` (COL-7) →
two-step ownership transfer; `Activation(owner, bears, mntd, thresholds, weights)`, thresholds in whole
$MNTD (ACT-2), owned by MINT's admin and paused from construction (ACT-12, ACT-15), with no call
after it; `MysteryBox(owner, bears)`. Arbitrum One:
`PrizeDraw(owner, coordinator, subscriptionId, keyHash, worker, playable)` → added as the
subscription's consumer.

#### Scenario: Correct from the first block
- **WHEN** the deploy script runs on a fresh chain
- **THEN** each contract is created with its constructor arguments in the listed order and is never left deployed-but-unconfigured
- **AND** no address is set after construction; every call after construction is a listed setting or ownership transfer, in the listed order

### Requirement: OPS-3 — Verification
**Kind:** work-item
Every contract's source is published and verified: on Sourcify for Robinhood Chain and its
testnet, and on Arbiscan for Arbitrum One and Arbitrum Sepolia.

*Technical note.* Sourcify for 4663 and 46630, because mainnet Blockscout's API sits behind a bot
challenge; Arbiscan through Etherscan's API for 42161 and 421614.

#### Scenario: Source is verified where the chain allows
- **WHEN** a contract is deployed on 4663 or 46630
- **THEN** its source is verified through Sourcify and readable there

### Requirement: OPS-4 — Rehearsal on testnets (46630, Arbitrum Sepolia, Sepolia)
**Kind:** work-item
Before mainnet, everything is rehearsed on the testnets:
- Studio managing a collection Calea deployed, with royalty enforcement on;
- minting through OpenSea and through getminted.io;
- the whitelist end to end: a list from MINT's register loaded into Studio, Calea's check
  passing, and wallets minting their spots and no more;
- a burn raising a bear's level, against a test $MNTD;
- two mystery-box cycles: team bears excluded, both chains scheduled, one win and one loss, a win
  paid and recorded, and a bear opened again in the second cycle;
- an OpenSea testnet listing.

On mainnet, before the drop page goes live, one team bear is listed and sold on OpenSea (COL-7).

*Technical note.* Testnets 46630, Arbitrum Sepolia (421614) and Sepolia. The whitelist case:
`compare` passes over the CSV against Studio's root, a two-spot wallet mints two, and a one-spot
wallet is refused its second. The burn goes through `Activation` against $MNTD on 46630 to a
recorded level. The cycles cover relays in order, words and outcomes, and a payout from a prize
wallet on 46630 or Sepolia recorded with `recordPayout`.

#### Scenario: Every path is rehearsed
- **WHEN** the rehearsal runs on 46630, Arbitrum Sepolia and Sepolia
- **THEN** each listed path completes end to end, including one open that wins and one that does not

### Requirement: OPS-5 — Handover
**Kind:** work-item
Calea deploys, configures, hands over ownership, verifies the source and delivers the runbook,
then holds no owner key. The one role it may keep is the worker's, if Calea runs it (O5), and
MINT's admin can take that back at any time. Technical support runs until 19 November 2026 with
agreed response hours (DEL-10). The runbook covers:
- the deployment order (OPS-2);
- switching royalty enforcement off and on (OPS-6);
- pausing and opening burns around 29 October (ACT-15);
- loading the whitelist into Studio and checking it (WL-4);
- running a mystery-box cycle (RAF-18).

*Technical note.* The runbook is one document, backed by `forge script` tooling. MINT's admin
takes the worker role back with `setWorker` `→ CQ-23`.

#### Scenario: Nothing stays with Calea
- **WHEN** handover completes
- **THEN** every contract's owner is MINT's admin, every source is verified and the runbook is delivered
- **AND** Calea holds no owner key, and no role other than the worker's where CQ-23 gives it one

### Requirement: OPS-6 — Enforcement runbook
**Kind:** work-item
Royalty enforcement is on from deployment. MINT's admin can tighten it later, and can switch it
off with one call and back on with one; every step is reversible. The strictest settings, which
would stop holders sending bears to contract wallets, are never used.

*Technical note.* Enabled at deployment: `MintABear.setTransferValidator(0x721C002B…)` with the
validator's zero-state policy. Optional, from the admin: `createList`, `addAccountsToWhitelist`,
`addAccountsToAuthorizers`, `applyListToCollection`, `setTransferSecurityLevelOfCollection`
(never level 5 or above). Disable: `setTransferValidator(address(0))`. Every step is an owner
call.

#### Scenario: Enforcement toggles by one call
- **GIVEN** enforcement enabled
- **WHEN** the admin calls `setTransferValidator(address(0))` and then sets V3 again
- **THEN** each call emits `TransferValidatorUpdated` and the policy follows the current value

### Requirement: OPS-7 — Chain constraints
**Kind:** informative
Three facts about Robinhood Chain shape the design:
- it can block an individual holder's transactions (compliance screening), so nothing depends on
  a holder acting by a deadline; a box left unopened is just a shot not taken;
- each transaction has a gas limit, so no call loops over the whole collection;
- there is no randomness on Robinhood Chain or ApeChain, so the draw runs on Arbitrum One.

*Technical note.* On Robinhood Chain `block.number` is the L1 height, so contracts and scripts key
on timestamps. The gas limit is Arbitrum-style, per transaction.

#### Scenario: The design honours the chain
- **WHEN** the contracts are reviewed against the chain's constraints
- **THEN** no logic keys on `block.number`, no call loops over the collection, and no correctness depends on a holder acting by a deadline
