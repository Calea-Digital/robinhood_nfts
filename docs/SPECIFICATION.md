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
| Client library (DEL-6) | Built and reviewed: mint, burn, transfers, reads and the royalty split, with a ready-to-show message for every error. Mint proofs from MINT's whitelist list are being added |
| Deployment and runbook (§7) | Scripts written and tested; the runbook covers every operating step |
| Internal audit | Tranche 1 (collection and activation): 30 September – 1 October |
| Testnet rehearsal | As soon as MINT's testnet $MNTD is deployed (O6) |
| Mystery box (§6) | Specified. Built once the team bears' ids arrive (O2) |

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
  - backend services and indexing, apart from the worker (O5).
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
| MINT's wallets | Admin `0x1530…6141`: the team bears, each cycle, pauses. Prize wallet `0xf6c0…e3e3`: holds and pays prizes |
| Worker | Carries each box opening to the draw and records payouts. Calea runs it unless MINT decides otherwise (O5) |
| Calea / Rayco | Builds, tests, deploys and hands over the contracts and the client library. Keeps no key after handover, except the worker's if O5 decides so |
| Calea internal auditor | Audits each tranche independently of the developer: review, fuzzing, report |

## 2. System overview (SYS)

**Where it runs.**

| Chain | What it holds |
|---|---|
| Robinhood Chain | The bears, their levels and the mystery box's openings; prizes in MINT's wallet |
| Arbitrum One | The draw, which uses Chainlink's randomness (Robinhood Chain has none) |
| Ethereum | Prizes in MINT's wallet; no contract |
| ApeChain | Prizes in MINT's wallet, if MINT confirms it (O2); no contract |

Everything is rehearsed first on the testnets: Robinhood Chain testnet (46630), Arbitrum Sepolia,
Sepolia and, if ApeChain holds prizes, Curtis.

**The contracts.**

| Contract | Chain | What it does |
|---|---|---|
| `MintABear` | Robinhood Chain | The 4,444-bear collection. Counts every transfer, which resets a bear's level, and enforces royalties |
| `Activation` | Robinhood Chain | Burns $MNTD for a bear and records its level and royalty weight |
| `MysteryBox` | Robinhood Chain | Runs the cycles, keeps team bears out, checks that the opener owns the bear, and records each opening |
| `PrizeDraw` | Arbitrum One | Decides each opening in turn with a fresh random number, and records wins and payouts |

The whitelist has no contract (WL-8).

**Who can do what.**
- **The contracts enforce:**
  - ownership and the 4,444 cap;
  - the level reset on transfer, levels and weights;
  - one shot per bear per cycle and the team-bear exclusion;
  - the order of the draw.
- **MINT's admin wallet**, one wallet for every contract (O1), configures Studio, pauses burning,
  and schedules each cycle with its prize list. It cannot move a holder's bear, grant a level
  without a burn, or change an outcome. It can allow another minter on the collection, so that
  key has to be kept safe.
- **MINT's prize wallet** holds and pays the prizes. Nothing on-chain forces a payout. What the
  chain guarantees is the record: every win and every payout is public, so an unpaid win is
  visible to anyone.
- **The worker** carries each opening to the draw and records payouts. It cannot change an
  outcome or the order. It can only delay one, and a delay is visible.
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
2. **Mint.** Iñigo runs the drop in Studio, and holders mint on OpenSea or getminted.io.
3. **Burn.** A holder burns $MNTD for a bear, and its level and weight rise.
4. **Transfer.** Any transfer resets the bear's level to 0.
5. **Mystery box.** MINT schedules a cycle and publishes its prize list. A holder opens a box with
   a bear and the draw decides it at once. A win is paid from MINT's prize wallet and recorded.
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
bears can prevent that. OpenSea's handling on Robinhood Chain is proven first on testnet with
Studio, then by selling one team bear before the drop page is published. If OpenSea cannot fill
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
- **Thresholds.** $50 wagered unlocks spot 1 and $100 unlocks spot 2. Season 1 wagering counts up
  to $50, so spot 2 always needs at least $50 wagered during the campaign. For example, a holder
  with $16,361 of Season 1 wagering sees one spot claimable and $50 more to wager for the second.
- **First come, first served** on getminted.io/mintabear. Reaching a threshold makes the account
  eligible but reserves nothing. A spot belongs to the wallet once the backend has recorded the
  claim.
- **Live counter.** It shows "spots left — X / 1,000". A claim that arrives after the last spot
  is refused whole.
- **Limits.** The holder chooses the wallet the bear will mint to. There are at most two wagering
  spots per wallet and two per account. Spots from other channels come on top and do not count
  toward the 1,000 (WL-8).
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
- **Calea:**
  - the check that Studio's list is MINT's final list (WL-4);
  - the mint proofs for getminted.io, built from the same list (DEL-6);
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
- **Before the stage opens,** Calea checks that Studio's list is exactly MINT's final list. The
  getminted.io page builds its mint proofs from the same list.

*Technical note.* The final list is a CSV, `wallet,allocations`. Each row becomes a SeaDrop
allowlist leaf whose `maxTotalMintableByWallet` is the row's allocations, and SeaDrop counts it
against every bear minted to the wallet. `compare` in `script/WhitelistExport.s.sol` rebuilds the
allowlist Merkle root from the CSV and the stage's parameters, and fails unless it is the root on
SeaDrop, naming the difference. The client library's `buildAllowList` builds the getminted.io
proofs from the same CSV (DEL-6). The row's address is the address that calls `mintAllowList`.
The CSV's allocations total at most 4,222, and `compare` also fails when they total more. The
whitelist stage's `maxTokenSupplyForStage` is 4,444, the collection's total including the team's
222, so the stage can fill every row.

*Acceptance.* Given MINT's final CSV and the whitelist stage Studio has set; when `compare` runs over the CSV and the stage; then it passes only if the root on SeaDrop is the root of the CSV's rows, and fails naming the difference otherwise.

**WL-5 Timing.** MINT's backend takes claims only during the campaign window. The list is frozen at least 48
hours before the whitelist stage opens, which leaves time to load it into Studio, check it and
fix anything. The stage opens with the mint on 29 October, so the list is frozen by 27 October at
the same time of day. The 48 hours is Calea's buffer, not an OpenSea rule. Dates `→ CQ-1`.

**WL-8 Off-chain register.** The whitelist lives in MINT's backend, and no contract is deployed for it (MINT, 28 September
2026, `→ CQ-18`).
1. A holder signs in on getminted.io with Privy, or pastes a wallet address.
2. The page shows what the account has wagered and what is left to unlock the next spot.
3. The holder claims what is unlocked. A pasted address proves it belongs to the holder with a
   free wallet signature. A wallet connected through Privy has already done so.
4. The backend records the claim.

The backend's counter makes sure two claims at the same moment can't both take the last spot.

getminted.io is also a general whitelist checker. The register holds every whitelist spot, from
wagering and from every other channel, such as cross-community collaborations and giveaways, and
a wallet sees all of its spots, wagered or not. Spots from other channels do not count toward the
1,000 and come on top of the two wagering spots; together they are capped at 3,222 (MINT,
29 September 2026). The final list has one
row per wallet, with its total across all channels. Nothing about the whitelist is public until
Studio's list is set, and after that Studio's list is its only trace on-chain.
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
A holder opens a mystery box with a bear they own and learns the outcome on the spot. The box runs in cycles MINT schedules: in each cycle every playable bear gets one shot, and the next cycle gives every bear a new one, whoever holds it. `MysteryBox` on Robinhood Chain runs the cycles and records openings. `PrizeDraw` on Arbitrum One decides each opening and records wins and payouts.

**RAF-32 Cycles.** MINT's admin schedules each cycle before it starts: its window, its number of prizes, and a
fingerprint of the prize list MINT publishes (RAF-27) (MINT, CQ-9, CQ-20). A cycle can't be
scheduled while one is open, start in the past, or start before the previous one ends. A cycle
lasts at most 90 days, so a mistyped end date can't hold the game in one cycle for longer. A
scheduled cycle can be replaced until it starts; from then on its terms are fixed. Boxes open
only inside the window, and an opening made inside it is decided even if the answer arrives
after the window ends (RAF-29). Prizes a cycle doesn't award stay in MINT's prize wallet
(RAF-33) for a later cycle. MINT decides when the next cycle starts, so the game can rest between
cycles for as long as MINT needs. The draw is given the same prize count and fingerprint, and
both chains publish them, so anyone can check they match.

*Technical note.* `scheduleCycle(start, end, prizeCount, manifestHash)` on `MysteryBox` records
the next cycle. It is refused while a cycle is open (`CycleInProgress`); for a window that starts
in the past, starts before the previous cycle ends, ends before it starts, or has `end - start`
above `MAX_CYCLE_LENGTH`, 90 days (`InvalidWindow`); and for a prize count of zero or above
`PLAYABLE` (`InvalidPrizeCount`). A cycle is open from `start` to `end` inclusive. `PrizeDraw`
carries each cycle's `prizeCount` and `manifestHash`, set by the owner with
`scheduleCycle(cycleId, prizeCount, manifestHash)` before the cycle's first open is resolved.
Both chains emit `CycleScheduled`.

*Acceptance.* Given the owner has scheduled cycle 1 from `start` to `end` with 5 prizes; when a holder opens a box before `start`, between `start` and `end`, and after `end`; then only the open between `start` and `end` succeeds, and the others revert with `CycleNotOpen`; and scheduling cycle 2 while cycle 1 is open reverts with `CycleInProgress`.

**RAF-27 Playable ids and the prize pool.** A cycle's odds depend on two numbers: how many bears can play and how many prizes it has. MINT's
222 team bears are excluded (which ids `→ CQ-20`). The exclusion is recorded once, before the
first cycle, and never changes. The box is told at deployment how many bears will play, and the
first cycle can't be scheduled until the exclusions leave exactly that many, so a missed or
mistyped range is caught before anything is fixed. An excluded bear stays out whoever holds it,
so a sold team bear stays out. That leaves 4,222 playable bears. Before each cycle MINT publishes
its prize list: each prize's chain, token and id or amount, in order. The n-th prize won in a
cycle is entry n of the list. Only the count and the list's fingerprint are on-chain. The prizes
are in MINT's prize wallet (RAF-33), so the list is MINT's commitment.

*Technical note.* `MysteryBox(owner, bears, expectedPlayable)` takes the expected playable count,
4,222, the same deploy value `PrizeDraw` takes as `PLAYABLE`; it is refused unless from 1 to
`MAX_BEARS`. The owner records exclusions as ranges with `excludeRange(from, to)` (event
`IdsExcluded`), allowed only until the first cycle is scheduled and frozen after it
(`ExclusionFrozen`). `PLAYABLE = MAX_BEARS − excluded`; the first `scheduleCycle` is refused unless
it equals `EXPECTED_PLAYABLE` (`ExclusionsIncomplete(have, want)`), and from then on `PLAYABLE` is
fixed. The prize list's hash is the cycle's `manifestHash` (RAF-32); the contracts cannot check
it against a balance.

*Acceptance.* Given ranges excluded totalling 222 ids; when the owner schedules the first cycle; then `PLAYABLE` reads 4,222 and `excludeRange` reverts with `ExclusionFrozen`.

**RAF-28 Opening a box.** A bear's holder opens a box with it while a cycle is open, free apart from gas. The opening is
refused while the box is paused, outside a cycle, for anyone who doesn't hold the bear, for a
team bear, and for a bear already opened this cycle. Each bear has one shot per cycle (MINT,
CQ-9): an opened bear can still be sold, but nobody can open it again that cycle, its buyer
included. In the next cycle, whoever holds it can. The page shows a wallet's shots left: a holder
of ten bears who has opened two sees eight. The page counts them from each bear's own record; the
box itself keeps no count per wallet, and the count is for display only, since opening is what
enforces the rule.

*Technical note.* `open(uint256 tokenId)` on `MysteryBox`, by `ownerOf(tokenId)` at that moment.
It reverts with `ContractPaused`, `CycleNotOpen`, `NotBearOwner`, `IdExcluded` or
`AlreadyOpened`. Effects: the id is spent for the cycle (`opened(cycleId, tokenId)` reads true),
the next `openIndex` is assigned (one sequence across all cycles), and
`BoxOpened(openIndex, cycleId, tokenId, opener)` is emitted. Shots left are counted by the client
library: for each bear the page's indexer lists for the wallet, one Multicall3 call (deployed on
4663 and 46630) reads `ownerOf`, `isExcluded` and `opened(currentCycle, tokenId)`, and a bear
counts when the wallet holds it, it is not excluded and it has not opened in the open cycle.
Because ownership is read on-chain, a stale list can leave out a bear just received but never
counts one sold.

*Acceptance.* Given an open cycle and a holder of a playable bear not yet opened in it; when the holder calls `open(tokenId)`; then `BoxOpened(openIndex, cycleId, tokenId, opener)` is emitted and `opened(cycleId, tokenId)` reads true; and the buyer of that bear cannot open it again in the same cycle, reverting with `AlreadyOpened`, and may open it in the next.

**RAF-29 Resolution, in order.** The worker carries each opening to the draw on Arbitrum One, which decides openings strictly in
the order they were made. It refuses one out of turn, so the worker can't choose which opening
meets which state of the prize pool. It can only delay one, and a delay is visible. Each opening
gets its own random number. Several can be in flight at once, but results are applied in order.
Each relay names the bear that opened, so every result can be matched to its opening on Robinhood
Chain, and the draw refuses a bear relayed twice in one cycle and a relay once a cycle's bears are
all relayed. The worker relays an opening once Robinhood Chain's sequencer has confirmed it. A
random number is never lost to a failed delivery: the draw stores each number as it arrives, and
anyone can apply the stored numbers in order, so a cycle's last results are recorded even when no
further opening follows.

*Technical note.* `resolve(uint64 openIndex, uint64 cycleId, uint256 tokenId, address opener)` on
`PrizeDraw`, relayed from `BoxOpened`. It refuses any `openIndex` but the next unresolved one
(`OutOfOrder`); a cycle it has not been given or one earlier than the last it resolved
(`UnknownCycle`); a `tokenId` outside 1 to `MAX_BEARS` (`InvalidTokenId`); a `tokenId` already
resolved in that cycle (`AlreadyResolved`); and any resolve once the cycle has accepted
`PLAYABLE` relays (`CycleExhausted`). It requests one Chainlink word and emits
`DrawRequested(openIndex, requestId)`. The VRF callback stores the word for its `openIndex` and
never reverts for a request the draw made; outcomes are applied in `openIndex` order, so an open
waits only on the words of the opens before it. The callback and `resolve` each apply pending
outcomes within a fixed budget, and `applyOutcomes(maxCount)`, open to anyone, applies up to
`maxCount` more; none of them can change an outcome, only when it is recorded. A delayed open
shows as a `BoxOpened` with no `OutcomeRecorded`; a relayed open that matches no `BoxOpened` on
4663 is visible the same way. An open made before its cycle's `end` is resolved even if the word
arrives after it.

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
on Arbitrum. The subscription that pays for the numbers is assumed to be MINT's (`→ CQ-17`). It
is funded for a cycle's worth, at most 4,222 numbers, and topped up when its balance runs low. An
answer normally takes seconds to minutes; if Chainlink has not answered an opening within an
hour, the worker can ask again, so a lost request holds the queue up for an hour at most.
Whichever answer arrives first is the one used, so asking again can never be used to pick a
better number.

*Technical note.* Chainlink VRF v2.5, one request and one word per open. `PrizeDraw` on Arbitrum
One (42161) uses coordinator `0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e`, and on Arbitrum
Sepolia (421614) `0x5CE8D5A2BC84beb22a398CCA51996F7930313D61`; it is the subscription's consumer.
The subscription is funded for at most `PLAYABLE` requests per cycle and topped up on a balance
alarm, not on a schedule. Robinhood Chain's `prevrandao` is constant. `rerequest(openIndex)`, by
the worker, requests another word for a relayed opening with no word whose last request is at
least `REREQUEST_AFTER` (1 hour) old, emitting `DrawRequested` again; it is refused for an
opening not yet relayed (`NotRelayed`), one already answered (`AlreadyAnswered`) and one asked
more recently (`TooEarly`). Every request made for an opening stays valid, and the first word
delivered is stored and applied; later words are ignored.

*Acceptance.* When `resolve` runs; then exactly one VRF v2.5 request is made from the subscription with `PrizeDraw` as consumer; and the outcome uses that request's word alone.

**RAF-33 Prize custody and the payout record.** Prizes sit in MINT's prize wallet `0xf6c0…e3e3` on Robinhood Chain, Ethereum and possibly
ApeChain (MINT, CQ-8, CQ-20). No contract holds a prize or runs on a prize chain. A prize is paid
by an ordinary transfer to the winner's address on the prize's chain; by default MINT sends every
win (`→ CQ-22`). Nothing on-chain forces a payout, and MINT can move any prize at any time.
Custody is MINT's choice. What the chain guarantees is the record. The worker records each payout
on the draw contract, once and only for a win, so anyone can match a win to its transfer and see
a win that was never paid. The winner is whoever opened the box. If a winner's wallet can't
receive on a prize chain, MINT settles it by hand, and the page warns contract-wallet holders
before they open.

*Technical note.* The prize wallet is `0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3`, an externally
owned account. The worker calls `recordPayout(openIndex, chainId, txHash)` on `PrizeDraw`,
refused unless the outcome of `openIndex` is a win (`NotAWin`) not yet recorded as paid
(`AlreadyPaid`); it emits `PrizePaid(cycleId, openIndex, chainId, txHash)`. There is no on-chain
nomination of another recipient.

*Acceptance.* Given open 7 recorded as a win; when the worker calls `recordPayout(7, 1, txHash)`; then `PrizePaid(cycleId, 7, 1, txHash)` is emitted; and a second `recordPayout` for open 7 reverts with `AlreadyPaid`, and one for an open that did not win reverts with `NotAWin`.

**RAF-14 Roles.** **MINT's admin** records the team bears, schedules cycles, sets the worker and pauses either
contract. Ownership can't be given up. **The worker** carries openings to the draw, asks again for
an opening Chainlink has not answered within an hour, and records payouts (who runs it `→ CQ-23`).
**Anyone** can open a box with a bear they hold, apply outcomes whose random numbers have arrived,
and read everything. No role can open a box for a holder, change an outcome or move a bear.

*Technical note.* Owner: on `MysteryBox` `excludeRange`, `scheduleCycle`, `setPaused`; on
`PrizeDraw` `scheduleCycle`, `setWorker`, `setPaused`; ownership transfer on both;
`renounceOwnership` reverts on both. Worker: `resolve`, `rerequest` and `recordPayout` on
`PrizeDraw`. Anyone: `open` on `MysteryBox`, `applyOutcomes` on `PrizeDraw`. The VRF coordinator
alone delivers words.

*Acceptance.* When a non-owner calls `excludeRange`, `scheduleCycle` or `setWorker`, or a non-worker calls `resolve` or `recordPayout`; then each reverts; and `open` needs no role but the bear's ownership.

**RAF-34 Pause.** Pausing the mystery box stops new openings. Pausing the draw stops new random numbers being
requested, while numbers already requested are still applied. Neither pause stops payout records
or reads. A pause doesn't extend a cycle; it only shortens the time holders have.

*Technical note.* Pausing the hub blocks `open`; pausing `PrizeDraw` blocks `resolve`. Neither
blocks `recordPayout` or any read, and a pause does not move `end`.

*Acceptance.* Given the hub and the draw each paused; when `open` and `resolve` are called; then each reverts with `ContractPaused`; and `recordPayout` and every read still succeed.

**RAF-16 Events.** Both contracts publish every step: the team-bear exclusions, each cycle's terms on both chains,
every opening, every request for a random number, every outcome with the bear that opened, every
payout, and every change of worker or pause.

*Technical note.* Hub: `IdsExcluded(from, to)`, `CycleScheduled(cycleId, start, end, prizeCount,
manifestHash)`, `BoxOpened(openIndex, cycleId, tokenId, opener)`, `PausedSet`. `PrizeDraw`:
`CycleScheduled(cycleId, prizeCount, manifestHash)`, `DrawRequested(openIndex, requestId)`,
`OutcomeRecorded(openIndex, cycleId, tokenId, opener, won, prizeIndex)`, `PrizePaid(cycleId,
openIndex, chainId, txHash)`, `WorkerSet`, `PausedSet`.

*Acceptance.* When a cycle runs through exclusion, scheduling, an open, a resolution and a payout record; then every listed event fires with the documented arguments.

**RAF-17 Reads.** The page can read for free: the playable count, whether a bear is excluded or already opened this
cycle, the current cycle and its terms, the longest a cycle may last, the live odds, and each
opening's bear, outcome and payout. A wallet's shots left come from these reads, one per bear
(RAF-28).

*Technical note.* Hub: `MAX_BEARS`, `PLAYABLE`, `EXPECTED_PLAYABLE`, `MAX_CYCLE_LENGTH`,
`isExcluded(tokenId)`, `currentCycle()` and each cycle's `(start, end, prizeCount, manifestHash)`,
`isOpen()`, `opened(cycleId, tokenId)`, `openCount()`. `PrizeDraw`: `PLAYABLE`, each cycle's
`(prizeCount, manifestHash, idsLeft, prizesLeft)`, `nextToResolve()`, `nextToApply()`,
`outcomeOf(openIndex)` with its `tokenId`, `payoutOf(openIndex)`, and `odds(cycleId)` returning
`(prizesLeft, idsLeft)`. Each read costs a fixed amount, whatever the number of bears.

*Acceptance.* When every listed read is called during an open cycle; then each returns without reverting and `odds(cycleId)` returns `(prizesLeft, idsLeft)`.

**RAF-18 Worker sequence.** A cycle runs in this order:
1. Once, before the first cycle, MINT records the team bears.
2. For each cycle, MINT publishes the prize list, schedules the cycle on both chains with the same
   prize count and fingerprint, and holds the prizes in its prize wallet.
3. Holders open boxes inside the window.
4. The worker carries each opening to the draw, in order.
5. Random numbers arrive and outcomes are recorded.
6. Each win is paid from the prize wallet on its chain and recorded.
7. After the window, MINT schedules the next cycle whenever it is ready.

MINT's page shows the cycle's window, its prize list, the live odds, a wallet's shots left, its
outcomes and its payouts, and warns contract-wallet holders before they open.

*Acceptance.* When the sequence runs on the testnets through two cycles, from exclusion to the payout records; then each step succeeds in the listed order, a relay offered out of turn is refused, and a bear opened in cycle 1 opens again in cycle 2.

**RAF-19 Acceptance cases.** Each of these has a test:
- an excluded id cannot be opened, before or after it is sold;
- exclusions cannot change once the first cycle is scheduled;
- a box cannot be opened outside its cycle's window;
- a bear cannot be opened twice in one cycle, by its holder or its buyer, and can be opened in
  the next;
- a cycle cannot be scheduled while one is open, and a scheduled cycle's terms cannot change
  once it has started;
- a relay out of order is refused;
- a bear relayed twice in one cycle is refused by the draw, and so is a relay once the cycle's
  bears are all decided;
- an opening Chainlink has not answered can be asked again only after an hour, and only the
  first answer to arrive is used;
- a cycle in which every playable bear is opened awards exactly its prize count, and the pool
  neither empties early nor is left over;
- a cycle that ends early awards no more than its prize count;
- a win is recorded as paid once, and a loss cannot be;
- a holder who sells a bear after opening it keeps its outcome.

*Acceptance.* When the tranche-2 test suite runs; then every listed case has a passing deterministic test.
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
| Admin | owns every contract on every chain | MINT, `0x1530…6141` (to confirm for every contract, O1) |
| Worker | carries openings to the draw and records payouts | Calea, assumed (O5) |
| Royalty receiver | receives the 5% royalties (the pot) | MINT, `0xf7E7…0e63` |
| Prize wallet | holds and pays every prize | MINT, `0xf6c0…e3e3` |
| Randomness subscription | pays for the draw's random numbers | MINT, assumed (O4) |

*Technical note.* Admin `0x153052B43c8fD4ec01f14D1Edd8660778daa6141`, an EOA (MINT, 28 September
2026), owner of every contract on every chain `→ CQ-12`. Worker: an EOA funded on Arbitrum,
holding `resolve` and `recordPayout` on `PrizeDraw` `→ CQ-23`. Royalty receiver
`0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63`, the ERC-2981 receiver `→ CQ-15`. Prize wallet
`0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3`, an EOA (RAF-33). VRF subscription: the Chainlink
subscription `PrizeDraw` draws on `→ CQ-17`.

*Acceptance.* When the mainnet deploy scripts run; then the admin and worker addresses they read are the ones MINT recorded; and the royalty receiver is set in Studio before the first sale.

**OPS-2 Deployment order.** Every address a contract needs is given when it is deployed, so each contract is correct from its
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
after it; `MysteryBox(owner, bears)`. Arbitrum One:
`PrizeDraw(owner, coordinator, subscriptionId, keyHash, worker, playable)` → added as the
subscription's consumer.

*Acceptance.* When the deploy script runs on a fresh chain; then each contract is created with its constructor arguments in the listed order and is never left deployed-but-unconfigured; and no address is set after construction; every call after construction is a listed setting or ownership transfer, in the listed order.

**OPS-3 Verification.** Every contract's source is published and verified: on Sourcify for Robinhood Chain and its
testnet, and on Arbiscan for Arbitrum One and Arbitrum Sepolia.

*Technical note.* Sourcify for 4663 and 46630, because mainnet Blockscout's API sits behind a bot
challenge; Arbiscan through Etherscan's API for 42161 and 421614.

*Acceptance.* When a contract is deployed on 4663 or 46630; then its source is verified through Sourcify and readable there.

**OPS-4 Rehearsal on testnets (46630, Arbitrum Sepolia, Sepolia).** Before mainnet, everything is rehearsed on the testnets:
- Studio managing a collection Calea deployed, with royalty enforcement on;
- minting through OpenSea and through getminted.io;
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

*Acceptance.* When the rehearsal runs on 46630, Arbitrum Sepolia and Sepolia; then each listed path completes end to end, including one open that wins and one that does not.

**OPS-5 Handover.** Calea deploys, configures, hands over ownership, verifies the source and delivers the runbook,
then holds no owner key. The one role it may keep is the worker's, if Calea runs it (O5), and
MINT's admin can take that back at any time. Technical support runs until 19 November 2026 with
agreed response hours (DEL-10). The runbook covers:
- the deployment order (OPS-2);
- switching royalty enforcement off and on (OPS-6);
- pausing and opening burns around 29 October (ACT-15);
- loading the whitelist into Studio and checking it (WL-4);
- running a mystery-box cycle (RAF-18).

*Technical note.* The runbook is one document, backed by `forge script` tooling. MINT's admin
takes the worker role back with `setWorker` `→ CQ-23`.

*Acceptance.* When handover completes; then every contract's owner is MINT's admin, every source is verified and the runbook is delivered; and Calea holds no owner key, and no role other than the worker's where CQ-23 gives it one.

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
  a holder acting by a deadline; a box left unopened is just a shot not taken;
- each transaction has a gas limit, so no call loops over the whole collection;
- there is no randomness on Robinhood Chain or ApeChain, so the draw runs on Arbitrum One.

*Technical note.* On Robinhood Chain `block.number` is the L1 height, so contracts and scripts key
on timestamps. The gas limit is Arbitrum-style, per transaction.
<!-- openspec:end -->

## 8. Calendar (CAL)

Four dates are fixed by MINT: TGE on 20 October, the whitelist frozen by 27 October, the mint on
29 October, and burns open on 29 October. Every other date is Calea's plan from the statement of
work, for MINT to confirm or move (`→ CQ-1`). Mystery-box cycles are MINT's to schedule, so they
are not listed.

| Date (2026) | What happens | Who | Basis |
|---|---|---|---|
| 29 Sep – 2 Oct | Collection final and deployed with royalty enforcement; Studio proven on testnet; OpenSea page live; one team bear listed and sold | Calea; Iñigo | SoW |
| 30 Sep – 1 Oct | Internal audit of the collection and activation contracts | Calea | Calea |
| when MINT deploys it | Test $MNTD on the testnet, for the burn rehearsal (O6) | MINT (Lorenzo) | MINT |
| 5 – 9 Oct | Mystery box, draw, worker and page tested on the testnets, two cycles included; audit report and runbooks; no open Critical or High finding | Calea; Javier; MINT | SoW |
| 12 – 14 Oct | Mystery box and draw deployed and verified; roles and addresses checked; randomness subscription funded | Calea; Iñigo; MINT | SoW |
| MINT's dates (O7) | Whitelist campaign open on getminted.io/mintabear | Iñigo; Javier; Vlad; Lorenzo | to confirm |
| 20 Oct | TGE: $MNTD live on Robinhood Chain; Activation deployed against it, paused | MINT; Calea | MINT |
| 20 – 28 Oct | Real burns rehearsed on mainnet, in short windows the admin opens and closes | Calea; MINT | derived |
| by 27 Oct | Whitelist frozen, loaded into Studio and checked by Calea; mint proofs published | Iñigo; Calea | MINT |
| 29 Oct | Mint: the whitelist stage first, then the other stages; burns and level-up open | Iñigo; Javier; Calea | MINT |
| after 29 Oct | First mystery-box cycle, scheduled by MINT with its prize list | Iñigo; Calea | MINT |
| 5 Nov | First royalty split; after that at each ETH cap or countdown (§2) | MINT | SoW; to confirm |
| 19 Nov | Handover; technical support ends (OPS-5) | Iñigo; Robert; Calea | SoW; to confirm |

**Basis:**
- *MINT*: fixed by MINT.
- *SoW*: set by the statement of work.
- *derived*: follows from a MINT date.
- *to confirm*: not yet held by anyone.

**Whatever moves, three things hold:**
- **The collection doesn't wait.** It deploys and mints without the mystery box or Activation.
- **Burns open only after a real test.** They open to holders only after being tried against the
  real $MNTD. That window is only nine days after TGE, and the testnet $MNTD takes the pressure
  off it.
- **The worker outlives the handover.** It keeps running after 19 November for as long as cycles
  run (O5).

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
- **the play page:** minting, with whitelist proofs from MINT's final list (WL-4); burning; and
  the mystery box (opening, outcomes, odds, shots left, payouts);
- **MINT's admin page:** excluding the team bears, scheduling cycles on both chains, pauses;
- **the worker:** relaying openings and recording payouts.

MINT builds against a library that has already been exercised, not against raw contract
interfaces (`→ CQ-19`). It also includes a reference script that reproduces the royalty split,
dead-address exclusion included, so MINT can check its split adds up.

*Technical note.* Interfaces, events, roles and calldata examples for every contract. The library
is typed against the ABIs and covers: mint (SeaDrop stages, allowlist proofs from the whitelist
CSV, `mintPublic`); burn (`costToReach`, approve, `burn`); the mystery box (`open`, outcomes,
odds, shots left, payout records); the admin page (`excludeRange`, `scheduleCycle` on both
chains, pauses); the worker (`resolve`, `recordPayout`). It documents the revert reasons a caller
has to handle. The reference script reproduces the split from `Activation.snapshot`, so that
"allocations plus carried rounding equal funding" is testable by MINT.

*Acceptance.* When MINT integrates the play page and the admin page; then every contract call they make is covered by the typed TypeScript library, with passing tests and documented revert reasons, and the reference script reproduces the royalty split.

**DEL-8 Audit tranches.** Tranche 1 is the collection and Activation. Tranche 2 is the mystery box and the draw, once the
team-bear ids arrive (O2). The whitelist has no contract, so none of it is audited (WL-8). Iñigo
accepts each tranche after Calea and MINT sign off, and anything not accepted stays switched off
in the page.

*Technical note.* Tranche 1: `MintABear` and `Activation`. Tranche 2: `MysteryBox` and
`PrizeDraw`, once CQ-20's remaining values are supplied. `WhitelistClaim` and `WhitelistImport`
are built but not deployed.

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
  - **whitelist support**: the check, the mint proofs and a review of the claim rules (WL-4,
    WL-8);
  - the **cross-chain draw**: the draw on Arbitrum, relaying each opening, and the payout
    record;
  - the admin-page calls in the client library.

Two items are priced only if MINT confirms them:
- **running the worker** after 19 November, if Calea runs it (O5, `→ CQ-23`);
- **holding and invoicing the randomness subscription**, if MINT doesn't (O4, `→ CQ-17`).

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
| **Supply** | 4,444 bears, forever. No bear can be burned (CQ-6) | COL-2, COL-8 |
| **Royalties** | 5% to `0xf7E7…0e63`, enforced on marketplace sales from deployment (CQ-7, CQ-15) | COL-6, COL-7 |
| **Holder protection** | No freeze and no clawback. No admin can touch a holder's bear (CQ-16) | ACT-12 |
| **Whitelist** | Kept in MINT's backend, with no contract. Wagering gives up to 2 spots per wallet out of 1,000, all guaranteed; collaborations and giveaways add up to 3,222 spots on top, so every spot has a bear. getminted.io shows a wallet all of its spots. The final list goes into Studio, and Calea checks the two match (CQ-18, CQ-24) | WL-1, WL-8, WL-4 |
| **$MNTD** | Native to Robinhood Chain. A standard burnable token: 18 decimals, fixed supply, no owner (CQ-2) | ACT-7 |
| **Levels** | Burning 1,666 / 3,333 / 8,333 / 16,666 / 41,666 $MNTD in total reaches levels 1–5 (CQ-4) | ACT-2 |
| **Weights** | 1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00 for levels 0–5. A level-5 bear earns twice a level-0 bear's share (CQ-5) | ACT-3 |
| **Status links** | MINT's, kept off-chain against holders' Privy accounts (CQ-21) | ACT-12 |
| **Mystery box** | Runs in cycles MINT schedules. Each bear gets one shot per cycle, decided on the spot by a fresh random number. The odds are fixed for the cycle, and unawarded prizes stay with MINT for later cycles (CQ-9) | RAF-32, RAF-28, RAF-30 |
| **Team bears** | 222, excluded from the mystery box for good (CQ-20) | RAF-27 |
| **Draw** | On Arbitrum One, using Chainlink's randomness (CQ-17) | RAF-8 |
| **Prizes** | Held and paid by MINT's prize wallet `0xf6c0…e3e3` on Robinhood Chain, Ethereum and possibly ApeChain. Every payout is recorded on-chain (CQ-8) | RAF-33 |
| **Play page** | MINT builds it in TypeScript on getminted.io, using Calea's tested client library (CQ-19) | DEL-6, DEL-11 |
| **Repository** | `github.com/mintdotio/NFT`, with Calea's recommended layout (CQ-14) | DEL-9 |

Questions closed without a decision are listed in the appendix.

### Open items

Seven points are still MINT's to decide or supply, listed by the date each is needed. Each carries
Calea's fallback, which is what is built if it is not answered in time.

**O1 — Who owns the contracts (CQ-12)** · by 2 October

Every contract has an owner, the one wallet that can change its settings: Studio's configuration,
the pause on burning, the mystery box's cycles. We have `0x1530…6141`, a single ordinary wallet.
Confirm it owns every contract on every chain, or name the exceptions.

*Holds up:* the mainnet deployment and the ownership handover. *If not answered:* `0x1530…6141`
owns everything, and the risk rests on that one key (§2).

**O2 — The 222 team bears (CQ-20)** · by 5 October

Team bears never play the mystery box, and the set is fixed for good before the first cycle. We
need their token ids as ranges; if the team mints first from the owner wallet, they are 1–222.
Also: will ApeChain hold prizes?

*Holds up:* the mystery box build and the first cycle. *If not answered:* no fallback; the first
cycle cannot be scheduled.

**O3 — How a prize reaches the winner (CQ-22)** · by 12 October

Prizes sit in MINT's prize wallet, and someone has to send each one: MINT by hand, or an automated
service holding that wallet's key. And does MINT send every win straight away, or does the winner
request it within 30 days?

*Holds up:* the payout step. *If not answered:* MINT sends each win to the winner, and the worker
records it on-chain.

**O4 — Who holds the randomness subscription (CQ-17)** · by 12 October

Each box opening buys one random number from Chainlink on Arbitrum One, paid from a prepaid
subscription that needs topping up. Someone owns and funds it.

*Holds up:* deploying the draw contract. *If not answered:* MINT owns and funds it. If Calea holds
it instead, it is a priced service Calea invoices.

**O5 — Who runs the worker (CQ-23)** · by 12 October

The worker is a small service that carries each box opening from Robinhood Chain to the draw on
Arbitrum and records payouts. It cannot change an outcome or the order, but it must be running.

*Holds up:* deploying the draw contract and the handover. *If not answered:* Calea runs it as a
priced service; MINT can replace it at any time.

**O6 — $MNTD's addresses (CQ-2)** · testnet as soon as possible; mainnet by 20 October

The activation contract is tied to one $MNTD address for life. We need the testnet token's address
for the rehearsal, and the mainnet address at TGE.

*Holds up:* the testnet rehearsal and the activation contract's deployment. *If not answered:* the
rehearsal waits.

**O7 — The dates (CQ-1)** · the whitelist window now; the rest by 29 October

Three dates are fixed: TGE 20 October, mint 29 October, burns from 29 October. Still needed: the
whitelist campaign window (the list freezes 48 hours before the whitelist stage), the first
royalty-split date and the handover date.

*Holds up:* the whitelist freeze and scheduling. *If not answered:* the §8 dates stay proposals.

## 11. Sign-off

| Party | Name | Date | Signature |
|---|---|---|---|
| MINT | Iñigo Gaston | | |
| Calea | Bojan Jovin | | |
| Rayco | | | |

Version 2.6, 29 September 2026. The version signed has the open items of §10 resolved.
Amendments are issued as new versions, and requirement identifiers are never reused.
