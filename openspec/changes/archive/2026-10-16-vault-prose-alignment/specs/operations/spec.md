## MODIFIED Requirements

### Requirement: OPS-1 — Addresses
**Kind:** work-item
The keys and wallets the system uses are recorded before mainnet deployment; the royalty receiver
is recorded before the first sale (COL-6).

| Role | What it does | Who holds it |
|---|---|---|
| Admin | owns every contract on every chain | MINT, `0x1530…6141` |
| Worker | carries openings to the draw, signs each winner's claim ticket and records claims | MINT, a key MINT creates (CQ-23) |
| Royalty receiver | receives the 5% royalties (the pot) | MINT, `0xf7E7…0e63` |
| Prize wallet | funds the prize vaults with each cycle's prizes | MINT, `0xf6c0…83e3` |
| Randomness subscription | pays for the draw's random numbers | Calea, invoicing MINT (CQ-17) |

*Technical note.* Admin `0x153052B43c8fD4ec01f14D1Edd8660778daa6141`, an EOA (MINT, 28 September
2026), owner of every contract on every chain (MINT, 12 October 2026, CQ-12). A later move to a
multisig goes through each contract's two-step handover (COL-10, ACT-12, RAF-14). Worker: an EOA MINT creates and funds with ETH on
Arbitrum One, holding `resolve` and `recordPayout` on `PrizeDraw` and set as every
`PrizeVault`'s `signer`, whose key signs the claim tickets (CQ-23, RAF-18, RAF-36). Royalty receiver
`0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63`, the ERC-2981 receiver `→ CQ-15`. Prize wallet
`0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3`, an EOA that sends each cycle's prizes to the vault
on their chain during cycle setup and pays no winner itself (RAF-33, RAF-35). VRF subscription:
the Chainlink subscription `PrizeDraw` draws on, owned by a Calea wallet on Arbitrum One (CQ-17).

#### Scenario: The recorded keys are the deployed ones
- **WHEN** the mainnet deploy scripts run
- **THEN** the admin and worker addresses they read are the ones MINT recorded
- **AND** the royalty receiver is set in Studio before the first sale

### Requirement: OPS-3 — Verification
**Kind:** work-item
Every contract's source is published and verified on Sourcify: on Robinhood Chain and its
testnet, and on Arbitrum One and Arbitrum Sepolia. Each prize vault is verified on its chain too,
on Sourcify where the chain is supported and on the chain's explorer otherwise.

*Technical note.* Sourcify for 4663 and 46630, because mainnet Blockscout's API sits behind a bot
challenge, and for 42161 and 421614, where Arbiscan shows a Sourcify-verified source; one route
needs no explorer API key (the person's choice, 16 October 2026). `PrizeVault` on 1, 33139 and
8453 and on their testnets (11155111, 33111, 84532) through Sourcify, or Etherscan's API for the
chain's explorer.

#### Scenario: Source is verified where the chain allows
- **WHEN** a contract is deployed on 4663 or 46630
- **THEN** its source is verified through Sourcify and readable there

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
burn goes through `Activation` against $MNTD on 46630 to a recorded level. The cycles are the
rehearsal of 15 October 2026: relays in order, words and outcomes, and each win paid on 46630 from
the rehearsal wallet and recorded with `recordPayout`. The prize vaults' run on the testnets,
claims with the worker's tickets included, is RAF-18's.

#### Scenario: Every path is rehearsed
- **WHEN** the rehearsal runs on 46630, Arbitrum Sepolia and Sepolia
- **THEN** each listed path completes end to end, including one open that wins and one that does not

### Requirement: OPS-5 — Handover
**Kind:** work-item
Calea deploys, configures, hands over ownership, verifies the source and delivers the runbook,
then holds no owner key. It keeps the randomness subscription, which it funds and invoices to
MINT (CQ-17) and can hand to MINT at any time. It keeps no contract role: MINT runs the worker
(CQ-23). Technical support runs until 19 November 2026 with
agreed response hours (DEL-10). The runbook covers:
- the deployment order (OPS-2);
- switching royalty enforcement off and on (OPS-6);
- pausing and opening burns around 29 October (ACT-15);
- loading the whitelist into Studio and checking it (WL-4);
- running a mystery-box cycle (RAF-18), funding and registering its prizes on the vaults, and
  setting up, funding and running the worker;
- moving each contract's ownership to a new owner, such as a multisig (COL-10, ACT-12, RAF-14).

*Technical note.* The runbook is one document, backed by `forge script` tooling. MINT's admin
authorises the worker with `setWorker` on `PrizeDraw` and `setSigner` on each `PrizeVault`
(CQ-23). The ownership steps cover all five contracts: `MintABear`'s
`transferOwnership` then `acceptOwnership`, and the Solady handover on `Activation`, `MysteryBox`,
`PrizeDraw` and each `PrizeVault` (`requestOwnershipHandover` from the new owner,
`completeOwnershipHandover` from the owner within 48 hours), each with its read-back of `owner()`,
and the same steps as a Safe proposes them.

#### Scenario: Nothing stays with Calea
- **WHEN** handover completes
- **THEN** every contract's owner is MINT's admin, every source is verified and the runbook is delivered
- **AND** Calea holds no owner key and no contract role; it holds the randomness subscription (CQ-17)
