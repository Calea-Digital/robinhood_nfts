# Operations, roles and handover Specification

## Purpose
MINT needs to receive contracts that are correct from their first block, verified on every chain, and handed over with every key, role and a runbook — so that operating them after 19 November needs nothing from Calea.

## Requirements

### Requirement: OPS-1 — Addresses
**Kind:** work-item
The three control keys are recorded before mainnet deployment; the
royalty receiver follows, before the first sale (COL-6). `→ CQ-12`, `→ CQ-15`.

| Role | Holds | Recommendation |
|---|---|---|
| Admin | owner of every contract on every chain | Safe multisig controlled by Iñigo; one EOA per chain if Safe's interface does not cover a chain |
| Worker | `MysteryBox`, every `PrizeVault`, `PrizeDraw` | EOA held by MINT automation, funded on each chain |
| Eligibility signer | `WhitelistClaim.signer` | Backend key held by MINT; rotatable by the admin |
| Royalty receiver | ERC-2981 receiver — the pot | MINT, separate from the admin |
| Prize vaults | the `PrizeVault` contracts, one per prize chain | — |

`DirectBurnAdapter` has no role.

#### Scenario: The recorded keys are the deployed ones
- **WHEN** the mainnet deploy scripts run
- **THEN** the admin, worker and signer addresses they read are the ones MINT recorded
- **AND** the royalty receiver is set in Studio before the first sale

### Requirement: OPS-2 — Deployment order
**Kind:** work-item
Every address a contract needs at birth is a constructor argument,
so a contract is correct from its first block and is never deployed-but-unconfigured (MINT,
CQ-12). One cannot be: `Activation.setCrediter`, because the adapter does not exist until
`Activation` does. `WhitelistClaim.setSigner` exists so the admin can rotate the signer; the
first signer is a constructor argument. Both stay owner-only. The other calls made after
construction are settings and hand-overs, each in the order listed: `setMaxSupply`,
`setTransferValidator`, `setPaused(true)` and ownership transfers. Robinhood Chain:
`MintABear(name, symbol, [SeaDrop])` → `setMaxSupply(4444)` → `setTransferValidator(V3)`
(COL-7) → two-step ownership transfer → provenance, `baseURI` and royalties set by Iñigo
through Studio, before the drop page is published (COL-5, COL-6, COL-10).
`WhitelistClaim(owner, signer, openAt, closeAt)`, with MINT's admin as `owner`, before the
campaign opens. `Activation(bears, thresholds, weights)` → `DirectBurnAdapter(mntd, activation)`
→ `setCrediter(adapter)` → `setPaused(true)` until the switch-on date → ownership; requires
$MNTD on 4663. `MysteryBox(bears, worker)` → ownership; `PrizeVault(worker)` → `approveAsset`
per prize asset → ownership. Ethereum and ApeChain: `PrizeVault(worker)` → approvals →
ownership. The Chainlink chain: `PrizeDraw(coordinator, subscriptionId, keyHash, worker,
playable, prizeCount, manifestHash)` → added as consumer → ownership. Each contract is deployed
before the page that depends on it is published.

#### Scenario: Correct from the first block
- **WHEN** the deploy script runs on a fresh chain
- **THEN** each contract is created with its constructor arguments in the listed order and is never left deployed-but-unconfigured
- **AND** the only address set after construction is `Activation`'s crediter; every other call after construction is a listed setting or ownership transfer, in the listed order

### Requirement: OPS-3 — Verification
**Kind:** work-item
Sourcify for 4663 and 46630 (mainnet Blockscout's API sits behind a bot
challenge); Etherscan for Ethereum and Sepolia; Apescan for ApeChain and Curtis; Basescan for
Base and Base Sepolia.

#### Scenario: Source is verified where the chain allows
- **WHEN** a contract is deployed on 4663 or 46630
- **THEN** its source is verified through Sourcify and readable there

### Requirement: OPS-4 — Rehearsal on testnets (46630, Sepolia, Curtis, Base Sepolia)
**Kind:** work-item
Studio attaches to and
manages a self-deployed, validated `MintABear`; both mint paths (OpenSea and the getminted.io
mirror); a whitelist claim from voucher to exported allowlist to a two-per-wallet allowlist mint; a
burn through the adapter against $MNTD on 46630 through to a credited level; a full multi-chain
game — deposits on the testnets, commit, exclude, open, boxes opened, relays, words, outcomes,
awards, claims and expiry, including one open that wins and one that does not; an OpenSea testnet
listing of the validated collection. On mainnet, before the drop page is published: one team bear
listed and sold on OpenSea (COL-7).

#### Scenario: Every path is rehearsed
- **WHEN** the rehearsal runs on 46630, Sepolia, Curtis and Base Sepolia
- **THEN** each listed path completes end to end, including one open that wins and one that does not

### Requirement: OPS-5 — Handover
**Kind:** work-item
Calea deploys, configures, transfers ownership, verifies source, and delivers
the runbook; after that it holds no key and no role. Technical support runs through
19 November 2026 with agreed response hours (DEL-10). The runbook is one document, produced via
`forge script` tooling, covering deploy order (OPS-2), the enforcement toggle (OPS-6) and
Activation's pause/unpause around the burn switch-on date (ACT-11), the whitelist export (WL-4),
and the mystery-box worker sequence (RAF-18).

#### Scenario: Nothing stays with Calea
- **WHEN** handover completes
- **THEN** every contract's owner is MINT's admin, every source is verified and the runbook is delivered
- **AND** Calea holds no key and no role

### Requirement: OPS-6 — Enforcement runbook
**Kind:** work-item
Enabled at deployment: `MintABear.setTransferValidator(0x721C002B…)`
with the validator's zero-state policy. Optional, from the admin: `createList`,
`addAccountsToWhitelist`, `addAccountsToAuthorizers`, `applyListToCollection`,
`setTransferSecurityLevelOfCollection` (never level 5 or above). Disable:
`setTransferValidator(address(0))`. Every step is an owner call and reversible.

#### Scenario: Enforcement toggles by one call
- **GIVEN** enforcement enabled
- **WHEN** the admin calls `setTransferValidator(address(0))` and then sets V3 again
- **THEN** each call emits `TransferValidatorUpdated` and the policy follows the current value

### Requirement: OPS-7 — Chain constraints
**Kind:** informative
On Robinhood Chain `block.number` is the L1 height — contracts and
scripts key on timestamps. Sequencer-level compliance screening can block an individual
holder's transactions, so nothing in the system requires a holder to act by a deadline in
order for the system to stay correct: an unclaimed prize expires back to inventory, a missed
box left unopened is a shot not taken, and nothing else depends on either. Robinhood Chain
applies an Arbitrum-style per-transaction gas limit, which is why no call in this system loops
over the collection.
Randomness is not available on Robinhood Chain or ApeChain, which is why the seed comes from
Base.

#### Scenario: The design honours the chain
- **WHEN** the contracts are reviewed against the chain's constraints
- **THEN** no logic keys on `block.number`, no call loops over the collection, and no correctness depends on a holder acting by a deadline
