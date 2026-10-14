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

Nothing is deployed on a prize chain (RAF-33).

*Technical note.* The calls after construction are, in order, `setMaxSupply`,
`setTransferValidator` and ownership transfers. Robinhood Chain:
`MintABear(name, symbol, [SeaDrop])` → `setMaxSupply(4444)` → `setTransferValidator(V3)` (COL-7) →
two-step ownership transfer; `Activation(owner, bears, mntd, thresholds, weights)`, thresholds in whole
$MNTD (ACT-2), owned by MINT's admin and paused from construction (ACT-12, ACT-15), with no call
after it; `MysteryBox(owner, bears)` (RAF-27).
Arbitrum One: `PrizeDraw(owner, coordinator, keyHash, subscriptionId, callbackGasLimit,
requestConfirmations, nativePayment, playable, firstOpenIndex)` with `playable` 4,444 and
`firstOpenIndex` 1 → added as the subscription's consumer → `setWorker(worker)` by the owner
(RAF-14).

#### Scenario: Correct from the first block
- **WHEN** the deploy script runs on a fresh chain
- **THEN** each contract is created with its constructor arguments in the listed order and is never left deployed-but-unconfigured
- **AND** no address is set after construction; every call after construction is a listed setting or ownership transfer, in the listed order

### Requirement: OPS-4 — Rehearsal on testnets (46630, Arbitrum Sepolia, Sepolia)
**Kind:** work-item
Before mainnet, everything on-chain is rehearsed on the testnets:
- the collection deployed with royalty enforcement on, and a holder's own transfer passing;
- the whitelist end to end on SeaDrop: a list set by the owner, and wallets minting their spots
  and no more;
- a burn raising a bear's level, against a test $MNTD;
- two mystery-box cycles: both chains scheduled, one win and one loss, a win
  paid and recorded, and a bear opened again in the second cycle.

OpenSea does not support Robinhood Chain's testnet, so what only OpenSea can show is checked on
mainnet before the drop page is published:
- Studio takes over the collection Calea deployed, and Calea's check passes against a test list
  loaded into the whitelist stage, before any stage opens;
- the team's bears are minted, and one is listed and sold on OpenSea (COL-7).

*Technical note.* Testnets 46630, Arbitrum Sepolia (421614) and Sepolia. SeaDrop, Seaport 1.6
and Limit Break's validator V3 are deployed on 46630; OpenSea's SignedZone is not. The whitelist
case on 46630: the owner sets the allowlist root with SeaDrop's `updateAllowList`, `compare`
passes over the CSV against it, a two-spot wallet mints two with its proof, and a one-spot wallet
is refused its second. On mainnet, `compare` passing over a test CSV against the root Studio set
shows that Studio builds the tree, each wallet's limit included, as `AllowListTree` does. The
burn goes through `Activation` against $MNTD on 46630 to a recorded level. The cycles cover relays in order, words and outcomes, and a payout from a prize
wallet on 46630 or Sepolia recorded with `recordPayout`.

#### Scenario: Every path is rehearsed
- **WHEN** the rehearsal runs on 46630, Arbitrum Sepolia and Sepolia
- **THEN** each listed path completes end to end, including one open that wins and one that does not
