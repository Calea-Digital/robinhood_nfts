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
admin with the worker as `signer` from construction, with no call after it.

#### Scenario: Correct from the first block
- **WHEN** the deploy script runs on a fresh chain
- **THEN** each contract is created with its constructor arguments in the listed order and is never left deployed-but-unconfigured
- **AND** no address is set after construction; every call after construction is a listed setting or ownership transfer, in the listed order

### Requirement: OPS-3 — Verification
**Kind:** work-item
Every contract's source is published and verified: on Sourcify for Robinhood Chain and its
testnet, and on Arbiscan for Arbitrum One and Arbitrum Sepolia. Each prize vault is verified on
its chain too, on Sourcify where the chain is supported and on the chain's explorer otherwise.

*Technical note.* Sourcify for 4663 and 46630, because mainnet Blockscout's API sits behind a bot
challenge; Arbiscan through Etherscan's API for 42161 and 421614. `PrizeVault` on 1, 33139 and
8453 and on their testnets (11155111, 33111, 84532) through Sourcify, or Etherscan's API for the
chain's explorer.

#### Scenario: Source is verified where the chain allows
- **WHEN** a contract is deployed on 4663 or 46630
- **THEN** its source is verified through Sourcify and readable there

### Requirement: OPS-7 — Chain constraints
**Kind:** informative
Three facts about Robinhood Chain shape the design:
- it can block an individual holder's transactions (compliance screening), so nothing depends on
  a holder acting by a deadline except a prize claim: a box left unopened is just a shot not
  taken, and a prize not claimed within one hour of the cycle's end carries over to a later
  cycle (RAF-36, RAF-37);
- each transaction has a gas limit, so no call loops over the whole collection;
- there is no randomness on Robinhood Chain or ApeChain, so the draw runs on Arbitrum One.

*Technical note.* On Robinhood Chain `block.number` is the L1 height, so contracts and scripts key
on timestamps. The gas limit is Arbitrum-style, per transaction.

#### Scenario: The design honours the chain
- **WHEN** the contracts are reviewed against the chain's constraints
- **THEN** no logic keys on `block.number`, no call loops over the collection, and the only deadline a holder faces is a prize's claim window, after which the prize carries over
