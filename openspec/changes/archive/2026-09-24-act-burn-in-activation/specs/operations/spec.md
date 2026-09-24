# Spec Delta

## MODIFIED Requirements

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

#### Scenario: The recorded keys are the deployed ones
- **WHEN** the mainnet deploy scripts run
- **THEN** the admin, worker and signer addresses they read are the ones MINT recorded
- **AND** the royalty receiver is set in Studio before the first sale

### Requirement: OPS-2 — Deployment order
**Kind:** work-item
Every address a contract needs at birth is a constructor argument,
so a contract is correct from its first block and is never deployed-but-unconfigured (MINT,
CQ-12). `WhitelistClaim.setSigner` exists so the admin can rotate the signer; the first signer is
a constructor argument, and it stays owner-only. The calls made after construction are settings
and hand-overs, each in the order listed: `setMaxSupply`, `setTransferValidator`,
`setPaused(true)` and ownership transfers. Robinhood Chain:
`MintABear(name, symbol, [SeaDrop])` → `setMaxSupply(4444)` → `setTransferValidator(V3)`
(COL-7) → two-step ownership transfer → provenance, `baseURI` and royalties set by Iñigo
through Studio, before the drop page is published (COL-5, COL-6, COL-10).
`WhitelistClaim(owner, signer, openAt, closeAt)`, with MINT's admin as `owner`, before the
campaign opens. `Activation(bears, mntd, thresholds, weights)`, thresholds in whole $MNTD
(ACT-2) → `setPaused(true)` until the switch-on date → ownership; requires $MNTD on 4663.
`MysteryBox(bears, worker)` → ownership; `PrizeVault(worker)` → `approveAsset` per prize asset →
ownership. Ethereum and ApeChain: `PrizeVault(worker)` → approvals → ownership. The Chainlink
chain: `PrizeDraw(coordinator, subscriptionId, keyHash, worker, playable, prizeCount,
manifestHash)` → added as consumer → ownership. Each contract is deployed before the page that
depends on it is published.

#### Scenario: Correct from the first block
- **WHEN** the deploy script runs on a fresh chain
- **THEN** each contract is created with its constructor arguments in the listed order and is never left deployed-but-unconfigured
- **AND** no address is set after construction; every call after construction is a listed setting or ownership transfer, in the listed order

### Requirement: OPS-4 — Rehearsal on testnets (46630, Sepolia, Curtis, Base Sepolia)
**Kind:** work-item
Studio attaches to and
manages a self-deployed, validated `MintABear`; both mint paths (OpenSea and the getminted.io
mirror); a whitelist claim from voucher to exported allowlist to a two-per-wallet allowlist mint; a
burn through `Activation` against $MNTD on 46630 through to a recorded level; a full multi-chain
game — deposits on the testnets, commit, exclude, open, boxes opened, relays, words, outcomes,
awards, claims and expiry, including one open that wins and one that does not; an OpenSea testnet
listing of the validated collection. On mainnet, before the drop page is published: one team bear
listed and sold on OpenSea (COL-7).

#### Scenario: Every path is rehearsed
- **WHEN** the rehearsal runs on 46630, Sepolia, Curtis and Base Sepolia
- **THEN** each listed path completes end to end, including one open that wins and one that does not
