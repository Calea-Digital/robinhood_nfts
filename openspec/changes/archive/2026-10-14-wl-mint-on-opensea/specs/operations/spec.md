## MODIFIED Requirements

### Requirement: OPS-4 — Rehearsal on testnets (46630, Arbitrum Sepolia, Sepolia)
**Kind:** work-item
Before mainnet, everything is rehearsed on the testnets:
- Studio managing a collection Calea deployed, with royalty enforcement on;
- minting through OpenSea's drop page;
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
