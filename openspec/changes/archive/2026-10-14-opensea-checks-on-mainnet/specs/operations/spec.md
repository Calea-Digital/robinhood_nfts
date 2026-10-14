## MODIFIED Requirements

### Requirement: OPS-4 — Rehearsal on testnets (46630, Arbitrum Sepolia, Sepolia)
**Kind:** work-item
Before mainnet, everything on-chain is rehearsed on the testnets:
- the collection deployed with royalty enforcement on, and a holder's own transfer passing;
- the whitelist end to end on SeaDrop: a list set by the owner, and wallets minting their spots
  and no more;
- a burn raising a bear's level, against a test $MNTD;
- two mystery-box cycles: team bears excluded, both chains scheduled, one win and one loss, a win
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
