<!-- GENERATED sections between openspec markers are written by docs/tools/spec_tools/render_calea_prose.py from openspec/. Edit openspec/ and the narrative here, then run docs/tools/board.sh. -->
# MintABear — Specification

<!-- openspec:begin version -->
**Version** 2.6 · **Date** 29 September 2026 · **Status** for sign-off once the open items in §10
are settled
<!-- openspec:end -->

Prepared by Calea for MINT. It states what Calea builds for MintABear and what is still MINT's to
decide. It draws on MINT's statement of work (14 September 2026), MINT's written answers, the
calls of 15, 21 and 28 September 2026, and MINT's replies of 29 September. Where these differ,
this document gives the resolution.

**How to read.** §10, at the front, lists what is settled and what is still open. Each
requirement has an identifier: COL for the collection, WL for the whitelist, ACT for activation,
RAF for the mystery box, OPS for operations and DEL for deliverables. Most carry an acceptance
line, the test that shows the requirement is met. Where MINT hasn't decided yet, the requirement
gives Calea's recommendation, which is what gets built if the decision is deferred. A yellow line
under a section marks a question still open there, and §10 sets it out. The appendices list the
settled questions and the retired requirements.

## Where the work stands

As of 29 September 2026. Nothing is deployed yet.

| Part | Where it stands |
|---|---|
| Collection (§3) | Built and reviewed |
| Whitelist (§4) | In MINT's backend. Calea's check that Studio's list matches MINT's final list is ready before the freeze on 27 October |
| Activation (§5) | Built and reviewed. Deployed at TGE with burning paused; burning opens on 29 October |
| Client library (DEL-6) | Built and reviewed: mint, burn, transfers, reads and the royalty split, with a ready-to-show message for every error. Holders mint on OpenSea's drop page, so the library reads the mint's progress and sends no mint |
| Deployment and runbook (§7) | Scripts written and tested; the runbook covers every operating step |
| Internal audit | Tranche 1 (collection and activation): 30 September – 1 October |
| Testnet rehearsal | 16 October on 46630; Studio and the first OpenSea sale are proven on mainnet, 19–21 October (OPS-4) |
| Mystery box (§6) | Built and in review for staging (pull request #13); every bear plays (CQ-20) |

**What the client library needs from MINT.** None of these changes a contract. Each is needed
before the page it serves goes live.
- **The final whitelist list** by 27 October: one row per wallet with its number of spots.
- **OpenSea's fee recipient for the drop**, which every mint names, and access to OpenSea's
  listings API, so the page can warn a holder whose bear is listed before they burn.
- **An archive RPC endpoint for Robinhood Chain**, for the royalty split.
- **The wording of holder messages**, optionally. The library ships plain-English defaults that
  MINT can replace or translate.

**Changes since v2.5.**
- **Easier to read.** Each requirement states in plain words what it does; the technical detail
  stays in Calea's specification and the repository. Settled questions are no longer repeated
  under each section, and §10 lists the open items soonest first.
- **Repository.** `github.com/mintdotio/NFT` (CQ-14).
- **Existing-contract review.** Withdrawn, so DEL-7 is retired. Calea's review work is the
  internal audit of its own contracts; tranche 1's runs on 30 September and 1 October (CQ-13).
- **Whitelist.** The 1,000 wagering spots are guaranteed. Collaborations and giveaways add up to
  3,222 more on top, so every spot has a bear, and getminted.io shows a wallet all of its spots
  (CQ-18, CQ-24; WL-1, WL-4, WL-8). The final list names the wallet that will mint, for a smart
  wallet its own address (WL-4).
- **Commercial items.** "The unique-winner rule" is replaced by the cycles and the win rule
  (DEL-10).
- **Calendar.** Rows in date order, the past row removed, the internal audit added (§8).

## 1. Scope

### 1.1 What Calea delivers

- **The collection** (§3): the 4,444-bear contract on Robinhood Chain, run by MINT from OpenSea
  Studio, with royalties enforced.
- **Whitelist support** (§4): the check that Studio's list matches MINT's final list, and the mint
  proofs built from it.
- **Activation** (§5): the contract that burns $MNTD to raise a bear's level and holds the royalty
  weights.
- **The mystery box** (§6): a contract on Robinhood Chain that records each opening, and the draw
  on Arbitrum One that decides it and records the payout.
- **Quality**: tests for every requirement, and the internal audit report (review, fuzzing) for
  each tranche.
- **Deployment** (§7): scripts, a testnet rehearsal, verified mainnet deployment, the runbook and
  the handover.
- **Integration**: the TypeScript client library for getminted.io, review of the page's contract
  calls, and delivery into `github.com/mintdotio/NFT`, gated by Calea before each pull request
  (DEL-6, DEL-9, DEL-11).
- **Support** until 19 November.

### 1.2 What Calea does not deliver

- **Excluded by the statement of work:** an independent external audit; fixes to existing MINT
  contracts; on-chain artwork; automatic bridging or trading; unsupported assets; new casino free
  spins.
- **MINT's:**
  - artwork, metadata and reveal;
  - the Privy login, the wager API, the eligibility check and the whitelist;
  - the web app, the Framer pages and the admin page;
  - the royalty pot: buying $MNTD, the split wallet and crediting accounts. Calea provides a
    reference script that reproduces the split;
  - the Status boost and Status links;
  - holding and paying prizes;
  - monitoring and alerts;
  - backend services and indexing, and running the worker Calea builds (CQ-23).
- **Not part of the design:** token-bound accounts (ERC-6551, COL-9); bridging prizes between
  chains; cross-chain messaging.

### 1.3 Who does what

| Party | Responsibility |
|---|---|
| Iñigo (MINT) | Runs the collection in OpenSea Studio; holds the admin wallet; approves prizes; accepts deliverables |
| Robert (MINT) | Funds the treasury and reserves; settlement |
| Javier (MINT) | Builds the page on getminted.io |
| Lorenzo (MINT) | Privy login; account, Status and wager APIs |
| Vlad (MINT) | Privy connection on getminted.io and the wager API, with Lorenzo |
| Guri (MINT) | The whitelist eligibility check |
| MINT's wallets | Admin `0x1530…6141`: mints the team bears, schedules each cycle, pauses. Prize wallet `0xf6c0…83e3`: holds and pays prizes |
| Worker | Carries each box opening to the draw and records payouts. Built by Calea, run by MINT from a key MINT creates (CQ-23) |
| Calea / Rayco | Builds, tests, deploys and hands over the contracts and the client library. Keeps no key or contract role after handover. Holds and funds the randomness subscription, invoicing MINT (CQ-17) |
| Calea internal auditor | Audits each tranche independently of the developer: review, fuzzing, report |

## 2. System overview (SYS)

**Where it runs.**

| Chain | What it holds |
|---|---|
| Robinhood Chain | The bears, their levels and the mystery box's openings; the prize vault for prizes on this chain |
| Arbitrum One | The draw, which uses Chainlink's randomness (Robinhood Chain has none) |
| Ethereum | The prize vault for prizes on Ethereum |
| ApeChain | The prize vault for prizes on ApeChain |
| Base | The prize vault, deployed when a cycle first holds a prize on Base |

Everything is rehearsed first on the testnets: Robinhood Chain testnet (46630), Arbitrum Sepolia,
Sepolia and, if ApeChain holds prizes, Curtis.

**The contracts.**

| Contract | Chain | What it does |
|---|---|---|
| `MintABear` | Robinhood Chain | The 4,444-bear collection. Counts every transfer, which resets a bear's level, and enforces royalties |
| `Activation` | Robinhood Chain | Burns $MNTD for a bear and records its level and royalty weight |
| `MysteryBox` | Robinhood Chain | Runs the cycles, checks that the opener owns the bear, and records each opening |
| `PrizeDraw` | Arbitrum One | Decides each opening in turn with a fresh random number, and records wins and payouts |

The whitelist has no contract (WL-8).

**Who can do what.**
- **The contracts enforce:**
  - ownership and the 4,444 cap;
  - the level reset on transfer, levels and weights;
  - one shot per bear per cycle;
  - the order of the draw.
- **MINT's admin wallet**, one wallet for every contract, configures Studio, pauses burning,
  and schedules each cycle with its prize list. It cannot move a holder's bear, grant a level
  without a burn, or change an outcome. It can allow another minter on the collection, so that
  key has to be kept safe.
- **The prize vault** on each prize chain holds the cycle's prizes, which MINT's prize wallet
  sends it during cycle setup. It releases each prize once, only to the winner the draw named,
  within the claim window; what is not claimed stays for a later cycle. Every win and every
  claim is public, so an unclaimed win is visible to anyone.
- **The worker** carries each opening to the draw, signs each winner's claim ticket and records
  the claims. It cannot change an outcome or the order. It can only delay one, and a delay is
  visible. Its key also signs tickets, so a leak of it could claim the current cycle's unclaimed
  prizes; MINT can pause the vaults and change the key.
- **The whitelist is MINT's word.** MINT's backend decides who is on it. The chain holds only
  Studio's list, which Calea checks against MINT's final list.

**What stays off-chain, with MINT:**
- wager tracking and the whitelist;
- the Privy login that ties wallets to getminted.io accounts;
- Status boosts and links;
- the royalty pot and its split: half the ETH buys $MNTD, and both are credited to accounts by
  bear weight (ACT-10);
- the prize lists and the prizes;
- the UI, the admin page, indexing and alerts.

What a level is worth is MINT's to define. The chain records only that it was reached.

**End to end.**
1. **Whitelist.** Holders claim spots on getminted.io. MINT freezes the list and loads it into
   Studio, and Calea checks it.
2. **Mint.** Iñigo runs the drop in Studio, and holders mint on OpenSea's drop page.
3. **Burn.** A holder burns $MNTD for a bear, and its level and weight rise.
4. **Transfer.** Any transfer resets the bear's level to 0.
5. **Mystery box.** MINT schedules a cycle and publishes its prize list. A holder opens a box with
   a bear and the draw decides it at once. A winner claims the prize from the vault on its chain within an hour of the cycle's end, and the claim is recorded.
6. **Royalties.** At each closing, MINT reads every bear's weight and splits the pot.

## 3. Collection contract — MintABear (COL)


<!-- openspec:begin family COL -->
A 4,444-bear collection on Robinhood Chain that MINT runs from OpenSea Studio. It collects royalties on every marketplace sale, and every transfer resets a bear's level, so the rest of the system relies only on ownership and the transfer count.

**COL-1 Base.** The collection is a standard OpenSea drop contract, so Studio runs the drop, mint pages,
metadata and royalties unchanged. Only OpenSea's official mint contract can mint.

*Technical note.* `MintABear` extends OpenSea's `ERC721SeaDrop` with its mint path,
`getMintStats`, metadata and royalty interfaces unchanged. Canonical SeaDrop
`0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` is the only allowed minter; the drop is configured
and operated through Studio by MINT (COL-11).

*Acceptance.* Given the collection deployed with canonical SeaDrop as its only allowed minter; when any other address calls the mint path; then the call reverts and no bear is minted.

**COL-2 Supply.** At most 4,444 bears, fixed in the code. Team, treasury, partner and whitelist bears all come
out of the same 4,444. Studio's supply setting is set to exactly 4,444 and cannot raise the cap.
No bear can be destroyed (COL-8), so the supply is exactly 4,444 once minted out.

*Technical note.* `MAX_BEARS = 4444` is a constant enforced on the mint path; a mint that would
exceed it reverts with `ExceedsMaxBears`. The inherited `maxSupply` is a Studio setting (COL-11)
set to exactly 4,444: `MAX_BEARS` refuses the mint whatever `maxSupply` says, so raising it would
only advertise a supply the token will not deliver, and buyers past the cap would pay for
reverted transactions.

*Acceptance.* Given 4,444 bears minted; when SeaDrop mints one more, whatever `maxSupply` says; then the transaction reverts with `ExceedsMaxBears`.

**COL-3 Transfer counter.** Every bear counts its transfers: sales, gifts, moves between the holder's own wallets, and
returns to a previous owner. Minting doesn't count, and the count never resets. A new count is
what resets the bear's level and weight (ACT-5).

*Technical note.* `transferNonce(tokenId)` increments on every transfer except mint and never
resets.

*Acceptance.* Given a bear whose `transferNonce` reads n; when it is transferred to another wallet; then `transferNonce` reads n + 1; and a freshly minted bear reads 0.

**COL-4 Reset event.** Every transfer publishes a reset signal in the same transaction, whether or not the bear had a
level, so getminted.io and indexers see the reset at once.

*Technical note.* `TransferNonceAdvanced(uint256 indexed tokenId, uint64 nonce)` is emitted for
every non-mint transfer, in the same transaction as `Transfer`. Anything `Activation` recorded at
the previous counter value is void once it fires.

*Acceptance.* When a bear is transferred, whether or not it has a level; then `TransferNonceAdvanced(tokenId, nonce)` is emitted in the same transaction as `Transfer`.

**COL-5 Metadata.** Standard OpenSea metadata, set in Studio, with the provenance committed before the mint opens.
Artwork is fixed, and a bear's level never changes its metadata. Placeholder, reveal and hosting
are MINT's.

*Technical note.* `baseURI` is set through Studio and `tokenURI(id) = baseURI + id`; the
provenance hash is committed with `setProvenanceHash` before the mint opens.

*Acceptance.* Given `baseURI` set through Studio; when `tokenURI(id)` is read; then it returns `baseURI` followed by `id`; and raising the bear's level changes nothing in it.

**COL-6 Royalties.** 5% of every sale goes to MINT's royalty pot `0xf7E7…0e63`, which is neither the admin wallet
nor the prize wallet (RAF-33). Iñigo sets it in Studio any time before the first sale, so it
doesn't hold up deployment.

*Technical note.* ERC-2981 through SeaDrop's `setRoyaltyInfo`: 500 basis points to
`0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63` (CQ-15).

*Acceptance.* Given royalty info set in Studio to 500 basis points and the pot address; when `royaltyInfo(id, salePrice)` is read; then it returns the pot address and 5% of `salePrice`.

**COL-7 Enforced royalties.** Royalties are enforced from deployment. A marketplace sale settles only through OpenSea or a
Payment Processor venue, and royalties are collected on every such sale; orders from other
venues fail. A holder's own transfers always pass, so a sale arranged outside a marketplace
(directly, or through an escrow) pays no royalty. No setting that lets holders move their own
bears can prevent that. OpenSea does not support Robinhood Chain's testnet, so its handling is
proven on mainnet before the drop page is published: Studio takes over the collection, and one
team bear is listed and sold. If OpenSea cannot fill
orders, one owner call lifts enforcement and one restores it (OPS-6).

*Technical note.* `MintABear` implements `ICreatorToken` (ERC-721C) and is deployed with
`setTransferValidator(0x721C002B0059009a671D00aD1700c9748146cd1B)`, Limit Break validator V3 on
4663, under the validator's zero-state policy: security level 0 (operator whitelist,
holder-initiated transfers always allowed, no receiver constraint) and list 0 (the Payment
Processor whitelist, with OpenSea's SignedZone `0x000056F7000000EcE9003ca63978907a00FFD100` as
authorizer). A Seaport order from any venue but OpenSea's SignedZone-restricted orders reverts.
Security levels 5 and above also restrict contract receivers and are never used. The lift is
`setTransferValidator(address(0))`; every change emits `TransferValidatorUpdated`.

*Acceptance.* Given the validator set to V3 with the zero-state policy; when a holder transfers a bear directly; then the transfer passes; and a Seaport order from a venue other than OpenSea's SignedZone reverts.

**COL-8 No burn.** No bear can be destroyed, by anyone, its owner included, so the supply never falls. A bear sent
to an address nobody controls stays in the supply. Nobody can open a mystery box with it
(RAF-28), and it is left out of the royalty split (ACT-10).

*Technical note.* The transfer hook refuses `to == address(0)` with `BurnDisabled`, so
`ERC721SeaDrop.burn` always reverts and `totalSupply` never falls; the royalty snapshot excludes
the canonical dead address `0x…dEaD`.

*Acceptance.* When anyone, the owner included, calls `burn` or transfers a bear to the zero address; then it reverts with `BurnDisabled`; and `totalSupply` is unchanged.

**COL-9 No token-bound accounts.** Bears don't come with wallets of their own (ERC-6551). These can be added later without
changing the collection. The one thing that can't be added later is a guard against sending a
bear into a bear's own wallet.

*Technical note.* The canonical registry `0x000000006551c19487814612e58FE06813775758` derives an
account address from `(chainId, tokenContract, tokenId)` for any ERC-721, so accounts need no
change to `MintABear`.

*Acceptance.* When the deployed `MintABear` is inspected; then it holds no ERC-6551 account code, no account guard and no registry call.

**COL-10 Ownership.** Calea deploys the collection and hands ownership to MINT's admin in two steps, before the drop
page is published: Calea offers and the admin accepts. Calea keeps no role. Ownership can never
be given up, because an ownerless collection would freeze every Studio setting and the
royalty-enforcement switch.

*Technical note.* The inherited two-step process: `transferOwnership`, then `acceptOwnership`
from the admin. `renounceOwnership` reverts for every caller, the owner included: an ownerless
collection would freeze Studio's drop configuration, `baseURI`, royalties and the
transfer-validator lift and restore (OPS-6), and a pending ownership offer would survive it.

*Acceptance.* Given Calea has called `transferOwnership(admin)`; when the admin calls `acceptOwnership`; then the admin is the owner; and Calea holds no role, and `renounceOwnership` reverts for the admin as for anyone else.

**COL-11 What Studio owns.** Studio sets the mint stages, dates and prices; allowlists and per-wallet limits, including the
whitelist stage loaded from MINT's final list (WL-4); the payout address; the supply setting
(COL-2); metadata and provenance (COL-5); and royalties (COL-6). A "guaranteed" stage is
guaranteed by the order of stages (it must close before the next opens), not by the contract.

*Technical note.* Studio writes these through SeaDrop's owner calls, `multiConfigure` among them.

**COL-12 Reads.** The page can read for free: who owns a bear, whether it exists, the supply and the cap, its
transfer count, metadata, royalty info, the enforcement setting and a wallet's mint stats, plus
the standard NFT reads.

*Technical note.* `ownerOf`, `exists(tokenId)`, `totalSupply`, `maxSupply`, `MAX_BEARS`,
`transferNonce`, `tokenURI`, `royaltyInfo`, `getTransferValidator`, `getMintStats`, plus the
ERC-721 and SeaDrop standard surface.

*Acceptance.* When `ownerOf`, `exists`, `totalSupply`, `maxSupply`, `MAX_BEARS`, `transferNonce`, `tokenURI`, `royaltyInfo`, `getTransferValidator` and `getMintStats` are called for a minted bear; then each returns without reverting; and `exists(id)` is false for an unminted id.

**COL-13 Events.** The collection publishes the standard transfer and approval events, Studio's configuration
events, the reset signal (COL-4) and every change to royalty enforcement (COL-7).

*Technical note.* `Transfer`, `Approval`, `ApprovalForAll`; SeaDrop configuration events;
`TransferNonceAdvanced` (COL-4); `TransferValidatorUpdated` (COL-7).

*Acceptance.* When a bear is transferred and the validator is changed; then `Transfer`, `TransferNonceAdvanced` and `TransferValidatorUpdated` are emitted with the documented arguments.
<!-- openspec:end -->

## 4. Whitelist (WL)


<!-- openspec:begin family WL -->
MINT runs a 1,000-spot whitelist for its wagering holders in its own backend. Calea's part is to make sure the list Studio mints from is exactly MINT's final list.

**WL-1 Rules.** - **Spots.** There are 1,000 wagering spots, and each is the right to mint one bear in the
  whitelist stage.
- **Thresholds.** $50 wagered unlocks spot 1 and $100 unlocks spot 2, with no claim needed in
  between. Wagering from before the account's first login on the page counts up to $50, and
  everything wagered after it counts in full, so spot 2 always needs at least $50 wagered after
  that login. For example, a holder with $16,361 wagered before signing in sees one spot
  claimable and $50 more to wager for the second. A refund can lower the credit, but a claimed
  spot stays.
- **First come, first served** on getminted.io/mintabear. Reaching a threshold makes the account
  eligible but reserves nothing. A spot belongs to the wallet once the backend has recorded the
  claim.
- **Live counter.** It shows "spots left — X / 1,000". A claim that arrives after the last spot
  is refused whole.
- **Limits.** The holder chooses the wallet the bear will mint to. There are at most two wagering
  spots per wallet and two per account. The account's first claim locks its wallet, so its
  second spot goes to the same wallet, and a wallet takes wagering spots from one account only.
  Spots from other channels come on top and do not count toward the 1,000 (WL-8).
- **Every spot has a bear.** The 1,000 wagering spots are guaranteed, and every other channel
  together is capped at 3,222 spots. With the 222 team bears that is exactly 4,444, so every
  whitelist spot can be minted while the whitelist stage runs (WL-4, `→ CQ-24`).

**WL-2 Division of work.** - **MINT:**
  - the Privy login;
  - the wager API (Season 1 capped at $50, plus campaign wagering);
  - the eligibility check and the page, which also checks a wallet's spots from every other
    channel;
  - the register with its counter, and the wallet signature for pasted addresses;
  - the final list.

Calea wrote the register's code at MINT's request (29 September 2026), outside the statement of
work. MINT deploys, runs and owns it.
- **Calea:**
  - the check that Studio's list is MINT's final list (WL-4);
  - a review of the backend's claim rules, on request.

**WL-4 Into the mint.** Once the list is frozen (WL-5), MINT exports the final list, one row per wallet with its number
of spots, and Iñigo loads it into Studio's whitelist stage.
- **The mint enforces each wallet's number.** It becomes that wallet's mint limit in the stage.
- **The list names the wallet that will mint.** For a smart wallet, that's the smart wallet's own
  address.
- **The list holds at most 4,222 spots:** the 1,000 wagering spots and at most 3,222 from every
  other channel together. The team's 222 bears are minted first, so every spot has a bear. A spot
  lasts as long as the whitelist stage; bears left unminted go to the next stage.
- **The limit counts every bear the wallet mints, in any stage.** So the whitelist stage is the
  first stage anyone but the team can mint in, no other stage overlaps it, and a later stage's
  limit counts the whitelist mints too.
- **Before the stage opens,** Calea checks that Studio's list is exactly MINT's final list.
- **Holders mint on OpenSea's drop page,** which serves each wallet's proof from Studio's list.

*Technical note.* The final list is a CSV, `wallet,allocations`. Each row becomes a SeaDrop
allowlist leaf whose `maxTotalMintableByWallet` is the row's allocations, and SeaDrop counts it
against every bear minted to the wallet. `compare` in `script/WhitelistExport.s.sol` rebuilds the
allowlist Merkle root from the CSV and the stage's parameters, and fails unless it is the root on
SeaDrop, naming the difference. The row's address is the address that calls `mintAllowList`.
The CSV's allocations total at most 4,222, and `compare` also fails when they total more. The
whitelist stage's `maxTokenSupplyForStage` is 4,444, the collection's total including the team's
222, so the stage can fill every row.

*Acceptance.* Given MINT's final CSV and the whitelist stage Studio has set; when `compare` runs over the CSV and the stage; then it passes only if the root on SeaDrop is the root of the CSV's rows, and fails naming the difference otherwise.

**WL-5 Timing.** MINT's backend takes claims only during the campaign window. The list is frozen at least 48
hours before the whitelist stage opens, which leaves time to load it into Studio, check it and
fix anything. The campaign runs from 30 September to 27 October at 12:00 UTC, and the whitelist
stage opens on 29 October at 12:00 UTC (MINT, 12 October 2026). The 48 hours is Calea's buffer,
not an OpenSea rule. Dates: CQ-1. The hand-off on 27 October:
1. Before 12:00 UTC, MINT loads every other channel's spots into the register. Nothing can be
   added after the freeze.
2. At 12:00 UTC, MINT's CTO freezes the register and exports the final list. A second export must
   be byte for byte the same.
3. By 14:00 UTC, the list and its checksum reach Iñigo and Calea. Iñigo loads it into Studio, and
   Calea's check (WL-4) passes before the stage opens.

*Technical note.* The register's `admin freeze --out <file>` validates the list and locks the
register for good; claims in flight finish first. `admin export` must reproduce the file's
sha256.

**WL-8 Off-chain register.** The whitelist lives in MINT's backend, and no contract is deployed for it (MINT, 28 September
2026, `→ CQ-18`).
1. A holder signs in on getminted.io with Privy, or pastes a wallet address.
2. The page shows what the account has wagered and what is left to unlock the next spot.
3. The holder claims what is unlocked. A pasted address proves it belongs to the holder with a
   free wallet signature. A wallet connected through Privy has already done so.
4. The backend records the claim.

The backend's counter makes sure two claims at the same moment can't both take the last spot.

Choosing a wallet and each claim take a free signature from that wallet, so nobody can claim to a
wallet they don't control. Wagering figures are read from MINT's wager API on the server at every
view and again inside every claim; nothing the browser sends is trusted.

getminted.io is also a general whitelist checker. The register holds every whitelist spot, from
wagering and from every other channel, such as cross-community collaborations and giveaways, and
a wallet sees all of its spots, wagered or not. Spots from other channels do not count toward the
1,000 and come on top of the two wagering spots; together they are capped at 3,222 (MINT,
29 September 2026). The final list has one
row per wallet, with its total across all channels. The team's spots are
display-only: the checker shows them, but they are never exported, never count toward the 3,222,
and a team wallet can't receive wagering or other whitelist spots, because its team mints would
count against the same per-wallet limit (WL-4). MINT loads the other channels from a CSV. Nothing
about the whitelist is public until Studio's list is set, and after that Studio's list is its only
trace on-chain.

*Technical note.* The register is `apps/whitelist-api` with `packages/whitelist-core` in MINT's
repository, on Railway: the page at `nft.getminted.io` and the API at `mintabear-api.mint.io`,
live since 1 October 2026. The starting point for wagering is the lifetime figure at the
account's first login (`accounts.baseline_cents`), since MINT's wager API reports lifetime
figures only. Signatures are EIP-712, single-use and valid for 10 minutes; smart wallets are
checked through ERC-1271 and ERC-6492. A claim locks the pool's counter row.
<!-- openspec:end -->

## 5. Activation and burn route (ACT)


<!-- openspec:begin family ACT -->
Holders burn $MNTD to raise a bear's level, and with it the bear's share of the royalties. No key can fake a level, and every transfer resets it, so a level always proves a burn by the current owner.

**ACT-1 One token, one collection.** Activation works with one token, $MNTD, fixed when it is deployed, and one collection. It reads
who owns a bear and its transfer count. The collection never calls it, so a problem in
Activation can never block a transfer. Recording a burn and burning the tokens happen in one
transaction: if either fails, neither happens.

*Technical note.* `Activation` holds one token reference, $MNTD, fixed in its constructor, and
uses it for one thing: burning the caller's own $MNTD in `burn` (ACT-7). It records burned
amounts per bear and derives level and weight from them. It reads `MintABear` (`ownerOf`,
`transferNonce`, `exists`); `MintABear` never calls it. The record comes first: `Activation` adds
the amount to the bear, then burns it from the holder, and any revert undoes both.

*Acceptance.* When `Activation`'s code and constructor are inspected; then its only calls to $MNTD are `decimals` in the constructor and `burnFrom` of the caller's own balance in `burn`, and it moves no other token; and it reads only `MintABear`'s `ownerOf`, `transferNonce` and `exists`.

**ACT-2 Thresholds.** A bear's level comes from the total $MNTD burned for it: 1,666 for level 1, then 3,333, 8,333,
16,666 and 41,666 for level 5. The figures are totals, so level 5 costs 41,666 in all (MINT,
CQ-4). They are fixed at deployment.

| Level | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Total burned to reach it | 1,666 | 3,333 | 8,333 | 16,666 | 41,666 |

*Technical note.* Five cumulative thresholds `T1 < T2 < T3 < T4 < T5`, supplied to the
constructor in whole $MNTD and scaled there by the token's `decimals` into base units, which are
immutable; `DECIMALS` reads the value used. A bear's level is the highest `k` with
`cumulative ≥ Tk`, or 0. `thresholdFor(level)` and `costToReach(tokenId, level)` expose them in
base units.

*Acceptance.* Given the thresholds 1,666 / 3,333 / 8,333 / 16,666 / 41,666 whole $MNTD and a token with 18 decimals; when a bear's cumulative reaches 8,333 $MNTD; then `levelOf` reads 3 and `costToReach(id, 4)` reads 8,333 × 10^18.

**ACT-3 Weights.** Each level has a royalty weight: 1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00 for levels 0–5 (MINT,
CQ-5), fixed at deployment. A level-5 bear earns twice a level-0 bear's share.

*Technical note.* Basis 100: `100 / 110 / 125 / 145 / 170 / 200`, supplied to the constructor and
immutable. `weightFor(level)` returns the table entry; `weightOf(tokenId)` returns the weight of
the bear's current level.

*Acceptance.* Given the weights 100 / 110 / 125 / 145 / 170 / 200; when a bear at level 3 is read; then `weightOf` returns 145 and `weightFor(5)` returns 200.

**ACT-4 Burn record.** Only a bear's current owner can burn for it. The burn is refused while burning is paused, for a
zero amount, for a bear already at level 5, and for more than level 5 needs (ACT-8). A successful
burn records the amount against the bear and publishes it (ACT-13). A burn can never land on a
bear its burner doesn't hold.

*Technical note.* `burn(uint256 tokenId, uint128 amount)` reverts unless: not paused
(`ContractPaused`); `amount > 0` (`ZeroAmount`); `ownerOf(tokenId) == msg.sender`
(`NotBearOwner`); the bear is below level 5 (`AlreadyAtMaxLevel`); `amount ≤ costToReach(tokenId,
5)` (`Overshoot`, ACT-8). Effects, in order: the cumulative for the bear's current counter value
increases by `amount`; `lifetimeBurned` increases by `amount`; `BearActivated(tokenId, burner,
previousLevel, newLevel, amount, cumulative)` is emitted; then `MNTD.burnFrom(msg.sender, amount)`.
The owner check and the counter are read in the same call as the record. `burn` is
non-reentrant: a call made from inside the token's `burnFrom` is refused.

*Acceptance.* Given the owner of a bear below level 5 who has approved `Activation` on $MNTD; when the owner calls `burn(tokenId, amount)`; then the cumulative and `lifetimeBurned` grow by `amount`, `BearActivated` is emitted and the owner's $MNTD falls by `amount`; and a `burn` made from inside the token's `burnFrom` reverts.

**ACT-5 Reset.** When a bear changes hands, its level and burned total read zero and its weight reads the level-0
weight (ACT-3), including when it returns to a previous owner. The reset follows from the
transfer itself (COL-3), so it can't be skipped and can't block a transfer.

*Technical note.* Cumulative and level read as zero whenever the counter value they were recorded
at differs from the current `transferNonce`; nothing is written on transfer.

*Acceptance.* Given a bear at level 2; when it is transferred to another wallet; then `levelOf` and `cumulativeOf` read zero and `weightOf` reads `weightFor(0)`, with no call into `Activation`.

**ACT-6 Lifetime.** Separately, every bear keeps a lifetime total of everything ever burned for it, which never
resets.

*Technical note.* `lifetimeBurned(tokenId)` accumulates every burn ever recorded for a bear.

*Acceptance.* Given a bear burned for twice with a transfer in between; when `lifetimeBurned` is read; then it is the sum of both burns.

**ACT-7 Burn route.** $MNTD is native to Robinhood Chain, so a burn removes supply outright (MINT, CQ-2). The holder
approves Activation on $MNTD once, then burns in one click. The token's address is fixed when
Activation is deployed, so a different address means a new Activation. No bridge, other chain or
cross-chain messaging is involved. MINT's staking sits beside the token and touches nothing here
(`→ CQ-2`).

*Technical note.* `Activation` takes the token's address as an immutable constructor argument.
`burn(tokenId, amount)` (ACT-4) records the burn and calls `MNTD.burnFrom(msg.sender, amount)` in
the same transaction. Requirements on $MNTD: an ERC-20 on 4663 exposing `decimals()` and
`burnFrom(address, uint256)` (OpenZeppelin `ERC20Burnable`, as the reference token) that reverts
rather than returning false on failure. A bridged or mint-and-burn representation, and a burn on
another chain with an attested record on 4663, are out.

*Acceptance.* Given the holder has approved `Activation` on $MNTD; when the holder calls `burn(tokenId, amount)` for a bear below level 5; then the burn is recorded and `burnFrom` executes in one transaction, and `BearActivated` is emitted; and a call by a non-owner reverts with `NotBearOwner`.

**ACT-8 Overshoot.** A burn above what level 5 still needs is refused, so no $MNTD is destroyed for nothing. The page
sizes each burn to the exact amount for the target level.

*Technical note.* `burn` reverts with `Overshoot` above `costToReach(tokenId, 5)`; the portal
sizes each burn with `costToReach(tokenId, targetLevel)`, which returns the exact remainder or
zero.

*Acceptance.* Given a bear whose `costToReach(id, 5)` reads x; when the holder calls `burn(id, x + 1)`; then it reverts with `Overshoot` and no $MNTD is burned.

**ACT-10 Snapshot view.** At each royalty closing, MINT's split counts every owned bear: a wallet's weight is the sum over
its bears, and bears held by the dead address are left out (COL-8). The total is taken off-chain,
because transfers reset weights without any call to Activation. Calea's reference script
reproduces the split from an archive node, refuses inputs that miss a bear, and its shares plus
the rounding carried forward equal the funding. MINT credits the shares to getminted.io accounts
(§2).

*Technical note.* `snapshot(uint256[] ids) → (address owner, uint8 level, uint16 weight)[]`,
returning zeroes for ids that do not exist. The split counts every bear with an owner among ids
`1..4444`, excluding the canonical dead address
`0x000000000000000000000000000000000000dEaD`. The reference script (DEL-6) reads the inputs at the
closing block in either of two ways that agree: owners from the collection's `Transfer` events
and weights from `weightOf`, for owned ids only, since `weightOf` answers the level-0 weight for
an id never minted; or `snapshot`, paged by a gas budget. Each id's owner lookup walks back to the
start of its mint batch, so one call over the whole range is not dependable (56.2M gas at two
bears per wallet).

*Acceptance.* When `snapshot([1, 2, 4445])` is read; then it returns owner, level and weight for ids 1 and 2 and zeroes for the id that does not exist.

**ACT-15 Pause.** MINT's admin can pause burning, and only burning: reads and transfers carry on. Activation is
deployed paused and opens on 29 October (§8). The pause has no exemptions, so the mainnet
rehearsal runs in a window the admin opens and closes again. Ownership can't be given up, so the
pause can always be set and lifted.

*Technical note.* `paused` is true from construction. `setPaused(bool)`, owner-only; while paused
`burn` reverts with `ContractPaused`. `renounceOwnership` reverts for every caller.

*Acceptance.* Given the owner has paused; when a holder calls `burn`; then it reverts with `ContractPaused`; and reads and every transfer still succeed.

**ACT-12 Roles.** MINT's admin can only pause and hand over ownership. A bear's owner can burn for it. Nothing else
can be changed: the token, thresholds, weights and records are fixed, and no one can record a
level without a burn. Ownership moves only to an address that has asked for it, so it can never
reach an address nobody controls. There is no freeze or clawback (MINT, CQ-16). Which bear carries an
account's Status boost is MINT's, kept off-chain against the holder's Privy account (MINT, CQ-21).

*Technical note.* Owner (MINT's admin, the constructor's `owner`; zero is refused with
`NewOwnerIsZeroAddress`): `setPaused` and the two-step handover — the new owner calls
`requestOwnershipHandover()`, then the owner calls `completeOwnershipHandover(newOwner)` within 48
hours. `transferOwnership` reverts with `TwoStepHandoverOnly` and `renounceOwnership` with
`RenounceDisabled`, for every caller. A bear's owner: `burn` for that bear. The external interface is pinned by the ACT-12
test: a function added fails the suite until the specification allows it.

*Acceptance.* When a non-owner calls `setPaused`, or anyone calls `renounceOwnership` or `transferOwnership`; then it reverts; and no function anywhere changes the token, thresholds, weights or a bear's record other than its owner's `burn`.

**ACT-13 Events.** Every burn publishes the bear, the burner, the old and new level, the amount and the new total.
Every pause change is published.

*Technical note.* `BearActivated(tokenId, burner, previousLevel, newLevel, amount, cumulative)`
(ACT-4) and `PausedSet(paused)`.

*Acceptance.* When a burn and a pause happen; then `BearActivated` and `PausedSet` are emitted with the documented arguments.

**ACT-14 Reads.** The page can read for free: a bear's level, burned total, lifetime total and weight; the weights
and thresholds; the cost to reach a level; the snapshot; and whether burning is paused.

*Technical note.* `levelOf`, `cumulativeOf`, `lifetimeBurned`, `weightOf`, `weightFor`,
`thresholdFor`, `costToReach`, `snapshot`, `paused`, `BEARS`, `MNTD`, `DECIMALS`.

*Acceptance.* When every listed read is called for a bear that has been burned for; then each returns without reverting; and `BEARS` and `MNTD` return the deployed addresses and `DECIMALS` the token's decimals.
<!-- openspec:end -->

## 6. Mystery box (RAF)


<!-- openspec:begin family RAF -->
A holder opens a mystery box with a bear they own and learns the outcome on the spot. The box runs in cycles MINT schedules: in each cycle every bear, the team's included, gets one shot, and the next cycle gives every bear a new one, whoever holds it. `MysteryBox` on Robinhood Chain runs the cycles and records openings. `PrizeDraw` on Arbitrum One decides each opening and records wins and payouts.

**RAF-32 Cycles.** MINT's admin schedules each cycle before it starts: its window, its number of prizes, and a
fingerprint of the prize list MINT publishes (RAF-27) (MINT, CQ-9, CQ-20). A cycle can't be
scheduled while one is open, start in the past, or start before the previous one ends. A cycle
lasts at most 90 days, so a mistyped end date can't hold the game in one cycle for longer. A
scheduled cycle can be replaced until it starts; from then on its terms are fixed, on both
chains. Boxes open only inside the window, and an opening made inside it is decided even if the
answer arrives after the window ends (RAF-29). Prizes a cycle doesn't award, and prizes not
claimed in time, stay in the prize vault (RAF-35, RAF-37) for a later cycle. MINT decides when
the next cycle starts, so the game can rest between cycles for as long as MINT needs. The draw
and every prize vault are given the same terms, and each chain publishes them, so anyone can
check they match.

*Technical note.* `scheduleCycle(start, end, prizeCount, manifestHash)` on `MysteryBox` records
the next cycle. It is refused while a cycle is open (`CycleInProgress`); for a window that starts
in the past, starts before the previous cycle ends, ends before it starts, or has `end - start`
above `MAX_CYCLE_LENGTH`, 90 days (`InvalidWindow`); and for a prize count of zero or above
`PLAYABLE` (`InvalidPrizeCount`). A cycle is open from `start` to `end` inclusive. `PrizeDraw`
carries each cycle's `start`, `prizeCount` and `manifestHash`, set by the owner with
`scheduleCycle(cycleId, start, prizeCount, manifestHash)`, and refuses to replace them once
`start` has passed or the cycle has accepted a relay (`CycleStarted`). Each `PrizeVault` carries
the cycle's `start`, `end` and full prize list (RAF-35). All three emit their cycle's terms.

*Acceptance.* Given the owner has scheduled cycle 1 from `start` to `end` with 5 prizes; when a holder opens a box before `start`, between `start` and `end`, and after `end`; then only the open between `start` and `end` succeeds, and the others revert with `CycleNotOpen`; and scheduling cycle 2 while cycle 1 is open reverts with `CycleInProgress`.

**RAF-27 Every bear plays, and the prize pool.** Every one of the 4,444 bears plays, the team's 222 included, and a team bear can win like any
other (MINT, 12 October 2026, CQ-20). No bear is ever left out. A cycle's odds depend on two
numbers: the 4,444 bears and the cycle's number of prizes. Before each cycle MINT publishes
its prize list: each prize's chain, token and id or amount, in order. The n-th prize won in a
cycle is entry n of the list. On Robinhood Chain and Arbitrum One only the count and the list's
fingerprint are on-chain. The prizes themselves are sent from MINT's prize wallet to the prize
vault on each prize chain, and each vault accepts the cycle's list only when it matches the
fingerprint and every prize on its chain is already held (RAF-35, CQ-22).

*Technical note.* `MysteryBox(owner, bears)` has no exclusion: `PLAYABLE` reads `MAX_BEARS`,
4,444, and `PrizeDraw` is deployed with `PLAYABLE` 4,444. The prize list's hash is the cycle's
`manifestHash` (RAF-32); `MysteryBox` and `PrizeDraw` cannot check it against a balance, and
`PrizeVault.registerCycle` does, refusing with `ManifestMismatch` or `Unfunded` (RAF-35).

*Acceptance.* Given a box deployed with no other call; when the owner schedules the first cycle; then `PLAYABLE` reads 4,444 on both chains, and the holder of bear 1, a team bear, can open it.

**RAF-28 Opening a box.** A bear's holder opens a box with it while a cycle is open, free apart from gas. The opening is
refused while the box is paused, outside a cycle, for anyone who doesn't hold the bear, and for a
bear already opened this cycle. Each bear has one shot per cycle (MINT,
CQ-9): an opened bear can still be sold, but nobody can open it again that cycle, its buyer
included. In the next cycle, whoever holds it can. The page shows a wallet's shots left: a holder
of ten bears who has opened two sees eight. The page counts them from each bear's own record; the
box itself keeps no count per wallet, and the count is for display only, since opening is what
enforces the rule.

*Technical note.* `open(uint256 tokenId)` on `MysteryBox`, by `ownerOf(tokenId)` at that moment.
It reverts with `ContractPaused`, `CycleNotOpen`, `NotBearOwner` or `AlreadyOpened`. Effects: the id is spent for the cycle (`opened(cycleId, tokenId)` reads true),
the next `openIndex` is assigned (one sequence across all cycles), and
`BoxOpened(openIndex, cycleId, tokenId, opener)` is emitted. Shots left are counted by the client
library: for each bear the page's indexer lists for the wallet, one Multicall3 call (deployed on
4663 and 46630) reads `ownerOf` and `opened(currentCycle, tokenId)`, and a bear counts when
the wallet holds it and it has not opened in the open cycle.
Because ownership is read on-chain, a stale list can leave out a bear just received but never
counts one sold.

*Acceptance.* Given an open cycle and a holder of a bear not yet opened in it; when the holder calls `open(tokenId)`; then `BoxOpened(openIndex, cycleId, tokenId, opener)` is emitted and `opened(cycleId, tokenId)` reads true; and the buyer of that bear cannot open it again in the same cycle, reverting with `AlreadyOpened`, and may open it in the next.

**RAF-29 Resolution, in order.** The worker carries each opening to the draw on Arbitrum One, which decides openings strictly in
the order they were made. It refuses one out of turn, so the worker can't choose which opening
meets which state of the prize pool. It can only delay one, and a delay is visible. Each opening
gets its own random number. Several can be in flight at once, but results are applied in order.
Each relay names the bear that opened, so every result can be matched to its opening on Robinhood
Chain, and the draw refuses a bear relayed twice in one cycle, a relay with no opener, and a relay
once a cycle's bears are all relayed. The worker relays an opening once Robinhood Chain's
sequencer has confirmed it. A random number is never lost to a failed delivery: the draw stores
each number as it arrives, and anyone can apply the stored numbers in order, so a cycle's last
results are recorded even when no further opening follows.

*Technical note.* `resolve(uint64 openIndex, uint64 cycleId, uint256 tokenId, address opener)` on
`PrizeDraw`, relayed from `BoxOpened`. It refuses any `openIndex` but the next unresolved one
(`OutOfOrder`); a cycle it has not been given or one earlier than the last it resolved
(`UnknownCycle`); a `tokenId` outside 1 to `MAX_BEARS` (`InvalidTokenId`); a zero `opener`
(`InvalidOpener`); a `tokenId` already resolved in that cycle (`AlreadyResolved`); and any resolve
once the cycle has accepted `PLAYABLE` relays (`CycleExhausted`). It requests one Chainlink word
and emits `DrawRequested(openIndex, requestId)`. The VRF callback stores the word for its
`openIndex` and never reverts for a request the draw made; outcomes are applied in `openIndex`
order, so an open waits only on the words of the opens before it. The callback applies pending
outcomes within the gas it has, `resolve` applies at most `RESOLVE_APPLY_LIMIT` (16), and
`applyOutcomes(maxCount)`, open to anyone, applies up to `maxCount` more; none of them can change
an outcome, only when it is recorded. `applyOutcomes` reverts with `InsufficientGas` when it stops
for gas with fewer than `maxCount` applied and the next opening's word stored, so a wallet's gas
estimate applies every ready outcome up to `maxCount`; the callback and `resolve` stop quietly
instead. A delayed open shows as a `BoxOpened` with no `OutcomeRecorded`; a relayed open that
matches no `BoxOpened` on 4663 is visible the same way. An open made before its cycle's `end` is
resolved even if the word arrives after it.

*Acceptance.* Given opens 1 and 2 recorded and neither resolved; when the worker calls `resolve(2, cycleId, tokenId, opener)`; then it reverts with `OutOfOrder`; and `resolve(1, cycleId, tokenId, opener)` requests one Chainlink word and emits `DrawRequested`.

**RAF-30 The win rule (normative).** Each cycle is a fixed pool drawn without replacement. At every opening, the chance of winning is
the prizes left divided by the playable bears not yet decided. The consequences:
- every holder faces the same odds before opening;
- a cycle in which every playable bear is opened awards exactly its prize count;
- a cycle that ends with bears unopened awards fewer, and the rest stay in MINT's wallet (RAF-32,
  MINT, CQ-9);
- a wallet's chances grow with the playable bears it holds, and one shot per bear per cycle is
  the only cap (MINT, CQ-9).

Which bear opened has no bearing on the outcome.

*Technical note.* Within a cycle, `idsLeft` starts at `PLAYABLE` and `prizesLeft` at the cycle's
prize count. On the word `w` for `openIndex i`: `won = (w mod idsLeft) < prizesLeft`; if `won`,
the next unawarded entry of the cycle's prize list is assigned to `i`'s opener and `prizesLeft`
decreases by one; `idsLeft` decreases by one either way;
`OutcomeRecorded(openIndex, cycleId, tokenId, opener, won, prizeIndex)` is emitted, where
`prizeIndex` is the entry of the list and carries no meaning when `won` is false. The rule reads
`w`, `idsLeft` and `prizesLeft` only, never `tokenId` or `opener`. The odds before an open are
`prizesLeft / idsLeft`.

*Acceptance.* Given a cycle with `idsLeft` at 10, `prizesLeft` at 2 and a word w with `w mod 10 == 1`; when the open is resolved; then `won` is true, the next entry of the cycle's prize list is assigned, `prizesLeft` reads 1 and `idsLeft` reads 9.

**RAF-8 Randomness.** Each opening gets its own random number from Chainlink on Arbitrum One (agreed 28 September
2026). One number per opening is what makes an outcome nobody can predict, MINT included.
Robinhood Chain has no Chainlink and no usable randomness of its own, which is why the draw runs
on Arbitrum. Calea holds and funds the subscription that pays for the numbers, and invoices MINT
(MINT, 12 October 2026, CQ-17). It is funded for a cycle's worth, at most 4,444 numbers, and topped up when its balance runs low.
Each opening is asked for once and never again: asking again would let whoever delivers the
numbers keep a losing one back and deliver a winning one instead. A request left unanswered
because the subscription ran low is answered once it is topped up. The subscription's holder can stop the
numbers by not funding it or by removing the draw, but can't choose an outcome. It can be handed to
MINT later with its number unchanged, so the draw keeps running. If the draw ever has to move to
another coordinator or subscription, a new draw takes over at the next opening.

*Technical note.* Chainlink VRF v2.5, one request and one word per open, never re-requested.
`PrizeDraw` on Arbitrum One (42161) uses coordinator `0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e`,
and on Arbitrum Sepolia (421614) `0x5CE8D5A2BC84beb22a398CCA51996F7930313D61`; it is the
subscription's consumer. The subscription is funded for at most `PLAYABLE` requests per cycle and
topped up on a balance alarm, not on a schedule. The subscription's owner is a Calea
wallet on Arbitrum One; the coordinator's `requestSubscriptionOwnerTransfer` and
`acceptSubscriptionOwnerTransfer` move it to MINT keeping `SUBSCRIPTION_ID`, which `PrizeDraw`
fixes at construction. Robinhood Chain's `prevrandao` is constant. The
constructor takes `firstOpenIndex`, the first opening the draw relays (1 for the first draw; for a
replacement, the next unresolved opening), and both `nextToResolve` and `nextToApply` start there.

*Acceptance.* When `resolve` runs; then exactly one VRF v2.5 request is made from the subscription with `PrizeDraw` as consumer; and the outcome uses that request's word alone.

**RAF-33 Prize custody and the payout record.** Each cycle's prizes are held by the prize vault on their chain (RAF-35), funded from MINT's prize
wallet `0xf6c0…83e3` on Robinhood Chain, Ethereum and ApeChain, and Base when a later cycle uses
it (MINT, CQ-8, CQ-20, CQ-22). A winner claims the prize from the vault (RAF-36); the vault
releases each prize once, only to the winner, and only within the claim window. Whatever is not
reserved for a claim stays MINT's to withdraw (RAF-37). What the chain guarantees beyond the
vault is the record. The worker records each claim on the draw contract, once and only for a
win, so anyone can match a win to its claim and see a win that was never paid. The winner is
whoever opened the box, and there is no way to name another recipient.

*Technical note.* The prize wallet is `0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3`, an externally
owned account, and the funding transfers are sent from it on MINT's admin page (DEL-6). After a
vault's `PrizeClaimed`, the worker calls `recordPayout(openIndex, chainId, txHash)` on
`PrizeDraw` with the claim's transaction, refused unless the outcome of `openIndex` is a win
(`NotAWin`) not yet recorded as paid (`AlreadyPaid`), and refused for a zero `chainId` or
`txHash` (`InvalidPayout`), which would close the win with no evidence; it emits
`PrizePaid(cycleId, openIndex, chainId, txHash)`, and `payoutOf(openIndex)` reads the record.
`chainId` is the prize's chain (1 Ethereum, 4663 Robinhood Chain, 33139 ApeChain, 8453 Base);
the draw accepts any non-zero id, so no chain list is fixed in code.

*Acceptance.* Given open 7 recorded as a win; when the worker calls `recordPayout(7, 1, txHash)`; then `PrizePaid(cycleId, 7, 1, txHash)` is emitted; and a second `recordPayout` for open 7 reverts with `AlreadyPaid`, and one for an open that did not win reverts with `NotAWin`.

**RAF-14 Roles.** **MINT's admin** schedules cycles, registers each cycle's prizes on the vaults, withdraws what
is not reserved, sets the worker and the vaults' signer, and pauses any contract. Ownership
can't be given up. **The worker** carries openings to the draw, signs each winner's claim ticket
and records payouts; MINT runs it (CQ-23). **A winner** claims their own prize. **Anyone** can
open a box with a bear they hold, apply outcomes whose random numbers have arrived, release a
closed cycle's reservations, and read everything. No role can open a box for a holder, change
an outcome, move a bear, or send a reserved prize anywhere but to its winner.

*Technical note.* Owner: on `MysteryBox` `scheduleCycle`, `setPaused`; on
`PrizeDraw` `scheduleCycle`, `setWorker`, `setPaused`; on `PrizeVault` `registerCycle`,
`withdraw`, `setSigner`, `setPaused`. Ownership moves on all three only by Solady's
two-step handover: the new owner's `requestOwnershipHandover`, then the owner's
`completeOwnershipHandover` within 48 hours; `transferOwnership` reverts with
`TwoStepHandoverOnly` and `renounceOwnership` with `RenounceDisabled`. Worker: `resolve` and
`recordPayout` on `PrizeDraw`, and the vaults' `signer`. Winner: `claim` on `PrizeVault`.
Anyone: `open` on `MysteryBox`, `applyOutcomes` on `PrizeDraw`, `release` on `PrizeVault`. The
VRF coordinator alone delivers words.

*Acceptance.* When a non-owner calls `scheduleCycle` or `setWorker`, or a non-worker calls `resolve` or `recordPayout`; then each reverts; and `open` needs no role but the bear's ownership.

**RAF-34 Pause.** Pausing the mystery box stops new openings. Pausing the draw stops new random numbers being
requested, while numbers already requested are still applied. Pausing a prize vault stops
claims, for instance while a suspected key leak is handled. No pause stops payout records,
reads, registration or withdrawal, and no pause extends a cycle or a claim window; it only
shortens the time holders have.

*Technical note.* Pausing the hub blocks `open`; pausing `PrizeDraw` blocks `resolve`; pausing
`PrizeVault` blocks `claim`. None blocks `recordPayout`, `registerCycle`, `withdraw`, `release`
or any read, and no pause moves `end` or `end + CLAIM_GRACE`.

*Acceptance.* Given the hub and the draw each paused; when `open` and `resolve` are called; then each reverts with `ContractPaused`; and `recordPayout` and every read still succeed.

**RAF-16 Events.** The contracts publish every step: each cycle's terms on every chain,
every opening, every request for a random number, every outcome with the bear that opened, every
claim, every payout, every release and withdrawal from a vault, and every change of worker,
signer or pause.

*Technical note.* Hub: `CycleScheduled(cycleId, start, end, prizeCount,
manifestHash)`, `BoxOpened(openIndex, cycleId, tokenId, opener)`, `PausedSet`. `PrizeDraw`:
`CycleScheduled(cycleId, start, prizeCount, manifestHash)`, `DrawRequested(openIndex, requestId)`,
`OutcomeRecorded(openIndex, cycleId, tokenId, opener, won, prizeIndex)`, `PrizePaid(cycleId,
openIndex, chainId, txHash)`, `WorkerSet`, `PausedSet`. `PrizeVault`: `CycleRegistered(cycleId,
start, end, manifestHash)`, `PrizeClaimed(cycleId, openIndex, prizeIndex, winner)`,
`Released(cycleId)`, `Withdrawn(kind, token, id, amount, to)`, `SignerSet(signer)`, `PausedSet`.

*Acceptance.* When a cycle runs through scheduling, an open, a resolution and a payout record; then every listed event fires with the documented arguments.

**RAF-17 Reads.** The page can read for free: the playable count, whether a bear has opened this cycle, the current cycle and its terms, the longest a cycle may last, the live odds, each
opening's bear, outcome and payout, and on each prize vault the cycle's prizes, which are
claimed, the claim deadline and what is reserved. A wallet's shots left come from these reads,
one per bear (RAF-28).

*Technical note.* Hub: `MAX_BEARS`, `PLAYABLE`, `MAX_CYCLE_LENGTH`, `currentCycle()` and each cycle's
`(start, end, prizeCount, manifestHash)`, `isOpen()`, `opened(cycleId, tokenId)`, `openCount()`,
`paused()`, `BEARS`, `owner()` and `ownershipHandoverExpiresAt(pendingOwner)`. `PrizeDraw`:
`MAX_BEARS`, `PLAYABLE`, each cycle's `(prizeCount, manifestHash, idsLeft, prizesLeft)`,
`nextToResolve()`, `nextToApply()`, `lastCycleResolved()`, `outcomeOf(openIndex)` with its
`tokenId`, `payoutOf(openIndex)`, `odds(cycleId)` returning `(prizesLeft, idsLeft)`,
`openingOfRequest(requestId)` (0 for a request the draw never made), `RESOLVE_APPLY_LIMIT`,
`worker()`, `paused()`, the Chainlink configuration `COORDINATOR`, `KEY_HASH`, `SUBSCRIPTION_ID`,
`CALLBACK_GAS_LIMIT`, `REQUEST_CONFIRMATIONS` and `NATIVE_PAYMENT`, `owner()` and
`ownershipHandoverExpiresAt(pendingOwner)`. `PrizeVault`: `MAX_PRIZES`, `CLAIM_GRACE`, each
cycle's `(start, end, manifestHash, prizeCount)`, `prizeOf(cycleId, prizeIndex)`,
`claimed(cycleId, prizeIndex)`, `claimDeadline(cycleId)`, `reserved(kind, token, id)`,
`released(cycleId)`, `signer()`, `paused()`, `eip712Domain()` (ERC-5267: the ticket's domain, from which the worker and
wallets build its typed data), `owner()` and `ownershipHandoverExpiresAt(pendingOwner)`. No other public
read exists on any of them. Each read costs a fixed amount, whatever the number of bears.

*Acceptance.* When every listed read is called during an open cycle; then each returns without reverting and `odds(cycleId)` returns `(prizesLeft, idsLeft)`.

**RAF-18 Worker sequence.** A cycle runs in this order:
1. For each cycle, MINT publishes the prize list. On MINT's admin page it sends the prizes from
   the prize wallet to the vault on each prize chain, registers the list on every vault, and
   schedules the cycle on both game chains, all with the same fingerprint.
2. Holders open boxes inside the window.
3. The worker carries each opening to the draw, in order.
4. Random numbers arrive and outcomes are recorded.
5. For each win the worker signs a claim ticket and serves it to the page; the winner claims on
   the prize's chain until one hour after the cycle's end (CQ-22), and the worker records
   each claim on the draw.
6. After the window, unclaimed prizes are released for a later cycle, and MINT schedules the
   next cycle whenever it is ready.

MINT's page shows the cycle's window, its prize list, the live odds, a wallet's shots left, its
outcomes, its tickets with the claim button and deadline, and its payouts.

The worker is a service Calea builds and MINT runs on its own infrastructure (MINT, 12 October
2026, CQ-23), with Calea's instructions: how to create its wallet, fund it and start it. MINT
creates the worker's key, which Calea never sees, and MINT's admin authorises its address on the
draw and as the vaults' signer. The wallet holds only ETH on Arbitrum One for gas. The worker
keeps no state of its own: on every start it reads from every chain where it stands, so a
restart or a redeploy can't skip or repeat an opening, a ticket or a record. It raises an alarm
when its gas runs low and when an opening waits too long for its outcome.

*Technical note.* A service in MINT's repository (`apps/box-worker`), packaged like the whitelist
API: a Dockerfile, Railway configuration and a health check. It reads `BoxOpened` on Robinhood
Chain and `nextToResolve`, `nextToApply` and `openCount` on both game chains, and calls `resolve`,
`applyOutcomes` and `recordPayout` on `PrizeDraw` through the client library (DEL-6). For each
`OutcomeRecorded` that won, it signs the EIP-712 ticket of RAF-36 and serves it at
`GET /tickets/:openIndex` and by wallet; it watches each vault's `PrizeClaimed` and records the
claim's transaction with `recordPayout`. The key is a secret in MINT's Railway project; MINT's
admin sets the address with `setWorker` and each vault's `setSigner`. Its gas per relay is
measured on Arbitrum Sepolia in the rehearsal (OPS-4).

*Acceptance.* When the sequence runs on the testnets through two cycles, from funding and scheduling to the payout records; then each step succeeds in the listed order, a relay offered out of turn is refused, each win is claimed from its vault with the worker's ticket and recorded, and a bear opened in cycle 1 opens again in cycle 2.

**RAF-19 Acceptance cases.** Each of these has a test:
- every bear can be opened by its holder, a team bear included;
- a box cannot be opened outside its cycle's window;
- a bear cannot be opened twice in one cycle, by its holder or its buyer, and can be opened in
  the next;
- a cycle cannot be scheduled while one is open, and a scheduled cycle's terms cannot change
  once it has started, on either chain;
- a relay out of order is refused;
- a bear relayed twice in one cycle is refused by the draw, and so is a relay once the cycle's
  bears are all decided;
- an opening is asked for once, and the first word delivered for it is the one used;
- a cycle in which every playable bear is opened awards exactly its prize count, and the pool
  neither empties early nor is left over;
- a cycle that ends early awards no more than its prize count;
- a win is recorded as paid once, and a loss cannot be;
- a holder who sells a bear after opening it keeps its outcome.

*Acceptance.* When the tranche-2 test suite runs; then every listed case has a passing deterministic test.

**RAF-35 Prize vault and the cycle's prize list.** Each cycle's prizes are held by a prize vault on the prize's chain: Robinhood Chain, Ethereum
and ApeChain, and Base when a cycle first uses it (MINT, 15 October 2026, CQ-22). The vault has
the same address on every chain and is owned by MINT's admin. It holds every kind of prize:
native coins (ETH, APE), tokens (ERC-20) and NFTs (ERC-721, ERC-1155). During cycle setup, MINT's
admin page sends the cycle's prizes from the prize wallet to the vault on each chain, then MINT's
admin registers the cycle's full prize list on every vault. The vault accepts the list only if
it is the list the cycle's fingerprint names and if it already holds every prize on its own
chain, so a published prize is provably there from the start. It also refuses a list that could
make a reservation disagree with what it can pay: a cycle longer than the box allows, an entry
that names nothing or says more than it reserves, and a token listed as two kinds of prize at
once. The list can be replaced until the cycle starts. From registration until the claim window
closes (RAF-36), the cycle's prizes on that chain are reserved for their winners.

*Technical note.* `PrizeVault(owner, signer)` in `packages/contracts`, deployed through the
CREATE2 deployer `0x4e59…956C` with the same arguments on every chain, so its address is the
same. A prize is `(chainId, kind, token, id, amount)` with kind native, ERC-20, ERC-721 or
ERC-1155; the list's fingerprint is `keccak256(abi.encode(prizes))` over the full ordered list,
the cycle's `manifestHash` on `MysteryBox` and `PrizeDraw` (RAF-32). Prize n of the list is the
draw's `prizeIndex` n (RAF-27, RAF-30). The owner's `registerCycle(cycleId, start, end, prizes,
manifestHash)` is refused when the list hashes to another value (`ManifestMismatch`), is empty
or longer than `MAX_PRIZES` (`InvalidPrizeCount`), has `end` before `start` or lasts longer than
90 days, the box's `MAX_CYCLE_LENGTH` (`InvalidWindow`), has an entry with an amount of 0, a
native entry naming a token or an id, an ERC-20 entry naming an id, or an ERC-721 entry whose
amount is not 1 (`InvalidPrize`), has an own-chain entry for a token the vault's reservations
already hold under another kind (`KindMismatch`), or the vault holds less of an entry for its
own chain than what is already reserved plus the entry (`Unfunded`), and once `start` has passed
(`CycleStarted`). It reserves each own-chain entry. A token's kind is held while any of its
entries is reserved, so it can be listed as another kind once its reservations are lifted. The
vault receives native coins, ERC-20 transfers and safe ERC-721 and ERC-1155 transfers.

*Acceptance.* Given a vault on chain 1 holding prize 2 of a cycle's list, an ERC-721, and not prize 4, an ERC-20 amount on chain 1; when the owner registers the list, then sends prize 4 and registers it again, and once more with an entry changed; then the first registration reverts with `Unfunded`, the second succeeds and reserves prizes 2 and 4, and the changed list reverts with `ManifestMismatch`.

**RAF-36 Claiming a prize.** A winner claims their prize on the prize's chain, paying gas there, with a ticket the worker
signs once the draw has recorded the win. MINT has stated that a winner needs gas on every
prize chain to claim. The ticket names the cycle, the opening, the prize and the winner: the
address that opened the box. Only that address can claim, the prize goes only to it, and each
prize is released once. The claim opens with the cycle and stays open until one hour after the
cycle's end, on the vault's own chain clock. Every recipient is treated alike: a smart-contract wallet that does not exist
on a prize chain cannot claim there, and that prize carries over (RAF-37).

*Technical note.* The ticket is an EIP-712 message `Claim(cycleId, openIndex, prizeIndex,
winner)` in the domain of the vault's chain and address, signed by the vault's `signer`, which is
the worker's address (CQ-23). `claim(cycleId, openIndex, prizeIndex, signature)` from
`msg.sender` = the winner is refused when paused (`ContractPaused`), for an unregistered cycle
(`UnknownCycle`), before the cycle's `start` or after `end + CLAIM_GRACE`, one hour
(`ClaimClosed`), for an entry on another chain or a `prizeIndex` outside the list (`WrongChain`), for a signature that does not recover to `signer` over the sender
(`InvalidTicket`), and for a prize already claimed (`AlreadyClaimed`). It transfers the prize to
the winner (native by value, ERC-20 by a safe transfer, ERC-721 and ERC-1155 by a safe transfer,
so a contract that cannot receive refuses it), lifts its reservation, and emits
`PrizeClaimed(cycleId, openIndex, prizeIndex, winner)`. It is non-reentrant.

*Acceptance.* Given cycle 1 registered with prize 1 on this chain, opening 7 won prize 1 for Alice, and the worker's ticket for it; when Bob sends Alice's ticket, then Alice claims, then Alice claims again, and Carol claims with her own winning ticket after `end` plus one hour; then Bob's claim reverts with `InvalidTicket`, Alice receives prize 1 and `PrizeClaimed` is emitted, her second claim reverts with `AlreadyClaimed`, and Carol's reverts with `ClaimClosed`.

**RAF-37 Carry-over and withdrawal.** A prize not claimed by the time the window closes stays in the vault, no longer reserved, and
MINT can put it in a later cycle's prize list. A prize decided after the window closed carries
over the same way. MINT's admin can withdraw anything the vault holds that is not reserved for
an open claim window, at any time, and never a reserved prize.

*Technical note.* Once `end + CLAIM_GRACE` has passed, anyone's `release(cycleId)` lifts the
reservations of the cycle's entries on this chain that are not claimed, and the counts of their
tokens, and emits `Released(cycleId)`. It runs whatever the pause, and is refused for a cycle with
no list (`UnknownCycle`), while the claim window is open, its last second included, since `claim`
accepts that second (`ClaimWindowOpen`), and for a cycle already released (`AlreadyReleased`).
`registerCycle` and `withdraw` count only what is still reserved. The owner's
`withdraw(kind, token, id, amount, to)` pays `to` by the asset's own transfer and emits
`Withdrawn(kind, token, id, amount, to)`. It is refused for an asset named as registration
refuses an entry (`InvalidPrize`), for a kind other than the one its token is reserved under
(`KindMismatch`), when it would leave less than the reserved amount of that asset (`Reserved`),
and for a zero `to` (`ZeroAddress`). It is non-reentrant.

*Acceptance.* Given cycle 1's prize 3, an ERC-20 amount on this chain, unclaimed; when the owner withdraws it before the window closes, and after the window closes and `release(1)`; then the first withdrawal reverts with `Reserved`, and after the release the amount can be registered in cycle 2's list or withdrawn.
<!-- openspec:end -->

<!-- openspec:begin retired -->
**Retired identifiers.** ACT-9 (the on-chain Status link) → ACT-12; ACT-11 (pause over burns and links) → ACT-15; DEL-4 (verified testnet addresses) → OPS-3 and OPS-4; DEL-5 (deployment scripts and runbook) → OPS-2 and OPS-5; DEL-7 (the existing-contract review, withdrawn with CQ-13) → DEL-3; RAF-1 (a single raffle chain) → RAF-32 and RAF-33; RAF-7 (passive ownership snapshot) → RAF-28; RAF-9 (draw over calldata entries) → RAF-30; RAF-10 (carry forward between rounds) → RAF-32; RAF-12 (round cancellation) → RAF-32; RAF-13 (per-round `minLevel` eligibility) → RAF-27; RAF-20 (rounds on the hub) → RAF-32; RAF-21 (entry into a round) → RAF-28; RAF-22 (one seed per round) → RAF-29; RAF-23 (the per-round draw) → RAF-30; RAF-2 (vault addresses) → RAF-33; RAF-3 (asset approval on the vaults) → RAF-27 and RAF-33; RAF-4 (deposit intake) → RAF-33; RAF-5 (vault inventory states) → RAF-30 and RAF-33; RAF-6 (committing prizes from the vaults) → RAF-27 and RAF-32; RAF-11 (claims from a vault) → RAF-33; RAF-15 (pause with vault claims) → RAF-34; RAF-24 (a prize vault per chain) → RAF-33; RAF-25 (recipient nomination) → RAF-33; RAF-26 (one game over the collection) → RAF-32; RAF-31 (closing the game) → RAF-32 and RAF-33; WL-3 (the voucher registry `WhitelistClaim`) → WL-8; WL-6 (the off-chain register as an alternative) → WL-8; WL-7 (the owner-imported registry `WhitelistImport`) → WL-8.
<!-- openspec:end -->

## 7. Operations, roles and handover (OPS)


<!-- openspec:begin family OPS -->
MINT receives contracts that are correct from their first block, verified on every chain, and handed over with every key, role and a runbook. Running them after 19 November needs nothing from Calea.

**OPS-1 Addresses.** The keys and wallets the system uses are recorded before mainnet deployment; the royalty receiver
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

*Acceptance.* When the mainnet deploy scripts run; then the admin and worker addresses they read are the ones MINT recorded; and the royalty receiver is set in Studio before the first sale.

**OPS-2 Deployment order.** Every address a contract needs is given when it is deployed, so each contract is correct from its
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

*Acceptance.* When the deploy script runs on a fresh chain; then each contract is created with its constructor arguments in the listed order and is never left deployed-but-unconfigured; and no address is set after construction; every call after construction is a listed setting or ownership transfer, in the listed order.

**OPS-3 Verification.** Every contract's source is published and verified on Sourcify: on Robinhood Chain and its
testnet, and on Arbitrum One and Arbitrum Sepolia. Each prize vault is verified on its chain too,
on Sourcify where the chain is supported and on the chain's explorer otherwise.

*Technical note.* Sourcify for 4663 and 46630, because mainnet Blockscout's API sits behind a bot
challenge, and for 42161 and 421614, where Arbiscan shows a Sourcify-verified source; one route
needs no explorer API key (the person's choice, 16 October 2026). `PrizeVault` on 1, 33139 and
8453 and on their testnets (11155111, 33111, 84532) through Sourcify, or Etherscan's API for the
chain's explorer.

*Acceptance.* When a contract is deployed on 4663 or 46630; then its source is verified through Sourcify and readable there.

**OPS-4 Rehearsal on testnets (46630, Arbitrum Sepolia, Sepolia).** Before mainnet, everything on-chain is rehearsed on the testnets:
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

*Acceptance.* When the rehearsal runs on 46630, Arbitrum Sepolia and Sepolia; then each listed path completes end to end, including one open that wins and one that does not.

**OPS-5 Handover.** Calea deploys, configures, hands over ownership, verifies the source and delivers the runbook,
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

*Acceptance.* When handover completes; then every contract's owner is MINT's admin, every source is verified and the runbook is delivered; and Calea holds no owner key and no contract role; it holds the randomness subscription (CQ-17).

**OPS-6 Enforcement runbook.** Royalty enforcement is on from deployment. MINT's admin can tighten it later, and can switch it
off with one call and back on with one; every step is reversible. The strictest settings, which
would stop holders sending bears to contract wallets, are never used.

*Technical note.* Enabled at deployment: `MintABear.setTransferValidator(0x721C002B…)` with the
validator's zero-state policy. Optional, from the admin: `createList`, `addAccountsToWhitelist`,
`addAccountsToAuthorizers`, `applyListToCollection`, `setTransferSecurityLevelOfCollection`
(never level 5 or above). Disable: `setTransferValidator(address(0))`. Every step is an owner
call.

*Acceptance.* Given enforcement enabled; when the admin calls `setTransferValidator(address(0))` and then sets V3 again; then each call emits `TransferValidatorUpdated` and the policy follows the current value.

**OPS-7 Chain constraints.** Three facts about Robinhood Chain shape the design:
- it can block an individual holder's transactions (compliance screening), so nothing depends on
  a holder acting by a deadline except a prize claim: a box left unopened is just a shot not
  taken, and a prize not claimed within one hour of the cycle's end carries over to a later
  cycle (RAF-36, RAF-37);
- each transaction has a gas limit, so no call loops over the whole collection;
- there is no randomness on Robinhood Chain or ApeChain, so the draw runs on Arbitrum One.

*Technical note.* On Robinhood Chain `block.number` is the L1 height, so contracts and scripts key
on timestamps. The gas limit is Arbitrum-style, per transaction.
<!-- openspec:end -->

## 8. Calendar (CAL)

Four dates are fixed by MINT: TGE on 20 October, the whitelist frozen on 27 October at 12:00 UTC,
the mint on 29 October with the whitelist stage at 12:00 UTC, and burns open on 29 October.
OpenSea does not support Robinhood Chain's testnet, so Studio and the first sale are proven on
mainnet the week before the drop page. Every date marked *Calea* is Calea's working plan (CQ-1). The first mystery-box cycle is listed; later cycles are MINT's to
schedule.

| Date (2026) | What happens | Who | Basis |
|---|---|---|---|
| 30 Sep – 1 Oct | Internal audit of the collection and activation contracts | Calea | Calea |
| 12 Oct | Test $MNTD on the testnet, for the burn rehearsal: `0x15CF…211C`, the reference token's code | MINT (Lorenzo) | MINT |
| 30 Sep – 27 Oct 12:00 UTC | Whitelist campaign open on getminted.io/mintabear | Iñigo; Javier; Vlad; Lorenzo | MINT |
| 15 Oct | Work before deployment finished: the whitelist registries removed, the deploy configs for 46630 and 4663 | Calea | agreed |
| 16 Oct | Testnet rehearsal on 46630: the collection with royalty enforcement, the whitelist on SeaDrop, a burn against the test $MNTD | Calea | agreed |
| 19 Oct | Collection deployed on 4663 with royalty enforcement; the admin accepts ownership; Studio takes it over and Calea's check passes on a test list; the team's 222 minted | Calea; MINT's admin; Iñigo | agreed |
| 19 Oct | $MNTD deployed on Robinhood Chain; its address to Calea, which checks its code against the reference token | MINT | MINT |
| 20 Oct | TGE: $MNTD live on Robinhood Chain; Activation deployed against it, paused | MINT; Calea | MINT |
| 20 – 21 Oct | One team bear listed and sold on OpenSea from a second MINT wallet; Calea confirms it settled and the 5% reached the pot | MINT; Calea | agreed |
| 22 Oct | Go or no-go on royalty enforcement (OPS-6), then the drop page is published | MINT | agreed |
| 20 – 28 Oct | Real burns rehearsed on mainnet, in short windows the admin opens and closes | Calea; MINT | derived |
| 27 Oct, before 12:00 UTC | Every other channel's spots loaded into the register | MINT | agreed |
| 27 Oct 12:00 UTC | Register frozen and the final list exported by MINT's CTO; list and checksum to Iñigo and Calea by 14:00 UTC | MINT (CTO) | agreed |
| 27 Oct 14:00 – 29 Oct 12:00 UTC | List loaded into Studio and checked by Calea | Iñigo; Calea | MINT |
| 29 Oct | Mint on OpenSea's drop page: the whitelist stage first, from 12:00 UTC, then the other stages; burns and level-up open | Iñigo; Javier; Calea | MINT |
| 20 – 21 Oct | The client library joins MINT's workspace on staging (`release/1.1`), before the worker that uses it; production (`release/1.0`) unchanged until after the mint | Calea; MINT (Lorenzo) | agreed |
| 22 – 28 Oct | The worker built; the mystery box, draw and worker rehearsed on 46630 and Arbitrum Sepolia through two cycles | Calea | Calea |
| 29 – 31 Oct | Mystery box and draw deployed and verified; the draw added to Calea's randomness subscription; MINT authorises the worker; the first cycle's terms (end, prize count, prize list) set by MINT's admin by 31 Oct, then scheduled on both chains and read back | Calea; MINT | Calea |
| 4 Nov | First mystery-box cycle opens | MINT | MINT |
| 5 Nov | First royalty split; after that at each ETH cap or countdown (§2) | MINT | MINT |
| 19 Nov | Handover; technical support ends (OPS-5) | Iñigo; Robert; Calea | MINT |

**Basis:**
- *MINT*: fixed by MINT.
- *SoW*: set by the statement of work.
- *derived*: follows from a MINT date.
- *agreed*: Calea's plan, accepted for MINT on 14 October 2026.

**Whatever moves, three things hold:**
- **The collection doesn't wait.** It deploys and mints without the mystery box or Activation.
- **Burns open only after a real test.** They open to holders only after being tried against the
  real $MNTD. That window is only nine days after TGE, and the testnet $MNTD takes the pressure
  off it.
- **The worker outlives the handover.** MINT runs it after 19 November for as long as cycles
  run (CQ-23).

## 9. Deliverables and acceptance (DEL)


<!-- openspec:begin family DEL -->
Each deliverable and the standard it is accepted against, written down, so both parties can tell when the work is done and what remains.

**DEL-1 Source.** The code compiles without warnings, and the automated security scan finds nothing High or
Critical. Every accepted Medium is documented.

*Technical note.* Warning-free `forge build`; Slither with no High or Critical finding.

**DEL-2 Tests.** Every contract has deterministic tests, organised by a written test tree, covering at least 90%
of lines.

*Technical note.* Deterministic unit and integration tests with a branching tree per contract
(`test/<Contract>.tree.md`); the coverage gate is at least 90% line and 80% branch.

**DEL-3 Review report.** Calea's internal auditor reviews each tranche independently of the developer, by hand and with
tools including fuzzing, and delivers a report with it.

*Technical note.* Static and manual review, plus fuzzing and invariant harnesses, written and run
by the internal auditor independently of the developer.

*Acceptance.* When a tranche is delivered; then the internal auditor's report, with the fuzzing and invariant results, is delivered with it.

**DEL-6 Integration package.** A TypeScript client library for getminted.io that covers every contract call the app makes. It is
typed and tested, and handles every error a caller must deal with, each with a message ready to
show holders:
- **the play page:** the mint's progress, read from the chain (holders mint on OpenSea's drop
  page, WL-4); burning; and the mystery box (opening, outcomes, odds, shots left, a winner's
  ticket and claim, payouts);
- **MINT's admin page:** setting up a cycle — sending each prize from the prize wallet to the
  vault on its chain, registering the prize list on every vault and scheduling the cycle on both
  game chains, all with one fingerprint computed from the list — then pauses, the vaults' signer,
  releases and withdrawals;
- **the worker:** relaying openings, signing and serving claim tickets, and recording payouts.

MINT builds against a library that has already been exercised, not against raw contract
interfaces (`→ CQ-19`). It also includes a reference script that reproduces the royalty split,
dead-address exclusion included, so MINT can check its split adds up.

*Technical note.* Interfaces, events, roles and calldata examples for every contract. The library
is typed against the ABIs and covers: mint reads (the public stage, the allowlist root, a wallet's mint
stats); burn (`costToReach`, approve, `burn`); the mystery box (`open`, outcomes,
odds, shots left, payout records); the prize vault (the funding transfer for each prize kind —
native, ERC-20 `transfer`, ERC-721 and ERC-1155 `safeTransferFrom` — from the prize wallet,
`manifestHash` computed as `keccak256(abi.encode(prizes))`, `registerCycle`, the ticket's EIP-712
typed data, `claim`, the vault's reads, `release`, `withdraw`, `setSigner`, pauses); the admin
page (`scheduleCycle` on both game chains, pauses); the worker (`resolve`, `recordPayout`,
ticket signing). It documents the revert reasons a caller has to handle. The reference script
reproduces the split from `Activation.snapshot`, so that "allocations plus carried rounding equal
funding" is testable by MINT.

*Acceptance.* When MINT integrates the play page and the admin page; then every contract call they make is covered by the typed TypeScript library, with passing tests and documented revert reasons, and the reference script reproduces the royalty split.

**DEL-8 Audit tranches.** Tranche 1 is the collection and Activation. Tranche 2 is the mystery box, the draw and the prize
vault. The whitelist has no contract, so none of it is audited (WL-8). Iñigo
accepts each tranche after Calea and MINT sign off, and anything not accepted stays switched off
in the page.

*Technical note.* Tranche 1: `MintABear` and `Activation`. Tranche 2: `MysteryBox`, `PrizeDraw`
and `PrizeVault`.

**DEL-9 Repository.** The contracts go into MINT's repository, `github.com/mintdotio/NFT`, as their own package beside
the client library (MINT, 28 and 29 September 2026). The repository has no CI for them: Calea
builds, formats and tests them locally before every pull request into the staging branch, and
again at review. The contracts go in as each tranche is accepted. The client library's mint and
whitelist calls, and the whitelist check (WL-4), are needed before the whitelist stage.

*Technical note.* `https://github.com/mintdotio/NFT`: `packages/contracts` (`@mint/contracts`)
beside `packages/contracts-client`. `packages/contracts` is a Foundry package with a thin
`package.json`, so `pnpm -r build|test|check` reach it, and its Foundry dependencies are git
submodules. The local gates are `forge fmt --check`, `forge build --sizes` with no warning,
`forge test`, the coverage gate and Slither, run before every pull request into `release/1.1`
(CQ-14).

*Acceptance.* When the contracts land in the monorepo; then `pnpm -r build|test|check` reach the Foundry package and the forge gates pass locally before every pull request into the staging branch.

**DEL-10 Commercial items for Rayco's agreement.** Listed so nothing is implied:
- prize logic, the cycles and the win rule;
- weight interfaces;
- Studio and frontend assistance;
- mainnet execution and handover on every chain;
- technical support through 19 November with agreed response hours;
- beyond the statement of work's single-chain design:
  - **whitelist support**: the check and a review of the claim rules (WL-4,
    WL-8);
  - the **cross-chain draw**: the draw on Arbitrum, relaying each opening, and the payout
    record;
  - the admin-page calls in the client library.

Priced as a service after the handover:
- **holding and funding the randomness subscription**, invoiced to MINT (CQ-17).

The worker is built by Calea and run by MINT (CQ-23), so running it is not a Calea service.

**DEL-11 Frontend collaboration.** MINT builds and owns the page holders use to mint, open boxes, burn and level up, in TypeScript
on getminted.io (MINT, CQ-19). Calea owns the contracts and the client library (DEL-6), and
reviews every change that touches a contract call before it merges. The Framer landing page
stays as it is and is neither built nor reviewed by Calea. Everything lives in
`github.com/mintdotio/NFT` (CQ-14).

**DEL-12 Review sign-off.** Every Critical and High finding from the internal audit (DEL-3) is fixed before the contract it
concerns goes to mainnet, for every contract in an audit tranche (DEL-8).
<!-- openspec:end -->

## 10. Decisions

Everything MINT has decided is written into the requirements. This section gathers the decisions
in one place, then lists what is still open.

### What is settled

| Topic | Decision | Where |
|---|---|---|
| **Admin** | `0x1530…6141` owns every contract on every chain. Ownership moves only in two steps, the new owner accepting, so MINT can move to a multisig later; it can never be renounced (CQ-12) | OPS-1, COL-10, ACT-12, RAF-14 |
| **Supply** | 4,444 bears, forever. No bear can be burned (CQ-6) | COL-2, COL-8 |
| **Royalties** | 5% to `0xf7E7…0e63`, enforced on marketplace sales from deployment (CQ-7, CQ-15) | COL-6, COL-7 |
| **Holder protection** | No freeze and no clawback. No admin can touch a holder's bear (CQ-16) | ACT-12 |
| **Whitelist** | Kept in MINT's backend, with no contract. Wagering gives up to 2 spots per wallet out of 1,000, all guaranteed; collaborations and giveaways add up to 3,222 spots on top, so every spot has a bear. getminted.io shows a wallet all of its spots. The final list goes into Studio, and Calea checks the two match (CQ-18, CQ-24). The campaign closes on 27 October at 12:00 UTC; the whitelist stage opens on 29 October at 12:00 UTC, and holders mint on OpenSea's drop page (CQ-1, CQ-19) | WL-1, WL-8, WL-4, WL-5 |
| **$MNTD** | Native to Robinhood Chain. A standard burnable token: 18 decimals, fixed supply, no owner (CQ-2) | ACT-7 |
| **Levels** | Burning 1,666 / 3,333 / 8,333 / 16,666 / 41,666 $MNTD in total reaches levels 1–5 (CQ-4) | ACT-2 |
| **Weights** | 1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00 for levels 0–5. A level-5 bear earns twice a level-0 bear's share (CQ-5) | ACT-3 |
| **Status links** | MINT's, kept off-chain against holders' Privy accounts (CQ-21) | ACT-12 |
| **Mystery box** | Runs in cycles MINT schedules. Each bear gets one shot per cycle, decided on the spot by a fresh random number. The odds are fixed for the cycle, and unawarded or unclaimed prizes stay in the prize vault for later cycles (CQ-9, CQ-22) | RAF-32, RAF-28, RAF-30 |
| **Team bears** | 222, minted first. They play the mystery box like every other bear and can win (CQ-20) | RAF-27 |
| **Draw** | On Arbitrum One, using Chainlink's randomness. Calea holds and funds the subscription and invoices MINT, after the handover too (CQ-17) | RAF-8, DEL-10 |
| **Worker** | Built by Calea, run by MINT on its own infrastructure from a key MINT creates, with ETH on Arbitrum One for gas (CQ-23) | RAF-18 |
| **Prizes** | Held by a prize vault on each prize chain (Robinhood Chain, Ethereum, ApeChain; Base when a cycle first uses it), funded from MINT's prize wallet `0xf6c0…83e3` on MINT's admin page during cycle setup. A winner claims with a ticket the worker signs, paying gas on the prize's chain, until one hour after the cycle's end; each prize is released once, only to the winner, and an unclaimed prize stays for a later cycle. Every claim is recorded on-chain (CQ-8, CQ-20, CQ-22) | RAF-33, RAF-35, RAF-36, RAF-37 |
| **Play page** | MINT builds it in TypeScript on getminted.io, using Calea's tested client library (CQ-19) | DEL-6, DEL-11 |
| **Repository** | `github.com/mintdotio/NFT`, with Calea's recommended layout (CQ-14) | DEL-9 |

Questions closed without a decision are listed in the appendix.

### Open items

One point is still MINT's to supply, with the date it is needed. It carries
Calea's fallback, which is what is built if it is not answered in time.

**O1 — $MNTD's mainnet address (CQ-2)** · by 20 October

The activation contract is tied to one $MNTD address for life. The testnet token is deployed and
carries the reference token's code. MINT deploys the mainnet token on 19 October, 24 hours before
TGE, and sends its address that day.

*Holds up:* the activation contract's deployment, not the mint. *If not answered:* the
activation contract is not deployed, and burns cannot open on 29 October.

## 11. Sign-off

| Party | Name | Date | Signature |
|---|---|---|---|
| MINT | Iñigo Gaston | | |
| Calea | Bojan Jovin | | |
| Rayco | | | |

Version 2.6, 29 September 2026. The version signed has the open items of §10 resolved.
Amendments are issued as new versions, and requirement identifiers are never reused.
