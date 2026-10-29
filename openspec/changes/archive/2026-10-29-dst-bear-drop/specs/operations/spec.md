# Spec Delta

## MODIFIED Requirements

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
- **Every prize chain** (Robinhood Chain, Ethereum, ApeChain; Base when a cycle first uses it):
  the prize vault, at the same address on each, before the first cycle that holds a prize there
  (RAF-35).
- **Holders' $MNTD** (Robinhood Chain): `BearDrop`, before the first round MINT announces (DST-1).
  Calea deploys it, loads and checks round 1's list (DST-6) and hands ownership to MINT's admin, who
  funds it and opens the round.

*Technical note.* The calls after construction are, in order, `setMaxSupply`,
`setTransferValidator` and ownership transfers. Robinhood Chain:
`MintABear(name, symbol, [SeaDrop])` → `setMaxSupply(4444)` → `setTransferValidator(V3)` (COL-7) →
two-step ownership transfer; `Activation(owner, bears, mntd, thresholds, weights)`, thresholds in whole
$MNTD (ACT-2), owned by MINT's admin and paused from construction (ACT-12, ACT-15), with no call
after it; `MysteryBox(owner, bears)` (RAF-27).
Arbitrum One: `PrizeDraw(owner, coordinator, keyHash, subscriptionId, callbackGasLimit,
requestConfirmations, nativePayment, playable, firstOpenIndex)` with `playable` 4,444 and
`firstOpenIndex` 1 → added as the subscription's consumer → `setWorker(worker)` by the owner
(RAF-14). Each prize chain: `PrizeVault(owner, signer)` through the CREATE2 deployer
`0x4e59b44847b379578588920cA78FbF26c0B4956C` with the same salt and arguments, owned by MINT's
admin with the worker as `signer` from construction, with no call after it. Robinhood Chain, for
holders' $MNTD: `BearDrop(owner, bears, mntd)`, owned by the deploying wallet → `setAmounts` batches for
round 1 (DST-6) → MINT's admin `requestOwnershipHandover` → `completeOwnershipHandover(admin)` (DST-5);
MINT funds the contract and calls `openRound`.

#### Scenario: Correct from the first block
- **WHEN** the deploy script runs on a fresh chain
- **THEN** each contract is created with its constructor arguments in the listed order and is never left deployed-but-unconfigured
- **AND** no address is set after construction; every call after construction is a listed setting or ownership transfer, in the listed order
