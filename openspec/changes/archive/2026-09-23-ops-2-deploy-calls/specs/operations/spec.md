# Spec Delta

## MODIFIED Requirements

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
