# MintABear — Specification

**Version** 2.0-draft · **Date** 18 September 2026 · **Status** basis for the MINT–Calea call of
21 September 2026; sign-off follows the call

Prepared by Calea for MINT. Sources: *MINTaBear development statement of work* (MINT,
14 September 2026); *Mint <> Calea* meeting (15 September 2026); *MintABear questionnaire v2.0*;
MINT's written answers to specification v1.0 (September 2026); *WL Wager Based Checker* (MINT,
September 2026). Where the sources differ, this document states the resolution. Where a point is
still MINT's to decide, the requirement states Calea's recommendation — which is also what Calea
builds if the decision is deferred — and points to the question (`→ CQ-n`) in the register.
Section 10 collects every decision for the call.

**How to read.** Requirements carry stable identifiers: `COL-n` collection contract, `WL-n`
whitelist claim, `ACT-n` activation and burn route, `RAF-n` mystery box raffle, `OPS-n`
operations and handover, `DEL-n` deliverables. Each is a single testable statement. An identifier
is never given a new meaning; a requirement superseded in this version is marked retired and
points to its replacement. In the client document, green callouts record MINT's answers as
confirmed; yellow callouts are decisions for the call.

## 1. Scope

### 1.1 In scope — Calea / Rayco

- **MintABear** collection contract on Robinhood Chain (chain id 4663), SeaDrop-compatible,
  managed through OpenSea Studio by MINT, royalties enforced.
- **WhitelistClaim** registry on Robinhood Chain: records first-come-first-served whitelist
  allocations against MINT-signed wagering eligibility and exports the allowlist for Studio
  (`→ CQ-18`).
- **Activation** contract on Robinhood Chain: cumulative $MNTD burn credits, level derivation
  (0–5), royalty-weight table, Status link; **DirectBurnAdapter**, the same-chain burn route.
- **Mystery box raffle**: `MysteryBox` hub on Robinhood Chain (rounds, entries, draw),
  `PrizeVault` on each chain that holds prizes (Robinhood Chain, Ethereum, ApeChain),
  `SeedRequester` on Base for Chainlink VRF (`→ CQ-8`, `→ CQ-9`).
- Deployment and verification scripts, runbook, testnet deployments, interface/event/role
  documentation with examples, static and manual review, fuzzing and invariant report.
- Technical support for the getminted.io integration: contract call surface, a typed client
  library, calldata examples, review of the frontend's contract calls (`→ CQ-19`).

### 1.2 Out of scope

From the SoW, verbatim: independent audit; existing-contract remediation; on-chain art renderer;
automatic bridges or trading; arbitrary unsupported assets; new casino free spins.

Also out of scope: ERC-6551 token-bound accounts (COL-9); artwork, metadata hosting and reveal
(MINT); the Privy mirror login, the wager API, the eligibility checker and the web app or Framer
pages (MINT); backend workers and indexing; the royalty pot, the $MNTD purchase, the splitter
wallet and the crediting of mint.io accounts; the Status boost; monitoring and alerts (MINT);
bridging prize assets between chains; cross-chain messaging infrastructure.

### 1.3 Parties and responsibilities

| Party | Responsibility |
|---|---|
| Iñigo (MINT) | Collection management in OpenSea Studio; admin of every contract; approves prize assets; funds treasury with Robert; UI with Javier; accepts deliverables |
| Robert (MINT) | Funds treasury and reserves; settlement |
| Javier (MINT) | UI on getminted.io (`→ CQ-19`) |
| Lorenzo (MINT) | Shared Privy login; account, Status and wager APIs; names the contract for review (`→ CQ-13`) |
| Vlad (MINT) | Privy connect on getminted.io and the wager API, with Lorenzo |
| Guri (MINT) | Eligibility checker |
| MINT automation | Worker key: deposit registration, round lifecycle, seed relay, winners root. Eligibility signer: whitelist vouchers |
| Calea / Rayco | Contracts, tests, scripts, runbook, testnets, review, integration support; deploys and hands over; retains no keys or roles |
| Calea internal auditor | Fuzzing and invariant harnesses, review report |

## 2. System overview (SYS)

**Chains.**

| Chain | Id | Hosts | Testnet |
|---|---|---|---|
| Robinhood Chain | 4663 | `MintABear`, `WhitelistClaim`, `Activation`, `DirectBurnAdapter`, `MysteryBox`, one `PrizeVault` | 46630 |
| Ethereum | 1 | `PrizeVault` | Sepolia 11155111 |
| ApeChain | 33139 | `PrizeVault` | Curtis 33111 |
| Base | 8453 | `SeedRequester` (Chainlink VRF v2.5) | Base Sepolia 84532 |

Robinhood Chain stores the bears and is the source of truth for ownership, levels, whitelist
claims and raffle entries. Prizes stay on the chain where MINT holds them. Randomness comes from
Base, which has Chainlink VRF v2.5 and which MINT already uses; Ethereum has it too, ApeChain and
Robinhood Chain do not (checked 18 September 2026).

**Contracts.**

| Contract | Chain | Purpose |
|---|---|---|
| `MintABear` | 4663 | ERC721SeaDrop collection, 4,444 supply, transfer counter, enforced royalties |
| `WhitelistClaim` | 4663 | 1,000 first-come-first-served whitelist allocations against signed eligibility |
| `Activation` | 4663 | Credited burns → level → weight; Status link |
| `DirectBurnAdapter` | 4663 | Burns $MNTD and credits the bear in one transaction |
| `MysteryBox` | 4663 | Rounds, per-bear entries, seed intake, draw, winners root |
| `PrizeVault` | 4663 · 1 · 33139 | Prize inventory, locking per round, claims by winners |
| `SeedRequester` | 8453 | Requests one VRF word per round; the fulfilment is the public seed |

**Trust model.** Contracts enforce ownership, supply, the transfer counter, level derivation, the
weights table, the whitelist count and per-wallet caps, raffle entries, prize locking, the draw
and claims. MINT holds two keys with narrow powers. The **eligibility signer** decides *who* may
claim a whitelist spot; the contract decides *how many* and *in what order*. The **worker**
supplies inputs the contracts cannot obtain themselves — deposit registration, round timing, and
two relayed values per round: the VRF seed from Base and the winners root to each vault. Both
relayed values are publicly checkable: the seed against the fulfilment event on Base, the root
against the hub's awards on Robinhood Chain. The worker cannot alter weights or thresholds,
raise a level without a burn, add or remove an entry, change who won, move a locked or won
prize, or create a whitelist spot.

**On-chain.** Ownership and transfers; the transfer counter and its event; whitelist claims and
the live spot count; credited burns, cumulative totals, levels and weights; Status nominations;
raffle entries, seeds, awards and roots; prize inventory and its states; claims.

**Off-chain (MINT).** Wager measurement and the Season 1 back-credit; the Privy login that ties
a wallet to a mint.io account; the royalty pot and its split — when the pot reaches its ETH cap
or its countdown ends, half the ETH buys $MNTD, and ETH and $MNTD move to a splitter wallet that
credits mint.io accounts by wallet weight (ACT-10); crediting an account requires knowing which
account a holding wallet belongs to, which the Privy login supplies and the chain does not; the
Status boost; indexing, alerts and the UI. What level 5 is *worth* is MINT's to define; the
chain records that it was reached.

**Flow.** (1) Whitelist campaign: a holder wagers on mint.io and logs in on getminted.io; MINT's
backend signs a voucher; the holder claims a spot on `WhitelistClaim`; at close MINT loads the
list into the Studio allowlist stage. (2) Iñigo runs the drop in Studio; holders mint via OpenSea
or the getminted.io mirror. (3) Holders burn $MNTD through the adapter; `Activation` credits the
bear and its level and weight follow. (4) Any transfer advances the counter and voids level,
weight and link. (5) A mystery box round: MINT deposits prizes into the vaults; the worker locks
them and opens the round; holders enter their bears; entries close; the seed arrives from Base;
the hub draws; the worker posts the root to each vault; winners claim; unclaimed prizes expire
back into inventory. (6) MINT reads `Activation.snapshot` at each royalty closing block and
splits the pot off-chain.

## 3. Collection contract — MintABear (COL)

**COL-1 Base.** `MintABear` extends OpenSea's `ERC721SeaDrop` with its mint path,
`getMintStats`, metadata and royalty interfaces unchanged. Canonical SeaDrop
`0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` is the only allowed minter. The drop is configured
and operated through OpenSea Studio by MINT (COL-11).

**COL-2 Supply.** `MAX_BEARS = 4444` is a constant enforced on the mint path; a mint that would
exceed it reverts with `ExceedsMaxBears`. The inherited `maxSupply` must be set to exactly 4,444
and never raised: a higher value advertises a supply the token will not deliver and buyers past
the cap pay for reverted transactions. Team, treasury, partner and whitelist bears all come out
of the same 4,444. Because no bear can be destroyed (COL-8), the supply is exactly 4,444 once
minted out.

**COL-3 Transfer counter.** `transferNonce(tokenId)` increments on every transfer except mint —
sales, gifts, self-initiated moves and return transfers to a previous owner alike — and never
resets. It is the mechanism by which every ownership change resets level, weight and Status
link (ACT-5).

**COL-4 Reset event.** `TransferNonceAdvanced(uint256 indexed tokenId, uint64 nonce)` is
emitted for every non-mint transfer, in the same transaction as `Transfer`. It is the
activation-reset event: anything `Activation` recorded at the previous counter value is void
once it fires. It fires whether or not a level existed.

**COL-5 Metadata.** Standard SeaDrop metadata: `baseURI` set through Studio,
`tokenURI(id) = baseURI + id`, provenance hash committed with `setProvenanceHash` before the
mint opens. Placeholder JSON, reveal and hosting are MINT's. Artwork is immutable and metadata
does not vary with level.

**COL-6 Royalties.** ERC-2981 through SeaDrop's `setRoyaltyInfo`: **5% (500 basis points)**,
receiver the royalty-pot address MINT names, distinct from the admin and from every vault. Set
by Iñigo in Studio at any point before the first sale; it does not hold up deployment. `→ CQ-15`
(receiver).

**COL-7 Creator token and enforced royalties.** `MintABear` implements `ICreatorToken` (ERC-721C)
and is deployed with the transfer validator **set**:
`setTransferValidator(0x721C002B0059009a671D00aD1700c9748146cd1B)`, Limit Break validator V3 on
4663, with the validator's zero-state policy — security level 0 (operator whitelist,
holder-initiated transfers always allowed, no receiver constraint) and list 0 (Limit Break
Payment Processor whitelist with OpenSea's SignedZone `0x000056F7000000EcE9003ca63978907a00FFD100`
as authorizer). Consequence: a transfer initiated by the holder always passes; a sale settles only
through OpenSea (SignedZone-restricted orders) or a Payment Processor marketplace, and creator
earnings are collected on every such sale; a Seaport order from any other venue reverts.
Security levels 5 and above additionally restrict contract receivers and are not used. OpenSea's
handling of a validated collection on this chain has not been observed, so the switch is proven
in two steps: on testnet 46630 with Studio (OPS-4), and on mainnet with a listing and sale of a
team bear before the drop page is published. If OpenSea cannot fill orders, one owner call,
`setTransferValidator(address(0))`, lifts enforcement until OpenSea confirms, and one call
restores it (OPS-6).

**COL-8 No burn.** The transfer hook refuses `to == address(0)` with `BurnDisabled`, so
`ERC721SeaDrop.burn` always reverts and no bear can be destroyed by anyone, its owner included;
`totalSupply` never falls. A bear sent to an address nobody controls (for example `0x…dEaD`)
remains a bear in the supply: nobody can enter it in a raffle (RAF-21), and the royalty snapshot
excludes the canonical dead address (ACT-10).

**COL-9 No token-bound accounts.** ERC-6551 is not part of the collection. It can be added later
without any change to `MintABear`: the canonical registry
`0x000000006551c19487814612e58FE06813775758` derives an account address from
`(chainId, tokenContract, tokenId)` for any ERC-721. The one property that cannot be retrofitted
is a token-side guard against sending a bear into a bear's account.

**COL-10 Ownership.** Deployed by Calea; ownership transferred to MINT's admin address by the
inherited two-step process (`transferOwnership`, then `acceptOwnership` from the admin) before
the drop page is published. Calea retains no role.

**COL-11 What Studio owns.** Mint stages, dates and pricing; allowlists and per-wallet limits,
including the whitelist stage loaded from `WhitelistClaim` (WL-4); payout address; `maxSupply`
(COL-2); `baseURI` and provenance (COL-5); royalty info (COL-6); `multiConfigure`. A
"guaranteed" stage is guaranteed by stage sequencing — the guaranteed window must close before
the next window opens — not by the contract.

**COL-12 Reads.** `ownerOf`, `exists(tokenId)`, `totalSupply`, `maxSupply`, `MAX_BEARS`,
`transferNonce`, `tokenURI`, `royaltyInfo`, `getTransferValidator`, `getMintStats`, plus the
ERC-721 and SeaDrop standard surface.

**COL-13 Events.** Standard `Transfer`, `Approval`, `ApprovalForAll`; SeaDrop configuration
events; `TransferNonceAdvanced` (COL-4); `TransferValidatorUpdated` (COL-7).

## 4. Whitelist claim (WL)

**WL-1 Rules.** From MINT's brief, as the contract enforces them:

- **1,000 spots**, each the right to mint one bear in the whitelist stage. A spot is an
  allocation: a wallet at $100 holds two of the 1,000 (`→ CQ-18` confirms this reading).
- **First come, first served** through getminted.io/mintabear. Reaching a threshold makes a
  wallet eligible; it reserves nothing. An allocation belongs to a wallet only once its claim
  transaction has succeeded.
- **$50 wagered unlocks allocation 1; $100 unlocks allocation 2.** Historical wagering (Season 1,
  back-credited) counts up to $50, so allocation 2 always requires at least $50 of in-campaign
  wagering. Who has wagered what is MINT's data (WL-2).
- **Live counter** "wagering spots left — X / 1,000", read from the contract. A claim that
  arrives after the last spot fails whole; there is no partial state.
- **The holder selects the NFT wallet** before claiming and may change it until the claim; the
  claim is made for that wallet. One call to action per unlocked allocation: a holder at $75
  claims one now and the second later.
- **Two per wallet, two per account.** A mint.io account cannot spread more than two allocations
  over several wallets.

**WL-2 Division of work.** MINT: the Privy mirror login on getminted.io; the wager API that
returns, for the logged-in account, historical wagering capped at $50 and in-campaign wagering;
the eligibility checker; the UI; and the **eligibility signer**, a backend key that signs a
voucher when the API confirms a threshold. Calea: the `WhitelistClaim` contract, the voucher
format, the export to the Studio allowlist, and the client calls (DEL-6).

**WL-3 Registry.** `WhitelistClaim` on Robinhood Chain (`→ CQ-18`; WL-6 is the alternative). A
voucher is an EIP-712 message `Claim(address wallet, uint8 allocationIndex, bytes32 account,
uint256 deadline)` signed by the eligibility signer, with a short `deadline` (minutes) and
`account` a hash of the mint.io account id, so the chain carries no personal data.
`claim(voucher, signature)` reverts unless: the signature is the signer's (`BadSigner`);
`block.timestamp ≤ deadline` (`Expired`); the campaign window is open (`CampaignClosed`);
`spotsLeft() > 0` (`SoldOut`); `allocationIndex == claimsOf(wallet) + 1` (`WrongAllocation`), so
allocations are claimed in order and at most twice; `accountClaims(account) < 2`
(`AccountLimit`). Effects: the wallet's and the account's counts increase, the spot counter
increases, the wallet is appended to the claimant list, and `WhitelistClaimed(wallet,
allocationIndex, account, spotNumber)` is emitted. By default the claim is sent by the wallet
itself, which pays Robinhood Chain gas — it needs gas for the mint anyway; in the relayed
variant MINT's worker submits the voucher and pays, with the same contract and `msg.sender`
unrestricted (`→ CQ-18`). Reads: `TOTAL_SPOTS`, `spotsLeft()`, `claimsOf(wallet)`,
`accountClaims(account)`, `claimants(offset, limit) → (wallet, allocations)[]`, `openAt`,
`closeAt`, `signer`. Owner (MINT admin): `setSigner`, `setWindow(openAt, closeAt)`, ownership
transfer. Nobody can remove or reassign a claim.

**WL-4 Into the mint.** After the window closes or the spots sell out, MINT exports the claimant
list — one row per wallet with its allocation count — and loads it as the whitelist stage's
allowlist in Studio. SeaDrop allowlist entries carry a per-wallet mint limit, so "one or two" is
enforced by the mint itself. The getminted.io mirror builds its Merkle proofs from the same list
(DEL-6). The registry is public, so a loaded list that differs from it is detectable by anyone.

**WL-5 Timing.** The registry is deployed and its signer set before the campaign opens; the
campaign closes at least 48 hours before the whitelist stage opens, for the export, the Studio
import and the publication of proofs. Dates `→ CQ-18`; calendar in §8.

**WL-6 Alternative — off-chain register.** MINT's backend records claims in its database behind
an atomic counter; Calea supplies the claim-API contract and the Studio export script and deploys
nothing. Faster to build and free of gas for holders; the order of claims and the sell-out rest
on MINT's server, nothing is publicly checkable, and the SeaDrop allowlist root is the only trace
on-chain. `→ CQ-18`.

## 5. Activation and burn route (ACT)

**ACT-1 Token-agnostic.** `Activation` holds no reference to $MNTD and never moves tokens. It
records credited burn amounts per bear and derives level and weight from them. It reads
`MintABear` (`ownerOf`, `transferNonce`, `exists`); `MintABear` never calls it, so no defect in
`Activation` can affect a transfer. In plain terms: burning the tokens and recording the level
are two steps of one transaction. The adapter burns the holder's $MNTD, then tells `Activation`
"this wallet burned this amount for this bear"; `Activation` accepts that message from the
adapter alone. If $MNTD ever changes address or chain, only the adapter changes.

**ACT-2 Thresholds.** Five cumulative thresholds `T1 < T2 < T3 < T4 < T5`, in $MNTD base units,
supplied to the constructor and immutable. A bear's level is the highest `k` with
`cumulative ≥ Tk`, or 0. `thresholdFor(level)` and `costToReach(tokenId, level)` expose them.
MINT's figures are 1,666 / 3,333 / 8,333 / 16,666 / 41,666 $MNTD, "burn rate per tier". The
contract stores the total burned to reach each level; the figures admit two readings and MINT
chooses one (`→ CQ-4`):

| Level | MINT's figure | Cumulative reading (recommended): total to reach the level | Per-level reading: total to reach the level |
|---|---|---|---|
| 1 | 1,666 | 1,666 | 1,666 |
| 2 | 3,333 | 3,333 | 4,999 |
| 3 | 8,333 | 8,333 | 13,332 |
| 4 | 16,666 | 16,666 | 29,998 |
| 5 | 41,666 | 41,666 | 71,664 |

Under the cumulative reading a bear reaches level 5 after 41,666 $MNTD in total; under the
per-level reading after 71,664. The constructor receives the chosen right-hand column in base
units, which fixes $MNTD's `decimals` before deployment (`→ CQ-2`).

**ACT-3 Weights.** Six royalty weights for levels 0–5, basis 100, supplied to the constructor
and immutable: `100 / 110 / 125 / 145 / 170 / 200` (1.00× to 2.00×), confirmed by MINT.
`weightFor(level)` returns the table entry; `weightOf(tokenId)` returns the weight of the bear's
current level.

**ACT-4 Credit.** `credit(uint256 tokenId, address burner, uint128 amount, uint64 nonce,
bytes32 ref)` is callable only by the `crediter` (ACT-7). It reverts unless: not paused;
`amount > 0`; `ownerOf(tokenId) == burner`; `transferNonce(tokenId) == nonce`; `ref` has not
been used. Both ownership checks passing means `burner` has owned the bear continuously since
`nonce` was read — a burn is never credited to a bear that changed hands in between. Effects:
the cumulative for the current counter value increases by `amount`; `lifetimeBurned` increases
by `amount`; `ref` is marked used; `BearActivated(tokenId, burner, previousLevel, newLevel,
amount, cumulative, ref)` is emitted.

**ACT-5 Reset.** Cumulative, level, weight and link read as zero whenever the counter value
they were recorded at differs from the current `transferNonce`. The reset is a consequence of
the transfer (COL-3), not an action: it cannot be skipped and cannot block a transfer. Return
transfers reset like any other.

**ACT-6 Lifetime.** `lifetimeBurned(tokenId)` accumulates every credit ever made to a bear and
never resets.

**ACT-7 Crediter and route.** Exactly one `crediter` address, set by the owner (`setCrediter`,
event `CrediterSet`). $MNTD is deployed on Robinhood Chain (MINT), so the crediter is the
**`DirectBurnAdapter`** on 4663. The holder approves the adapter on $MNTD once and calls
`burn(tokenId, amount)`; the adapter reverts unless `ownerOf(tokenId) == msg.sender`
(`NotOwner`), the bear is below level 5 (`AlreadyAtMaxLevel`) and
`amount ≤ costToReach(tokenId, 5)` (`Overshoot`); it then calls `MNTD.burnFrom(msg.sender,
amount)` and `Activation.credit(tokenId, msg.sender, amount, transferNonce(tokenId), ref)` in
the same transaction, with `ref` a per-adapter burn number, and emits `BurnedForBear(ref,
tokenId, burner, amount)`. The adapter has no owner and no settings; a new token address means a
new adapter and one `setCrediter` call. Requirements on $MNTD: an ERC-20 on 4663 exposing
`burnFrom(address, uint256)` (OpenZeppelin `ERC20Burnable`) with `decimals` fixed before
`Activation` is deployed. What the token on 4663 *is* decides what a burn means (`→ CQ-2`):
native canonical supply; a bridged representation, whose burn strands the canonical amount in
the bridge; or a mint-and-burn bridge token, whose burn reduces global supply. A burn on Base
with an attested credit on 4663, and cross-chain messaging, are not selected.

**ACT-8 Overshoot.** The adapter refuses any amount beyond what level 5 needs, so no $MNTD is
destroyed for nothing. The portal sizes each burn with `costToReach(tokenId, targetLevel)`,
which returns the exact remainder or zero.

**ACT-9 Status link.** `linkBear(tokenId)`, owner of the bear only, one nomination per wallet,
recorded with the current counter value; `unlinkBear()` clears it and is safe to call when
nothing is linked; `linkOf(wallet) → (tokenId, level)` returns `(0, 0)` when nothing is linked
or the bear has since moved. A wallet aggregates royalty weight across all its bears (ACT-10)
but carries exactly one Status boost; the boost's value is MINT's, off-chain.

**ACT-10 Snapshot view.** `snapshot(uint256[] ids) → (address owner, uint8 level, uint16
weight)[]`, returning zeroes for ids that do not exist. MINT's royalty accounting reads it for
`1..4444` at each closing block; a wallet's weight is the sum over its bears and the total
eligible weight is the sum over all bears whose owner is not the canonical dead address
`0x000000000000000000000000000000000000dEaD` (COL-8). Because transfers reset weight without any
call into `Activation`, there is no on-chain running total; the sum is taken off-chain from
this view. A reference script reproducing the split, dead-address exclusion included, is
delivered (DEL-6); MINT credits the resulting shares to mint.io accounts through its splitter
wallet (§2).

**ACT-11 Pause.** The owner may pause. While paused, `credit` and `linkBear` revert; reads,
`unlinkBear` and every transfer are unaffected. The adapter's `burn` therefore reverts while
paused and no $MNTD is burned; this is how burns stay closed to holders between deployment and
the switch-on date (§8). `renounceOwnership` is refused while paused, so a pause can always be
lifted.

**ACT-12 Roles.** Owner (MINT admin): `setCrediter`, `setPaused`, ownership transfer. Nothing
else is administrable: thresholds, weights and records are immutable; the adapter has no owner.
There is no freeze or clawback path into a bear anywhere (MINT, CQ-16).

**ACT-13 Events.** `BearActivated` (ACT-4), `BearLinked(wallet, tokenId)`,
`BearUnlinked(wallet, tokenId)`, `CrediterSet(previous, current)`, `PausedSet(paused)`;
adapter: `BurnedForBear(ref, tokenId, burner, amount)`.

**ACT-14 Reads.** `levelOf`, `cumulativeOf`, `lifetimeBurned`, `weightOf`, `weightFor`,
`thresholdFor`, `costToReach`, `linkOf`, `snapshot`, `paused`, `crediter`, `BEARS`; adapter:
`MNTD`, `ACTIVATION`, `burnCount`.

## 6. Mystery box raffle (RAF)

A holder opens a mystery box by entering a bear into a round; each bear is one entry per round.
The round draws once from a Chainlink seed, and each winner claims the prize on the chain where
it sits. Three contracts: the `MysteryBox` hub on Robinhood Chain — where the bears are, so
entries are checked against live ownership; a `PrizeVault` on every chain that holds prizes;
`SeedRequester` on Base. This is the architecture Calea recommends and builds by default; the
alternatives are in §10 D5 (`→ CQ-8`, `→ CQ-9`).

**RAF-20 Hub.** `MysteryBox` on Robinhood Chain runs rounds. The worker opens one with
`openRound(roundKey, entryOpen, entryClose, minLevel, claimWindow, nominationWindow,
manifest)`. The **manifest** is the ordered prize list `(chainId, vault, prizeIndex)` of
everything the vaults locked for `roundKey` (RAF-6): chains in the fixed order 4663 → 1 → 33139
and, within a vault, ERC-721 prizes in registration order, then baskets in asset-approval order.
It is fixed and public before any entry. A round with no prizes cannot open; at most one round
accepts entries at a time. States: Open (entries) → Closed (awaiting seed) → Drawn → Finalized;
or Cancelled.

**RAF-2 Addresses.** Each `PrizeVault` is the dedicated deposit address on its chain, separate
from the royalty pot and from the admin. The hub holds no assets.

**RAF-3 Asset approval.** The owner approves each asset on each vault once: `approveAsset(token,
kind, basketSize)` with `kind ∈ {ERC20, ERC721}`; `basketSize` is in base units for ERC-20 (for
$MNTD on Robinhood Chain, 5,000 × 10^decimals) and ignored for ERC-721, where each token is its
own prize. `revokeAsset` stops an asset entering future rounds and never touches locked or won
prizes. Unapproved assets never enter a round. ERC-1155 is not supported.

**RAF-4 Intake.** Deposits are plain transfers to a vault. Nothing happens until the worker
registers them: `registerERC721(token, id)` requires `ownerOf(id) == vault` and the id not yet
tracked; `syncERC20(token)` adds `balanceOf(vault) − tracked` to unreserved inventory. Token
transfers alone never change round state. Each registration emits `DepositRegistered`.

**RAF-5 Inventory states.** Unreserved → locked (for a round) → won → claimed; or won → expired
→ unreserved; or locked → unreserved when the round is cancelled or the prize is not awarded.
Locked and won prizes cannot be withdrawn, reused, swept or moved by anyone but the winner,
paused or not.

**RAF-6 Locking for a round.** Before a round opens, the worker calls `lockForRound(roundKey)`
on each vault that holds prizes for it: every unreserved full basket of every approved ERC-20
and every unreserved registered ERC-721 locks for `roundKey`; ERC-20 remainders below a basket
stay unreserved; the vault emits `RoundLocked(roundKey, prizes[])` with its ordered list.
Deposits registered afterwards wait for the next round. The hub's manifest (RAF-20) is the
concatenation of the vaults' lists, and a manifest that differs from the vaults' events is
detectable by anyone. MINT fills the vaults with exactly the prizes a round should carry, then
the worker locks and opens.

**RAF-21 Entry.** `enter(roundId, tokenIds[])` during the entry window, by the wallet that is
`ownerOf` each bear at that moment, with `Activation.levelOf(tokenId) ≥ minLevel`; a bear enters
a round once (`AlreadyEntered`). Entry is free apart from gas. Each entered bear is one ticket
for the entering wallet, and the entry belongs to that wallet for the rest of the round: the bear
is "spent" for the round, stays freely transferable, and its new owner cannot enter it again
until the next round. `triesLeft(roundId, wallet)` returns the wallet's bears not yet entered —
a wallet with ten bears and two entered sees eight. `BoxEntered(roundId, tokenId, wallet)` is
emitted per bear.

**RAF-8 Randomness.** Chainlink VRF v2.5 on Base (coordinator
`0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634`) through `SeedRequester`: one request and one word
per round, subscription owned and funded by MINT with `SeedRequester` as consumer (`→ CQ-17`).
Ethereum's coordinator `0xD7f86b4b8Cae7D942340FF628F82735b7a20893a` is the alternative host.
ApeChain has no Chainlink VRF; Robinhood Chain has none and no usable `prevrandao`.

**RAF-22 Seed.** After `entryClose` the worker requests the round's word from `SeedRequester`,
which stores it and emits `SeedFulfilled(roundKey, seed)`, and relays it with
`submitSeed(roundId, seed)`. The hub accepts one seed per round and only after entries are
closed: nobody can enter knowing the seed, and the worker cannot choose a seed to fit the entries
— it can only relay what Base produced, and anyone can compare the two events. Entries → seed →
draw is commit-before-randomness with the entries themselves as the commitment.

**RAF-23 Draw (normative).** Inputs: the round's tickets `T` (entered bears in entry order),
the manifest `P`, the seed `s`, an attempt counter `k` starting at 0. For prize `i` from 0 to
`|P|−1`: if no ticket remains, stop; `r = uint256(keccak256(abi.encode(s, k))) mod |T|`;
`k += 1`; the ticket `T[r]` names the wallet that entered it; if that wallet has already won in
this round, remove `T[r]` and repeat for the same `i`; otherwise award prize `i` to the wallet,
remove `T[r]`, emit `PrizeAwarded(roundId, i, winner)` and continue with `i+1`. Removal is
swap-with-last. Properties: each prize goes to a wallet drawn in proportion to its entered bears
among wallets that have not yet won this round; winners are distinct; a wallet wins at most one
prize per round; twenty bears are twenty chances at the first prize. `draw(maxSteps)` is
resumable, so a round of any size completes within the chain's per-transaction gas limit. When
tickets run out before prizes do, the rest carry forward (RAF-10). After the nomination window
(RAF-25), `finalize(roundId)` computes `winnersRoot`, the Merkle root of
`keccak256(roundKey, prizeIndex, recipient)` over awarded prizes, and emits
`RoundFinalized(roundId, winnersRoot)`.

**RAF-10 Carry forward.** Prizes not awarded because tickets ran out are released to unreserved
inventory when their vault receives the round's root (RAF-24) and lock into the next round;
`PrizesCarriedForward(roundId, prizeIndexes)` on the hub, `PrizesReleased` on the vault.

**RAF-24 Prize vaults.** One `PrizeVault` code, deployed on every chain that holds prizes.
Lifecycle: approval (RAF-3), intake (RAF-4), `lockForRound(roundKey)` (RAF-6);
`setWinnersRoot(roundKey, root)` by the worker — once, and anyone can check that it equals the
hub's `winnersRoot` — which also releases the round's unawarded prizes (RAF-10);
`claim(roundKey, prizeIndex, proof)` by the recipient (RAF-11); `expirePrize` (RAF-11);
`cancelRound(roundKey)` (RAF-12); `sweep` (RAF-14).

**RAF-25 Recipient nomination.** Winners claim on Ethereum or ApeChain from the address that
entered on Robinhood Chain. An address that is a contract wallet on Robinhood Chain may not exist
elsewhere, so for `nominationWindow` after the draw (default 24 hours; the worker may set 0) a
winner may call `nominateRecipient(roundId, prizeIndex, recipient)` on the hub; the root then
carries the recipient, which defaults to the winner. The UI warns contract-wallet holders before
they enter.

**RAF-11 Claims.** `claim(roundKey, prizeIndex, proof)` on the vault holding the prize: caller is
the recorded recipient; the prize is unclaimed; `block.timestamp ≤ rootSetAt + claimWindow`,
with `claimWindow` **30 days** (MINT). The prize — ERC-20 basket or ERC-721 — is transferred to
the caller. Claims are single-use and non-transferable, and the right belongs to the entering
wallet regardless of what it does with its bears afterwards. After the window `expirePrize`
(anyone) returns the prize to unreserved inventory for the next round — MINT treats an unclaimed
prize as renounced; a claimed prize never expires.

**RAF-12 Cancellation.** The owner may cancel a round on the hub while it is Open or Closed
without a seed (randomness failure); the worker then calls `cancelRound(roundKey)` on each vault,
releasing its locked prizes, and a late seed is ignored. Once drawn, nothing about a round can
change.

**RAF-13 Eligibility.** Round 1 uses `minLevel = 0`: ownership only. Later rounds may set
`minLevel`, checked live at entry (RAF-21). Rounds gated on MINT Status are out of scope: Status
is off-chain data that no chain can verify, so such a round would be a "curated" round whose
eligibility list MINT signs and publishes — a different trust model, and it must be visibly
labelled as one.

**RAF-14 Roles.** Owner (MINT admin): `approveAsset`, `revokeAsset`, `setWorker`,
`cancelRound`, `setPaused`, `sweep`. `sweep` moves unapproved tokens and unreserved inventory
out of a vault, with an event, **only while that vault has no round locked**: from
`lockForRound` until the round's root is set or the round is cancelled nothing leaves the vault
except to winners (MINT), and won prizes stay locked until claimed or expired regardless.
Worker (MINT automation): `registerERC721`, `syncERC20`, `lockForRound`, `openRound`,
`submitSeed`, `draw`, `finalize`, `setWinnersRoot`. Anyone: `enter` as a bear's owner, `claim`
as a recipient, `expirePrize`, all reads.

**RAF-15 Pause.** Pausing the hub blocks `openRound`, `enter`, `submitSeed`, `draw` and
`finalize`; pausing a vault blocks registration and locking. Neither blocks `claim`,
`expirePrize` or `nominateRecipient`.

**RAF-16 Events.** Hub: `RoundOpened(roundId, roundKey, entryOpen, entryClose, minLevel,
claimWindow, prizeCount)`, `BoxEntered`, `EntriesClosed`, `SeedSubmitted(roundId, seed)`,
`PrizeAwarded`, `PrizesCarriedForward`, `RecipientNominated`, `RoundFinalized`,
`RoundCancelled`, `WorkerSet`, `PausedSet`. Vault: `AssetApproved`, `AssetRevoked`,
`DepositRegistered`, `RoundLocked`, `WinnersRootSet(roundKey, root)`, `PrizeClaimed`,
`PrizeExpired`, `PrizesReleased`, `RoundCancelled`, `Swept`, `WorkerSet`, `PausedSet`.
`SeedRequester`: `SeedRequested(roundKey, requestId)`, `SeedFulfilled(roundKey, seed)`.

**RAF-17 Reads.** Hub: round state, times, `minLevel`, `claimWindow`, manifest, prize by index
(chain, vault, prizeIndex, winner, recipient), `entered(roundId, tokenId)`,
`triesLeft(roundId, wallet)`, `ticketCount(roundId)`, `winnersRoot(roundId)`. Vault: unreserved
inventory per asset, the locked round, prize by index (asset, id or amount, state),
`claimable(roundKey, wallet)`, `isApproved(token)`. `SeedRequester`: `seedOf(roundKey)`.

**RAF-18 Worker sequence.** Register deposits → lock each vault → open the round with the
manifest → holders enter → entries close → request the seed on Base → relay it → draw in
chunks → nomination window → finalize → set the root on each vault → publish results → after
the window, expire unclaimed prizes. MINT's UI shows inventory, tries left, entries, results
and claims, and is hidden while no round is open.

**RAF-19 Acceptance cases (from the SoW, adapted).** Token baskets group correctly; two NFTs
from one collection go to two different wallets; a deposit after locking waits for the next
round; locked prizes cannot be withdrawn or reused; fewer entered wallets than prizes carries the
excess forward; a randomness failure is cancelled and reserves released; a wallet with many bears
wins at most once and a bear counts once; a winner who sells the bear after entering still
claims; a bear sold after entering cannot be re-entered by the buyer; a relayed seed that differs
from Base's fulfilment is detectable; a root that differs from the hub's is detectable; a prize
on ApeChain is claimed with the hub's root.

**Retired identifiers.** RAF-1 (a single raffle chain) → RAF-20 and RAF-24; RAF-7 (passive
ownership snapshot) → RAF-21; RAF-9 (draw over calldata entries) → RAF-23.

## 7. Operations, roles and handover (OPS)

**OPS-1 Addresses.** Recorded before mainnet deployment (`→ CQ-12`, `→ CQ-15`):

| Role | Holds | Recommendation |
|---|---|---|
| Admin | owner of every contract on every chain | Safe multisig controlled by Iñigo; one EOA per chain if Safe's interface does not cover a chain |
| Worker | `MysteryBox`, every `PrizeVault`, `SeedRequester` | EOA held by MINT automation, funded on each chain |
| Eligibility signer | `WhitelistClaim.signer` | Backend key held by MINT; rotatable by the admin |
| Royalty receiver | ERC-2981 receiver — the pot | MINT, separate from the admin |
| Prize vaults | the `PrizeVault` contracts, one per prize chain | — |

`DirectBurnAdapter` has no role.

**OPS-2 Deployment order.** Robinhood Chain: `MintABear(name, symbol, [SeaDrop])` →
`setMaxSupply(4444)` → `setTransferValidator(V3)` (COL-7) → provenance, `baseURI`, royalties
through Studio → two-step ownership transfer. `WhitelistClaim(signer, openAt, closeAt)` →
ownership, before the campaign opens. `Activation(bears, thresholds, weights)` →
`DirectBurnAdapter(mntd, activation)` → `setCrediter(adapter)` → `setPaused(true)` until the
switch-on date → ownership; requires $MNTD on 4663. `MysteryBox(bears, activation, worker)` →
ownership; `PrizeVault(worker)` → `approveAsset` per prize asset → ownership. Ethereum and
ApeChain: `PrizeVault(worker)` → approvals → ownership. Base: `SeedRequester(coordinator,
subscriptionId, keyHash, worker)` → added as consumer → ownership. Each contract is deployed
before the page that depends on it is published.

**OPS-3 Verification.** Sourcify for 4663 and 46630 (mainnet Blockscout's API sits behind a bot
challenge); Etherscan for Ethereum and Sepolia; Apescan for ApeChain and Curtis; Basescan for
Base and Base Sepolia.

**OPS-4 Rehearsal on testnets (46630, Sepolia, Curtis, Base Sepolia).** Studio attaches to and
manages a self-deployed, validated `MintABear`; both mint paths (OpenSea and the getminted.io
mirror); a whitelist claim from voucher to exported allowlist to a two-per-wallet allowlist mint;
a burn through the adapter against $MNTD on 46630 through to a credited level; a full
multi-chain round — deposits on three testnets, lock, open, entries, seed, draw, root, claim,
expiry; an OpenSea testnet listing of the validated collection. On mainnet, before the drop page
is published: one team bear listed and sold on OpenSea (COL-7).

**OPS-5 Handover.** Calea deploys, configures, transfers ownership, verifies source, and delivers
the runbook; after that it holds no key and no role. Technical support runs through
19 November 2026 with agreed response hours (DEL-10).

**OPS-6 Enforcement runbook.** Enabled at deployment: `MintABear.setTransferValidator(0x721C002B…)`
with the validator's zero-state policy. Optional, from the admin: `createList`,
`addAccountsToWhitelist`, `addAccountsToAuthorizers`, `applyListToCollection`,
`setTransferSecurityLevelOfCollection` (never level 5 or above). Disable:
`setTransferValidator(address(0))`. Every step is an owner call and reversible.

**OPS-7 Chain constraints.** On Robinhood Chain `block.number` is the L1 height — contracts and
scripts key on timestamps. Sequencer-level compliance screening can block an individual
holder's transactions, so nothing in the system requires a holder to act by a deadline in
order for the system to stay correct: an unclaimed prize expires back to inventory, a missed
entry window is a missed round, and nothing else depends on either. Robinhood Chain applies an
Arbitrum-style per-transaction gas limit, which is why the draw is resumable in chunks.
Randomness is not available on Robinhood Chain or ApeChain, which is why the seed comes from
Base.

## 8. Calendar (CAL)

Three anchors are fixed by MINT: TGE on 20 October, the mint on 29 October, and burns, level-up
and the first mystery box round starting on 29 October. Every other row is derived from the SoW
and marked *proposed* until MINT confirms it (`→ CQ-1`).

| Date (2026) | Outcome | Lead | Basis |
|---|---|---|---|
| 21 Sep | Call: the decisions in §10 | Iñigo; Calea | fixed |
| 22 Sep – 2 Oct | `MintABear` final, reviewed, deployed with the validator set; OpenSea page and URL live before promotion; team bear listed and sold; `WhitelistClaim` deployed and signer set; Studio attach proven on testnet | Calea; Iñigo | SoW |
| by 5 Oct | $MNTD test deployment on 46630 for the adapter rehearsal | MINT (Lorenzo) | proposed |
| 6 – 26 Oct | Whitelist campaign open on getminted.io/mintabear | Iñigo; Javier; Vlad; Lorenzo | proposed |
| 5 – 9 Oct | Hub, vaults, seed requester, worker and UI tested on testnets, baskets and unique winners included; reports and runbooks; no open Critical/High | Calea; Javier; MINT | SoW |
| 12 – 14 Oct | Hub and vaults deployed, verified and funded on every prize chain; roles and official addresses verified; a multi-chain round rehearsed | Calea; Iñigo; Javier; MINT | SoW |
| 20 Oct | TGE: $MNTD live on Robinhood Chain; `Activation` and `DirectBurnAdapter` deployed, verified against the real token, paused | MINT; Calea | MINT |
| 20 – 28 Oct | Real burns rehearsed by MINT and Calea on mainnet; Activation stays paused to holders | Calea; MINT | derived |
| 26 Oct | Whitelist campaign closes; list exported, loaded into the Studio whitelist stage, proofs published | Iñigo; Calea | proposed |
| 29 Oct | Mint: whitelist stage, then the other stages per Studio; `Activation` unpaused — burns, level-up and Status linking open; round 1 entries open | Iñigo; Javier; Calea | MINT |
| 1 Nov | Round 1 entries close; seed; draw; results published | MINT worker; Calea | proposed |
| 2 Nov – 1 Dec | Round 1 claims on each prize chain; expiry and roll-over afterwards | Winners; MINT worker | proposed |
| 5 Nov | First royalty closing block and pot split; weekly after | MINT | SoW; to confirm |
| 19 Nov | Operations handed over; support continues per DEL-10 | Iñigo/Robert; Calea | SoW; to confirm |

Two decouplings hold whatever moves: the collection deploys and mints without the hub, the
vaults or the adapter being live, and `Activation` stays paused until the adapter has been
exercised against real $MNTD. One compression to note: burns open nine days after TGE, so the
mainnet rehearsal against the real token has that window; the testnet deployment on 5 October
takes the pressure off it.

## 9. Deliverables and acceptance (DEL)

**DEL-1 Source.** Warning-free `forge build`; Slither with no High or Critical finding, every
accepted Medium documented.

**DEL-2 Tests.** Deterministic unit and integration tests with a branching tree per contract;
at least 90% line coverage.

**DEL-3 Review report.** Static and manual review, plus fuzzing and invariant harnesses written
and run by Calea's internal auditor independently of the developer; every Critical and High
finding fixed before mainnet deployment; report delivered with the tranche.

**DEL-4 Testnet.** Verified addresses on 46630, Sepolia, Curtis and Base Sepolia for every
contract.

**DEL-5 Scripts and runbook.** `forge script` deployments and configuration for each chain,
source verification, and a runbook covering deploy order, role handover, enforcement toggle,
pause, the whitelist export, and the worker sequence.

**DEL-6 Integration package.** Interfaces, events, roles and calldata examples for every
contract; a typed client library for getminted.io covering mint (SeaDrop stages, allowlist
proofs, `mintPublic`), whitelist claim (voucher check and `claim`), burn (`costToReach`, approve,
`burn`), link, and mystery box (`triesLeft`, `enter`, `claimable`, `claim` on each chain); a
reference script that reproduces the royalty split from `Activation.snapshot`, dead-address
exclusion included, so that "allocations plus carried rounding equal funding" is testable by
MINT.

**DEL-7 Existing-contract review.** A read of the contract MINT names, within the agreed line
limit; findings only, no remediation (`→ CQ-13`).

**DEL-8 Audit tranches.** Tranche 1: `MintABear`, `WhitelistClaim`, `Activation` and
`DirectBurnAdapter`. Tranche 2: `MysteryBox`, `PrizeVault` and `SeedRequester`, once CQ-8 and
CQ-9 are decided. Iñigo accepts after Calea and MINT sign off; anything not accepted stays
disabled in the UI.

**DEL-9 Repository.** The contracts live in MINT's monorepo (`github.com/mintdotio/NFT`) as
`packages/contracts` (`@mint/contracts`), a Foundry package with a thin `package.json` so
`pnpm -r build|test|check` reach it; CI runs `forge fmt --check`, `forge build --sizes`,
`forge test` (`→ CQ-14`, `→ CQ-19`).

**DEL-10 Commercial items for Rayco's agreement.** Listed here so nothing is implied: prize
intake and unique-winner logic; weight interfaces; Studio and frontend assistance; mainnet
execution and role handover on every chain; technical support through 19 November with agreed
response hours; the existing-contract review; and two items beyond the SoW's single-chain vault
and collection: the **whitelist registry** (WL) and **multi-chain prize delivery** (a vault per
prize chain, the seed relay, the recipient nomination).

**DEL-11 Frontend collaboration.** Recommended and default (`→ CQ-19`): a standalone web app
`apps/mintabear` in the monorepo, built and owned by MINT; `packages/contracts` and a typed
`packages/contracts-client` owned by Calea; every pull request that touches a contract call is
reviewed by Calea before it merges; Framer keeps the marketing pages and links to the app.

## 10. Decisions for the call of 21 September

Nine decisions, in document order. Each states the options, their consequences and Calea's
recommendation, which is also what Calea builds if a decision is deferred. The settled items
follow, so the call need not reopen them.

### D1 — What $MNTD on Robinhood Chain is (CQ-2)

Burns open on 29 October, nine days after TGE, and the adapter needs the token's address,
`decimals` and `burnFrom`. What the token on Robinhood Chain *is* decides what a burn means:

- **(a1) Native — recommended.** Canonical supply issued on Robinhood Chain; a burn reduces it.
- **(a2) Bridged representation.** Canonical supply elsewhere, mirrored by a bridge; burning the
  mirror leaves the canonical tokens locked in the bridge forever. Acceptable only if MINT states
  publicly that locked-forever counts as burned.
- **(a3) Mint-and-burn bridge.** Each chain's supply is native to it; a burn on Robinhood Chain
  reduces global supply. Equivalent to (a1) for our purpose.

Also to answer: `burnFrom(address, uint256)` present? `decimals`? Who deploys? A copy on testnet
46630 by 5 October? Live on 4663 at TGE?

### D2 — Reading of the thresholds (CQ-4)

The table in ACT-2. **Recommended: cumulative** — 1,666 / 3,333 / 8,333 / 16,666 / 41,666 as
the total burned to reach each level, so level 5 costs 41,666 $MNTD in all. The per-level
reading makes level 5 cost 71,664 in all. Immutable once deployed.

### D3 — Addresses (CQ-12, CQ-15)

Admin, worker, eligibility signer, royalty receiver; the admin and worker also on Ethereum,
ApeChain and Base. **Recommended:** a Safe for the admin if its interface supports Robinhood
Chain, otherwise one EOA per chain held by Iñigo; EOAs for worker and signer; a royalty receiver
that is the pot and not the admin. Nothing deploys to mainnet before these are recorded.

### D4 — How whitelist claims are recorded (CQ-18)

- **(A) On-chain registry, holder pays gas — recommended.** Public counter, sell-out as a failed
  transaction, two-per-wallet and two-per-account caps enforced, the whole campaign auditable.
  Holders need a little ETH on Robinhood Chain, as they do for the mint.
- **(A′) On-chain registry, MINT pays.** Same contract; MINT's worker submits vouchers and pays.
- **(B) Off-chain register.** MINT's database; Calea supplies the export; nothing to audit.

Also to confirm: a spot is an allocation (1,000 allocations, up to two per wallet); campaign
6–26 October; who holds the signer key; the other stages and their order.

### D5 — Raffle architecture and reveal (CQ-8, CQ-9)

A prize can only be handed over on the chain where it sits, and entries can only be checked
against ownership on Robinhood Chain. Three ways to connect the two:

- **Option 1 — hub on Robinhood Chain, a vault on each prize chain — recommended.** Entries and
  the draw happen next to the bears; the result travels to each prize chain as one value the
  worker posts and anyone can verify; winners claim from the vault themselves; nothing leaves a
  vault during a round except to winners. One seed per round from Base. Most contracts to deploy
  (the same vault code three times), the strongest guarantees.
- **Option 2 — hub on Robinhood Chain, manual delivery elsewhere.** The hub and one vault on
  Robinhood Chain as in option 1; prizes on Ethereum and ApeChain are listed in the round and
  sent by MINT's treasury to the winners by hand within the claim window. Fewer deployments and
  lower cost; the SoW's "reserves cannot be withdrawn during a live round" cannot be enforced for
  those prizes, and delivery is on trust.
- **Option 3 — an independent raffle on each chain.** Each chain's vault runs its own draw with
  its own randomness and receives the entries as a relayed snapshot. Three randomness sources,
  three draws, a wallet may win once per chain; and ApeChain has no Chainlink VRF, so it would
  need another randomness source. Not recommended.

**Reveal.** *Scheduled draw — recommended*: entries during the window, one seed, one draw; the
UI opens every entered box at reveal time. *Instant*: each click resolves on the spot; Robinhood
Chain cannot produce randomness at click time, relaying Chainlink randomness per click takes
minutes and costs a fee per click, and a seed pre-committed by MINT lets MINT foresee outcomes.
Also: opening is free apart from gas, one open per bear per round; later rounds may require a
minimum level.

### D6 — VRF subscription (CQ-17)

Chainlink VRF is a paid service; whoever uses it holds a subscription topped up with LINK or
ETH that lists the allowed consumers, and each round makes one request costing a few dollars.
**Recommended (a):** MINT creates and funds the subscription on Base from a wallet it controls;
Calea adds `SeedRequester` as a consumer during deployment. **(b):** Calea creates it for the
rehearsal and transfers it at handover.

### D7 — Calendar (CQ-1)

Confirm or move the *proposed* rows of §8: $MNTD on testnet by 5 October; whitelist campaign
6–26 October; round 1 entries 29 October to 1 November with the draw on 1 November and claims to
1 December; first royalty close 5 November; handover 19 November.

### D8 — Existing-contract review (CQ-13)

Name the contract (probably the staking contract), its source or verified address, and its
size in lines, so the line limit can be set. Findings only.

### D9 — Frontend and repository (CQ-19, CQ-14)

- **(A) Standalone web app in the monorepo — recommended.** `apps/mintabear` by MINT;
  `packages/contracts` and `packages/contracts-client` by Calea; contract-touching pull requests
  reviewed by Calea; Framer keeps the marketing pages.
- **(B) Stay on Framer** with a Calea JavaScript bundle in code components; harder to test and
  review, every change through Framer's editor.

Also: Foundry dependencies as submodules or vendored; who owns CI.

### Settled

- **CQ-3** — the `credit` design stands; MINT's reply described the royalty pot, recorded in §2.
- **CQ-5** — weights 1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00, six levels.
- **CQ-6** — no burn; supply 4,444 forever; a bear at a dead address stays in supply.
- **CQ-7** — royalties enforced from deployment, proven on testnet and with one team-bear sale.
- **CQ-10** — 30-day claim window; unclaimed prizes roll into the next round.
- **CQ-11** — nothing leaves a vault while a round is live on it; withdrawals between rounds.
- **CQ-16** — no freeze, no clawback; "spent" is a raffle notion, not a freeze.

## 11. Sign-off

| Party | Name | Date | Signature |
|---|---|---|---|
| MINT | Iñigo Gaston | | |
| Calea | Bojan Jovin | | |
| Rayco | | | |

Version 2.0-draft, 18 September 2026. The version signed after the call carries the call's
decisions; amendments are issued as new versions of this document; requirement identifiers are
never reused.
