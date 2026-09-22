<!-- GENERATED sections between openspec markers are written by docs/tools/spec_tools/render_calea_prose.py from openspec/. Edit openspec/ and the narrative here, then run docs/tools/board.sh. -->
# MintABear — Specification

<!-- openspec:begin version -->
**Version** 2.1 · **Date** 21 September 2026 · **Status** records the decisions of the
MINT–Calea call of 21 September 2026; sign-off follows the open items in §10
<!-- openspec:end -->

Prepared by Calea for MINT. Sources: *MINTaBear development statement of work* (MINT, 14 September
2026); *Mint <> Calea* meeting (15 September 2026); *MintABear questionnaire v2.0*; MINT's written
answers to specification v1.0 (September 2026); *WL Wager Based Checker* (MINT, September 2026);
the MINT–Calea call of 21 September 2026. Where the sources differ, this document states the
resolution. Where a point is still MINT's to decide, the requirement states Calea's recommendation
— which is also what Calea builds if the decision is deferred — and points to the question (`→
CQ-n`) in the register. Section 10 records what the call settled and what is still open.

**How to read.** Requirements carry stable identifiers: `COL-n` collection contract, `WL-n`
whitelist claim, `ACT-n` activation and burn route, `RAF-n` mystery box raffle, `OPS-n`
operations and handover, `DEL-n` deliverables. The system overview and the calendar carry the
section tags `SYS` and `CAL`, which route questions to them and carry no requirements of their
own. Each requirement is a single testable statement. An identifier
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
- **Mystery box**: `MysteryBox` on Robinhood Chain (ownership, the spent id, the open register),
  `PrizeDraw` on the Chainlink chain (one VRF word per open, the win rule, the outcome), and a
  `PrizeVault` on each chain that holds prizes (`→ CQ-20`).
- Deterministic unit and integration tests; deployment and verification scripts, runbook,
  testnet deployments, interface/event/role documentation with examples, static and manual
  review, fuzzing and invariant report.
- A review of one existing MINT contract, findings only, within an agreed line limit
  (`→ CQ-13`); and delivery of the contracts into MINT's monorepo with CI (`→ CQ-14`).
- Technical support for the getminted.io integration: contract call surface, a typed client
  library, calldata examples, review of the frontend's contract calls (`→ CQ-19`).

### 1.2 Out of scope

From the SoW, verbatim: independent audit; existing-contract remediation; on-chain art renderer;
automatic bridges or trading; arbitrary unsupported assets; new casino free spins.

Also out of scope: ERC-6551 token-bound accounts (COL-9); artwork, metadata hosting and reveal
(MINT); the Privy mirror login, the wager API, the eligibility checker and the web app or Framer
pages (MINT); backend workers and indexing; running the royalty pot — the $MNTD
purchase, the splitter wallet and the crediting of getminted.io accounts, Calea delivering only
reference script that reproduces the split (DEL-6); the Status boost; monitoring and alerts (MINT);
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
| MINT automation | Worker key: deposit registration, prize commitment, relaying each open to the draw in order, posting awards. Eligibility signer: whitelist vouchers |
| Calea / Rayco | Contracts, tests, scripts, runbook, testnets, review, integration support; deploys and hands over; retains no keys or roles |
| Calea internal auditor | Fuzzing and invariant harnesses, review report |

## 2. System overview (SYS)

**Chains.**

| Chain | Id | Hosts | Testnet |
|---|---|---|---|
| Robinhood Chain | 4663 | `MintABear`, `WhitelistClaim`, `Activation`, `DirectBurnAdapter`, `MysteryBox`, one `PrizeVault` | 46630 |
| Ethereum | 1 | `PrizeVault` | Sepolia 11155111 |
| ApeChain | 33139 | `PrizeVault` | Curtis 33111 |
| Base | 8453 | `PrizeDraw` (Chainlink VRF v2.5) — Calea's recommendation, `→ CQ-17` | Base Sepolia 84532 |

Robinhood Chain stores the bears and is the source of truth for ownership, levels, whitelist
claims and which boxes have been opened. Prizes stay on the chain where MINT holds them, so the
prize chains are whichever chains MINT funds (`→ CQ-20`). Randomness comes from a chain with
Chainlink VRF v2.5: Calea recommends Base, which MINT already uses; Ethereum has it too, ApeChain
and Robinhood Chain do not (checked 18 September 2026).

**Contracts.**

| Contract | Chain | Purpose |
|---|---|---|
| `MintABear` | 4663 | ERC721SeaDrop collection, 4,444 supply, transfer counter, enforced royalties |
| `WhitelistClaim` | 4663 | 1,000 first-come-first-served whitelist allocations against signed eligibility |
| `Activation` | 4663 | Credited burns → level → weight; Status link |
| `DirectBurnAdapter` | 4663 | Burns $MNTD and credits the bear in one transaction |
| `MysteryBox` | 4663 | The open register: ownership check, the spent id, the excluded ids |
| `PrizeVault` | each prize chain | Prize inventory, commitment to the game, awards and claims |
| `PrizeDraw` | Chainlink chain | One VRF word per open, the win rule, the recorded outcome |

**Trust model.** Contracts enforce ownership, supply, the transfer counter, level derivation, the
weights table, the whitelist count and per-wallet caps, raffle entries, prize locking, the draw
and claims. MINT holds two keys with narrow powers. The **eligibility signer** decides *who* may
claim a whitelist spot; the contract decides *how many* and *in what order*. The **worker**
supplies inputs the contracts cannot obtain themselves — deposit registration, the relay of each
open from Robinhood Chain to the draw, and the posting of each award to the vault that holds the
prize. Both relays are publicly checkable, against `BoxOpened` on 4663 and `OutcomeRecorded` on
the draw. The draw refuses an open out of turn, so the worker cannot choose which open meets
which state of the pool; it can delay one, and a delayed open is visible. The worker cannot
alter weights or thresholds, raise a level without a burn, open a box, change an outcome, move a
committed or won prize, or create a whitelist spot.

**On-chain.** Ownership and transfers; the transfer counter and its event; whitelist claims and
the live spot count; credited burns, cumulative totals, levels and weights; Status nominations;
raffle entries, seeds, awards and roots; prize inventory and its states; claims.

**Off-chain (MINT).** Wager measurement and the Season 1 back-credit; the Privy login that ties
a wallet to a getminted.io account; the royalty pot and its split — when the pot reaches its ETH
or its countdown ends, half the ETH buys $MNTD, and ETH and $MNTD move to a splitter wallet that
credits getminted.io accounts by wallet weight (ACT-10); crediting an account requires knowing
account a holding wallet belongs to, which the Privy login supplies and the chain does not; the
Status boost; indexing, alerts and the UI. What level 5 is *worth* is MINT's to define; the
chain records that it was reached.

**Flow.** (1) Whitelist campaign: a holder wagers and logs in on getminted.io; MINT's
backend signs a voucher; the holder claims a spot on `WhitelistClaim`; at close MINT loads the
list into the Studio allowlist stage. (2) Iñigo runs the drop in Studio; holders mint via OpenSea
or the getminted.io mirror. (3) Holders burn $MNTD through the adapter; `Activation` credits the
bear and its level and weight follow. (4) Any transfer advances the counter and voids level,
weight and link. (5) The mystery box: MINT deposits prizes into the vaults; the worker commits
them; the owner records the excluded ids and opens the game; a holder opens a box with a bear,
which spends that id; the worker relays the open in turn; a Chainlink word decides it; a winner
nominates a recipient and the worker posts the award to the prize's vault; the winner claims
there. (6) MINT reads `Activation.snapshot` at each royalty closing block and
splits the pot off-chain.

## 3. Collection contract — MintABear (COL)


<!-- openspec:begin family COL -->
MINT needs a 4,444-bear collection on Robinhood Chain that its team runs from OpenSea Studio, that collects royalties on every sale, and whose every transfer visibly resets a bear's activation — so that everything else in the system can trust ownership and the transfer counter alone.

**COL-1 Base.** `MintABear` extends OpenSea's `ERC721SeaDrop` with its mint path,
`getMintStats`, metadata and royalty interfaces unchanged. Canonical SeaDrop
`0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` is the only allowed minter. The drop is configured
and operated through OpenSea Studio by MINT (COL-11).

*Acceptance.* Given the collection deployed with canonical SeaDrop as its only allowed minter; when any other address calls the mint path; then the call reverts and no bear is minted.

**COL-2 Supply.** `MAX_BEARS = 4444` is a constant enforced on the mint path; a mint that would
exceed it reverts with `ExceedsMaxBears`. The inherited `maxSupply` is a Studio setting (COL-11)
and is set to exactly 4,444: `MAX_BEARS` refuses the mint whatever `maxSupply` says, so raising it
cannot increase the supply delivered — it would only advertise a supply the token will not deliver,
and buyers past the cap would pay for reverted transactions. Team, treasury, partner and whitelist
bears all come out of the same 4,444. Because no bear can be destroyed (COL-8), the supply is
exactly 4,444 once minted out.

*Acceptance.* Given 4,444 bears minted; when SeaDrop mints one more, whatever `maxSupply` says; then the transaction reverts with `ExceedsMaxBears`.

**COL-3 Transfer counter.** `transferNonce(tokenId)` increments on every transfer except mint —
sales, gifts, self-initiated moves and return transfers to a previous owner alike — and never
resets. It is the mechanism by which every ownership change resets level, weight and Status
link (ACT-5).

*Acceptance.* Given a bear whose `transferNonce` reads n; when it is transferred to another wallet; then `transferNonce` reads n + 1; and a freshly minted bear reads 0.

**COL-4 Reset event.** `TransferNonceAdvanced(uint256 indexed tokenId, uint64 nonce)` is
emitted for every non-mint transfer, in the same transaction as `Transfer`. It is the
activation-reset event: anything `Activation` recorded at the previous counter value is void
once it fires. It fires whether or not a level existed.

*Acceptance.* When a bear is transferred, whether or not it has a level; then `TransferNonceAdvanced(tokenId, nonce)` is emitted in the same transaction as `Transfer`.

**COL-5 Metadata.** Standard SeaDrop metadata: `baseURI` set through Studio,
`tokenURI(id) = baseURI + id`, provenance hash committed with `setProvenanceHash` before the
mint opens. Placeholder JSON, reveal and hosting are MINT's. Artwork is immutable and metadata
does not vary with level.

*Acceptance.* Given `baseURI` set through Studio; when `tokenURI(id)` is read; then it returns `baseURI` followed by `id`; and raising the bear's level changes nothing in it.

**COL-6 Royalties.** ERC-2981 through SeaDrop's `setRoyaltyInfo`: **5% (500 basis points)**,
receiver the royalty-pot address MINT names, distinct from the admin and from every vault. Set
by Iñigo in Studio at any point before the first sale; it does not hold up deployment. `→ CQ-15`
(receiver).

*Acceptance.* Given royalty info set in Studio to 500 basis points and the pot address; when `royaltyInfo(id, salePrice)` is read; then it returns the pot address and 5% of `salePrice`.

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
restores it (OPS-6). Every change emits `TransferValidatorUpdated`.

*Acceptance.* Given the validator set to V3 with the zero-state policy; when a holder transfers a bear directly; then the transfer passes; and a Seaport order from a venue other than OpenSea's SignedZone reverts.

**COL-8 No burn.** The transfer hook refuses `to == address(0)` with `BurnDisabled`, so
`ERC721SeaDrop.burn` always reverts and no bear can be destroyed by anyone, its owner included;
`totalSupply` never falls. A bear sent to an address nobody controls (for example `0x…dEaD`)
remains a bear in the supply: nobody can enter it in a raffle (RAF-21), and the royalty snapshot
excludes the canonical dead address (ACT-10).

*Acceptance.* When anyone, the owner included, calls `burn` or transfers a bear to the zero address; then it reverts with `BurnDisabled`; and `totalSupply` is unchanged.

**COL-9 No token-bound accounts.** ERC-6551 is not part of the collection. It can be added later
without any change to `MintABear`: the canonical registry
`0x000000006551c19487814612e58FE06813775758` derives an account address from
`(chainId, tokenContract, tokenId)` for any ERC-721. The one property that cannot be retrofitted
is a token-side guard against sending a bear into a bear's account.

*Acceptance.* When the deployed `MintABear` is inspected; then it holds no ERC-6551 account code, no account guard and no registry call.

**COL-10 Ownership.** Deployed by Calea; ownership transferred to MINT's admin address by the
inherited two-step process (`transferOwnership`, then `acceptOwnership` from the admin) before
the drop page is published. Calea retains no role.

*Acceptance.* Given Calea has called `transferOwnership(admin)`; when the admin calls `acceptOwnership`; then the admin is the owner; and Calea holds no role.

**COL-11 What Studio owns.** Mint stages, dates and pricing; allowlists and per-wallet limits,
including the whitelist stage loaded from `WhitelistClaim` (WL-4); payout address; `maxSupply`
(COL-2); `baseURI` and provenance (COL-5); royalty info (COL-6); `multiConfigure`. A
"guaranteed" stage is guaranteed by stage sequencing — the guaranteed window must close before
the next window opens — not by the contract.

**COL-12 Reads.** `ownerOf`, `exists(tokenId)`, `totalSupply`, `maxSupply`, `MAX_BEARS`,
`transferNonce`, `tokenURI`, `royaltyInfo`, `getTransferValidator`, `getMintStats`, plus the
ERC-721 and SeaDrop standard surface.

*Acceptance.* When `ownerOf`, `exists`, `totalSupply`, `maxSupply`, `MAX_BEARS`, `transferNonce`, `tokenURI`, `royaltyInfo`, `getTransferValidator` and `getMintStats` are called for a minted bear; then each returns without reverting; and `exists(id)` is false for an unminted id.

**COL-13 Events.** Standard `Transfer`, `Approval`, `ApprovalForAll`; SeaDrop configuration
events; `TransferNonceAdvanced` (COL-4); `TransferValidatorUpdated` (COL-7).

*Acceptance.* When a bear is transferred and the validator is changed; then `Transfer`, `TransferNonceAdvanced` and `TransferValidatorUpdated` are emitted with the documented arguments.
<!-- openspec:end -->

## 4. Whitelist claim (WL)


<!-- openspec:begin family WL -->
MINT needs a first-come-first-served whitelist of 1,000 allocations that only wagering holders can claim, recorded where anyone can check it — so that the allowlist loaded into Studio is provably the list the campaign produced.

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
- **Two per wallet, two per account.** A getminted.io account cannot spread more than two
  over several wallets.

*Acceptance.* Given a wallet holding one claimed allocation and an account holding one; when the wallet claims allocation 2 with a valid voucher; then the claim succeeds and both counts read 2; and a third claim for either reverts.

**WL-2 Division of work.** MINT: the Privy mirror login on getminted.io; the wager API that
returns, for the logged-in account, historical wagering capped at $50 and in-campaign wagering;
the eligibility checker; the UI; and the **eligibility signer**, a backend key that signs a
voucher when the API confirms a threshold. Calea: the `WhitelistClaim` contract, the voucher
format, the export to the Studio allowlist, and the client calls (DEL-6).

**WL-3 Registry.** `WhitelistClaim` on Robinhood Chain (`→ CQ-18`; WL-6 is the alternative). A
voucher is an EIP-712 message `Claim(address wallet, uint8 allocationIndex, bytes32 account,
uint256 deadline)` signed by the eligibility signer, with a short `deadline` (minutes) and
`account` a hash of the getminted.io account id, so the chain carries no personal data.
`claim(voucher,
signature)` reverts unless: `msg.sender == wallet` (`NotClaimant`), the one condition D4 option
(A′) removes; the signature is the signer's (`BadSigner`); `block.timestamp ≤ deadline`
(`Expired`); the campaign window is open (`CampaignClosed`); `spotsLeft() > 0` (`SoldOut`);
`claimsOf(wallet) < MAX_PER_WALLET` (`WalletLimit`) and `allocationIndex == claimsOf(wallet) + 1`
(`WrongAllocation`), so a wallet claims its allocations in order and at most twice whatever the
voucher says; `accountClaims(account) < MAX_PER_ACCOUNT` (`AccountLimit`). Effects: the wallet's
and the account's counts increase, the spot counter increases, the wallet is appended to the
claimant list, and `WhitelistClaimed(wallet, allocationIndex, account, spotNumber)` is emitted. By
default the claim is sent by the wallet itself, which pays Robinhood Chain gas — it needs gas for
the mint anyway; in the relayed variant MINT's worker submits the voucher and pays, which is the
same contract without the `NotClaimant` condition (`→ CQ-18`). Reads: `TOTAL_SPOTS`,
`MAX_PER_WALLET`, `MAX_PER_ACCOUNT`, `spotsLeft()`, `claimsOf(wallet)`, `accountClaims(account)`,
`claimants(offset, limit) → (wallet, allocations)[]`, `openAt`, `closeAt`, `signer`. Owner (MINT
admin): `setSigner`, `setWindow(openAt, closeAt)`, ownership transfer. Nobody can remove or
reassign a claim.

*Acceptance.* Given a voucher signed by the signer for wallet W, allocation 1, within its deadline and the campaign window; when W calls `claim`; then `spotsLeft` falls by one, `claimsOf(W)` reads 1 and `WhitelistClaimed` is emitted; and the same call from another wallet reverts with `NotClaimant`.

**WL-4 Into the mint.** After the window closes or the spots sell out, MINT exports the claimant
list — one row per wallet with its allocation count — and loads it as the whitelist stage's
allowlist in Studio. SeaDrop allowlist entries carry a per-wallet mint limit, so "one or two" is
enforced by the mint itself. The getminted.io mirror builds its Merkle proofs from the same list
(DEL-6). The registry is public, so a loaded list that differs from it is detectable by anyone.

*Acceptance.* Given a closed campaign; when `claimants(offset, limit)` is read across the whole list; then every wallet appears once with its allocation count, and the Studio allowlist loaded from it carries the same rows.

**WL-5 Timing.** The registry is deployed and its signer set before the campaign opens; the
campaign closes at least 48 hours before the whitelist stage opens, for the export, the Studio
import and the publication of proofs. Dates `→ CQ-18`; calendar in §8.

*Acceptance.* Given `openAt` and `closeAt` set with the close at least 48 hours before the whitelist stage; when a claim arrives before `openAt` or after `closeAt`; then it reverts with `CampaignClosed`.

**WL-6 Alternative — off-chain register.** MINT's backend records claims in its database behind
an atomic counter; Calea supplies the claim-API contract and the Studio export script and deploys
nothing. Faster to build and free of gas for holders; the order of claims and the sell-out rest
on MINT's server, nothing is publicly checkable, and the SeaDrop allowlist root is the only trace
on-chain. `→ CQ-18`.
<!-- openspec:end -->

## 5. Activation and burn route (ACT)


<!-- openspec:begin family ACT -->
Holders need to burn $MNTD to raise a bear's level and weight, and MINT needs to read those weights for the royalty split, in a way no key can forge and every transfer resets — so that a level is always evidence of a burn by the current owner.

**ACT-1 Token-agnostic.** `Activation` holds no reference to $MNTD and never moves tokens. It
records credited burn amounts per bear and derives level and weight from them. It reads
`MintABear` (`ownerOf`, `transferNonce`, `exists`); `MintABear` never calls it, so no defect in
`Activation` can affect a transfer. In plain terms: burning the tokens and recording the level
are two steps of one transaction. The adapter burns the holder's $MNTD, then tells `Activation`
"this wallet burned this amount for this bear"; `Activation` accepts that message from the
adapter alone. If $MNTD ever changes address or chain, only the adapter changes.

*Acceptance.* When `Activation`'s code and constructor are inspected; then it holds no $MNTD reference and moves no tokens; and it reads only `MintABear`'s `ownerOf`, `transferNonce` and `exists`.

**ACT-2 Thresholds.** Five cumulative thresholds `T1 < T2 < T3 < T4 < T5`, in $MNTD base units,
supplied to the constructor and immutable. A bear's level is the highest `k` with
`cumulative ≥ Tk`, or 0. `thresholdFor(level)` and `costToReach(tokenId, level)` expose them.
The figures are 1,666 / 3,333 / 8,333 / 16,666 / 41,666 $MNTD, read cumulatively: each is the
total a bear must have burned to stand at that level, so level 5 costs 41,666 $MNTD in all
(MINT, CQ-4).

| Level | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Total burned to reach it | 1,666 | 3,333 | 8,333 | 16,666 | 41,666 |

The constructor receives this row in base units, which fixes $MNTD's `decimals` before
deployment (`→ CQ-2`).

*Acceptance.* Given the thresholds 1,666 / 3,333 / 8,333 / 16,666 / 41,666 in base units; when a bear's cumulative reaches 8,333; then `levelOf` reads 3 and `costToReach(id, 4)` reads 8,333.

**ACT-3 Weights.** Six royalty weights for levels 0–5, basis 100, supplied to the constructor
and immutable: `100 / 110 / 125 / 145 / 170 / 200` (1.00× to 2.00×), confirmed by MINT.
`weightFor(level)` returns the table entry; `weightOf(tokenId)` returns the weight of the bear's
current level.

*Acceptance.* Given the weights 100 / 110 / 125 / 145 / 170 / 200; when a bear at level 3 is read; then `weightOf` returns 145 and `weightFor(5)` returns 200.

**ACT-4 Credit.** `credit(uint256 tokenId, address burner, uint128 amount, uint64 nonce,
bytes32 ref)` is callable only by the `crediter` (`NotCrediter`, ACT-7). It reverts unless: not
paused (`ContractPaused`); `amount > 0` (`ZeroAmount`); `ownerOf(tokenId) == burner`
(`NotBearOwner`); `transferNonce(tokenId) == nonce` (`StaleNonce`); `ref` has not been used
(`RefAlreadyUsed`). Both ownership checks passing means `burner` has owned the bear continuously
since `nonce` was read — a burn is never credited to a bear that changed hands in between. Effects:
the cumulative for the current counter value increases by `amount`; `lifetimeBurned` increases by
`amount`; `ref` is marked used; `BearActivated(tokenId, burner, previousLevel, newLevel, amount,
cumulative, ref)` is emitted.

*Acceptance.* Given the crediter calls `credit` for a bear the burner owns, with the current nonce and a fresh `ref`; when the call executes; then the cumulative and `lifetimeBurned` grow by `amount` and `BearActivated` is emitted; and a second call with the same `ref` reverts with `RefAlreadyUsed`.

**ACT-5 Reset.** Cumulative, level, weight and link read as zero whenever the counter value
they were recorded at differs from the current `transferNonce`. The reset is a consequence of
the transfer (COL-3), not an action: it cannot be skipped and cannot block a transfer. Return
transfers reset like any other.

*Acceptance.* Given a bear at level 2 with a Status link; when it is transferred to another wallet; then `levelOf`, `cumulativeOf` and `weightOf` read zero and `linkOf` reads `(0, 0)`, with no call into `Activation`.

**ACT-6 Lifetime.** `lifetimeBurned(tokenId)` accumulates every credit ever made to a bear and
never resets.

*Acceptance.* Given a bear credited twice with a transfer in between; when `lifetimeBurned` is read; then it is the sum of both credits.

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
`Activation` is deployed. $MNTD is **native** to Robinhood Chain: its canonical supply is issued
there and `burnFrom` reduces it, so a burn removes supply outright and needs nothing said about
it publicly (MINT, CQ-2). A bridged or mint-and-burn representation, a burn on another chain
with an attested credit on 4663, and cross-chain messaging are all out. MINT's staking sits
beside the token on the same chain and touches nothing here: `Activation` reads only
`MintABear`, and the adapter only $MNTD. The token's `burnFrom` and `decimals` are still to be
confirmed against the deployed contract (`→ CQ-2`).

*Acceptance.* Given the holder has approved the adapter on $MNTD; when the holder calls `burn(tokenId, amount)` for a bear below level 5; then `burnFrom` and `credit` execute in one transaction and `BurnedForBear` is emitted; and a call by a non-owner reverts with `NotOwner`.

**ACT-8 Overshoot.** The adapter refuses any amount beyond what level 5 needs, so no $MNTD is
destroyed for nothing. The portal sizes each burn with `costToReach(tokenId, targetLevel)`,
which returns the exact remainder or zero.

*Acceptance.* Given a bear whose `costToReach(id, 5)` reads x; when the holder calls `burn(id, x + 1)`; then it reverts with `Overshoot` and no $MNTD is burned.

**ACT-9 Status link.** `linkBear(tokenId)`, owner of the bear only, one nomination per wallet,
recorded with the current counter value; `unlinkBear()` clears it and is safe to call when
nothing is linked; `linkOf(wallet) → (tokenId, level)` returns `(0, 0)` when nothing is linked
or the bear has since moved. A wallet aggregates royalty weight across all its bears (ACT-10)
but carries exactly one Status boost; the boost's value is MINT's, off-chain.

*Acceptance.* Given a wallet owning a bear at level 2; when it calls `linkBear(tokenId)`; then `linkOf(wallet)` reads `(tokenId, 2)`; and after the bear moves it reads `(0, 0)`.

**ACT-10 Snapshot view.** `snapshot(uint256[] ids) → (address owner, uint8 level, uint16
weight)[]`, returning zeroes for ids that do not exist. MINT's royalty accounting reads it for
`1..4444` at each closing block; a wallet's weight is the sum over its bears and the total
eligible weight is the sum over all bears whose owner is not the canonical dead address
`0x000000000000000000000000000000000000dEaD` (COL-8). Because transfers reset weight without any
call into `Activation`, there is no on-chain running total; the sum is taken off-chain from
this view. A reference script reproducing the split, dead-address exclusion included, is
delivered (DEL-6); MINT credits the resulting shares to getminted.io accounts through its
wallet (§2).

*Acceptance.* When `snapshot([1, 2, 4445])` is read; then it returns owner, level and weight for ids 1 and 2 and zeroes for the id that does not exist.

**ACT-11 Pause.** The owner may pause. While paused, `credit` and `linkBear` revert; reads,
`unlinkBear` and every transfer are unaffected. The adapter's `burn` therefore reverts while
paused and no $MNTD is burned; this is how burns stay closed between deployment and the
switch-on date (§8). The pause admits no exemption — no address may burn while it is on — so
the mainnet rehearsal against real $MNTD runs in a window the owner opens and closes again
(§8). `renounceOwnership` is refused while paused, so a pause can always be lifted.

*Acceptance.* Given the owner has paused; when the crediter calls `credit` or a holder calls `linkBear`; then both revert with `ContractPaused`; and reads, `unlinkBear` and every transfer still succeed.

**ACT-12 Roles.** Owner (MINT admin): `setCrediter`, `setPaused`, ownership transfer. Nothing
else is administrable: thresholds, weights and records are immutable; the adapter has no owner.
There is no freeze or clawback path into a bear anywhere (MINT, CQ-16).

*Acceptance.* When a non-owner calls `setCrediter` or `setPaused`; then it reverts; and no function anywhere changes thresholds, weights or a bear's record.

**ACT-13 Events.** `BearActivated` (ACT-4), `BearLinked(wallet, tokenId)`,
`BearUnlinked(wallet, tokenId)`, `CrediterSet(previous, current)`, `PausedSet(paused)`;
adapter: `BurnedForBear(ref, tokenId, burner, amount)`.

*Acceptance.* When a credit, a link, an unlink, a crediter change and a pause happen; then `BearActivated`, `BearLinked`, `BearUnlinked`, `CrediterSet` and `PausedSet` are emitted with the documented arguments.

**ACT-14 Reads.** `levelOf`, `cumulativeOf`, `lifetimeBurned`, `weightOf`, `weightFor`,
`thresholdFor`, `costToReach`, `linkOf`, `snapshot`, `paused`, `crediter`, `BEARS`; adapter:
`MNTD`, `ACTIVATION`, `burnCount`.

*Acceptance.* When every listed read is called for a credited bear; then each returns without reverting; and `BEARS`, `MNTD` and `ACTIVATION` return the deployed addresses.
<!-- openspec:end -->

## 6. Mystery box raffle (RAF)


<!-- openspec:begin family RAF -->
A holder opens a mystery box with a bear they own and learns the outcome there and then. One
bear is one shot: the open spends that id for good, and nobody can play it again, whoever holds
the bear afterwards. There are no rounds, no entry window and no scheduled draw (MINT, CQ-9).
Three contracts: `MysteryBox` on Robinhood Chain, where the bears are, so an open is checked
against live ownership; `PrizeDraw` on a chain with Chainlink VRF, which decides each open with
a random word of its own; and a `PrizeVault` on every chain that holds prizes, because a prize
can only be handed over where it sits.

**RAF-26 The game.** One game over the collection, not a series of rounds. States: **Setup** —
prizes deposited, registered and committed, excluded ids recorded, nothing openable; **Open** —
holders open boxes; **Closed** — no further opens, prizes never won released. The owner makes
each transition once and neither is reversible.

*Acceptance.* Given the game in Setup with prizes committed and ids excluded; when the owner opens it and later closes it; then each transition happens once and a second call to either reverts.

**RAF-27 Playable ids and the prize pool.** Two numbers fix the odds, and both freeze when the
game opens (`→ CQ-20`). The **excluded ids** are recorded as ranges by the owner during Setup
(`excludeRange(from, to)`, event `IdsExcluded`); an excluded bear is out of play whoever holds
it, so a team bear that is sold stays out. `PLAYABLE = MAX_BEARS − excluded` is computed at the
transition to Open and is immutable after it. The **prize pool** is the ordered manifest
`(chainId, vault, prizeIndex)` of every prize the vaults have committed (RAF-3, RAF-4), chains
in the fixed order the owner records and, within a vault, ERC-721 prizes in registration order
then baskets in asset-approval order. It is public before the first open and nothing may be
added once the game is Open. A game with no prizes cannot open.

`PLAYABLE` and the prize count are also `PrizeDraw`'s constructor arguments, because it runs on
another chain and cannot read the hub. The excluded ranges are therefore final before `PrizeDraw`
is deployed, and the hub's `GameOpened(playable, prizeCount, manifestHash)` publishes all three so
that anyone can check the two chains were given the same game.

*Acceptance.* Given ranges excluded during Setup and prizes committed; when the owner opens the game; then `GameOpened(playable, prizeCount, manifestHash)` publishes `MAX_BEARS − excluded`, the manifest length and its hash; and `excludeRange` after opening reverts.

**RAF-28 Opening a box.** `open(uint256 tokenId)` on `MysteryBox`, by the wallet that is
`ownerOf(tokenId)` at that moment. It reverts unless the game is Open (`GameNotOpen`),
`ownerOf(tokenId) == msg.sender` (`NotBearOwner`), the id is not excluded (`IdExcluded`) and the
id has not been opened (`AlreadyOpened`). Effects: the id is marked spent for good, the next
`openIndex` is assigned, and `BoxOpened(openIndex, tokenId, opener)` is emitted. Opening is free
apart from gas. A spent bear stays freely transferable and its buyer cannot open it again.
`shotsLeft(wallet)` returns the wallet's bears that are playable and unopened — a holder of ten
bears who has opened two sees eight.

*Acceptance.* Given an open game and a holder of a playable, unopened bear; when the holder calls `open(tokenId)`; then `BoxOpened(openIndex, tokenId, opener)` is emitted and `shotsLeft(holder)` falls by one; and the buyer of that bear cannot open it again, reverting with `AlreadyOpened`.

**RAF-29 Resolution, in order.** Each open is resolved on `PrizeDraw` by `resolve(uint64
openIndex, address opener)`, which the worker relays from the `BoxOpened` event. `PrizeDraw`
refuses any `openIndex` but the next unresolved one (`OutOfOrder`), so the worker cannot choose
which open meets which state of the pool; it can only delay one, and a delayed open is visible
as a `BoxOpened` with no `OutcomeRecorded`. `resolve` requests one Chainlink word and emits
`DrawRequested(openIndex, requestId)`. Requests may be in flight at once, and outcomes are
applied strictly in `openIndex` order as the words arrive, so an open waits on the words of the
opens before it and on nothing else.

*Acceptance.* Given opens 1 and 2 recorded and neither resolved; when the worker calls `resolve(2, opener)`; then it reverts with `OutOfOrder`; and `resolve(1, opener)` requests one Chainlink word and emits `DrawRequested`.

**RAF-30 The win rule (normative).** Let `idsLeft` be the playable ids not yet resolved and
`prizesLeft` the prizes not yet awarded, both starting at RAF-27's values. On the word `w` for
`openIndex i`:

- `won = (w mod idsLeft) < prizesLeft`;
- if `won`, the next unawarded prize of the manifest is assigned to `i`'s opener and `prizesLeft`
  decreases by one;
- `idsLeft` decreases by one either way;
- `OutcomeRecorded(openIndex, opener, won, prizeIndex)` is emitted, `prizeIndex` carrying no
  meaning when `won` is false.

Properties: every holder faces the same odds before opening, `prizesLeft / idsLeft`; exactly the
prize count is awarded once every playable id has been opened and resolved, so the pool can
neither run dry early nor be left over if the game is played out; a wallet's chances are
proportional to the playable bears it holds; and there is no cap on how many prizes one wallet
may win (MINT, CQ-9).

*Acceptance.* Given `idsLeft` at 10, `prizesLeft` at 2 and a word w with `w mod 10 == 1`; when the open is resolved; then `won` is true, the next manifest prize is assigned, `prizesLeft` reads 1 and `idsLeft` reads 9.

**RAF-31 Closing the game.** The owner closes the game once, after which `open` reverts. Prizes
never won — because their ids were never opened — return to unreserved inventory when the worker
posts the close to each vault, and the owner may then withdraw them (RAF-14).
`GameClosed(openCount, prizesAwarded)` on the hub, `PrizesReleased` on each vault. Nothing about
an outcome already recorded can change, and a prize already won stays the winner's until it is
claimed or expires.

*Acceptance.* Given an open game with one committed prize never won; when the owner closes the game and the worker posts the close to the vault; then `open` reverts, `GameClosed` and `PrizesReleased` are emitted and the prize is unreserved inventory again.

**RAF-2 Addresses.** Each `PrizeVault` is the dedicated deposit address on its chain, separate
from the royalty pot and from the admin. Neither `MysteryBox` nor `PrizeDraw` holds assets.

*Acceptance.* When the deployed addresses are compared; then each vault differs from the royalty pot and the admin, and `MysteryBox` and `PrizeDraw` hold no assets.

**RAF-3 Asset approval.** The owner approves each asset on each vault once: `approveAsset(token,
kind, basketSize)` with `kind ∈ {ERC20, ERC721}`; `basketSize` is in base units for ERC-20 (for
$MNTD on Robinhood Chain, 5,000 × 10^decimals) and ignored for ERC-721, where each token is its
own prize. `revokeAsset` stops an asset entering the pool and never touches a committed or won
prize. Unapproved assets never enter the pool. ERC-1155 is not supported.

*Acceptance.* Given an ERC-20 approved with basket size b; when the vault holds 2b + 1 units and commits; then two baskets are committed; and a deposit of an unapproved token never enters the pool.

**RAF-4 Intake.** Deposits are plain transfers to a vault. Nothing happens until the worker
registers them: `registerERC721(token, id)` requires `ownerOf(id) == vault` and the id not yet
tracked; `syncERC20(token)` adds `balanceOf(vault) − tracked` to unreserved inventory. Token
transfers alone never change the game's state. Each registration emits `DepositRegistered`.

*Acceptance.* Given an ERC-721 transferred to the vault; when the worker calls `registerERC721(token, id)`; then `DepositRegistered` is emitted and the prize is unreserved inventory; and before registration the game's state is unchanged.

**RAF-5 Inventory states.** Unreserved → committed (to the game) → won → claimed; or won →
expired → unreserved; or committed → unreserved when the game closes without the prize being
won. A committed or won prize cannot be withdrawn, swept or moved by anyone but its winner,
paused or not.

*Acceptance.* Given a committed prize; when the owner calls `sweep` for it; then the call reverts; and once won and expired the prize is unreserved again.

**RAF-6 Committing prizes.** During Setup the worker calls `commitToGame()` on each vault that
holds prizes: every unreserved full basket of every approved ERC-20 and every unreserved
registered ERC-721 is committed; ERC-20 remainders below a basket stay unreserved; the vault
emits `PrizesCommitted(prizes[])` with its ordered list. The hub's manifest (RAF-27) is the
concatenation of those lists, and a manifest that differs from the vaults' events is detectable
by anyone. MINT fills the vaults with exactly the prizes the game should carry, then the worker
commits and the owner opens.

*Acceptance.* Given a vault with approved baskets and registered ERC-721s; when the worker calls `commitToGame()`; then `PrizesCommitted(prizes[])` lists every full basket and every registered token in order; and remainders below a basket stay unreserved.

**RAF-8 Randomness.** Chainlink VRF v2.5, one request and one word per open, with the
subscription owned and funded by MINT and `PrizeDraw` as its consumer (MINT, CQ-17).
**Calea recommends Base** (coordinator `0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634`): MINT
already uses it, a request costs cents rather than the dollars Ethereum charges, and two-second
blocks keep the wait a holder sees down to seconds. Ethereum
(`0xD7f86b4b8Cae7D942340FF628F82735b7a20893a`) is the alternative and is correct but slow and
dear at one request per open. ApeChain has no Chainlink VRF; Robinhood Chain has none and no
usable `prevrandao` — which is why the draw is not on the chain the bears live on. One request
per open is what buys an outcome nobody can predict; the subscription has to carry the whole
collection's worth of requests, so it is funded for `PLAYABLE` of them and topped up on a
balance alarm, not on a schedule (`→ CQ-17`).

*Acceptance.* When `resolve` runs; then exactly one VRF v2.5 request is made from MINT's subscription with `PrizeDraw` as consumer; and the outcome uses that request's word alone.

**RAF-24 Prize vaults.** One `PrizeVault` code, deployed on every chain that holds prizes.
Lifecycle: approval (RAF-3), intake (RAF-4), `commitToGame()` (RAF-6); `award(prizeIndex,
recipient)` by the worker, once per prize and only for a prize the game recorded as won, which
anyone can check against `PrizeDraw`'s `OutcomeRecorded`; `claim(prizeIndex)` by the recipient
(RAF-11); `expirePrize` (RAF-11); `closeGame()` releasing the uncommitted remainder (RAF-31);
`sweep` (RAF-14).

*Acceptance.* Given a prize the draw recorded as won; when the worker calls `award(prizeIndex, recipient)` once; then `PrizeAwarded` is emitted; and a second `award` for the same prize, or one for a prize not recorded as won, reverts.

**RAF-25 Recipient nomination.** A winner claims on the prize's chain from the address that
opened the box on Robinhood Chain. An address that is a contract wallet on 4663 may not exist
elsewhere, so for `nominationWindow` after the outcome (default 24 hours; the owner may set 0) a
winner may call `nominateRecipient(openIndex, recipient)` on `PrizeDraw`; the worker posts the
award only once that window has passed, and the recipient defaults to the opener. The UI warns
contract-wallet holders before they open.

*Acceptance.* Given a win recorded at time t and a nomination window of 24 hours; when the winner calls `nominateRecipient(openIndex, r)` before t + 24 hours; then `recipientOf(openIndex)` reads r; and `award` before the window has passed reverts.

**RAF-11 Claims.** `claim(prizeIndex)` on the vault holding the prize: the caller is the
recorded recipient; the prize is unclaimed; `block.timestamp ≤ awardedAt + claimWindow`, with
`claimWindow` **30 days** (MINT, CQ-10). The prize — an ERC-20 basket or an ERC-721 — is
transferred to the caller. The right is single-use and non-transferable, and it belongs to the
wallet that opened the box whatever it does with its bears afterwards. After the window
`expirePrize` (anyone) returns the prize to unreserved inventory — MINT treats an unclaimed
prize as renounced — and a claimed prize never expires.

*Acceptance.* Given a prize awarded to r at time a; when r calls `claim(prizeIndex)` before a + 30 days; then the prize is transferred to r and `PrizeClaimed` is emitted; and after 30 days anyone may call `expirePrize` and the prize returns to inventory.

**RAF-14 Roles.** Owner (MINT admin): `approveAsset`, `revokeAsset`, `setWorker`,
`excludeRange`, `openGame`, `closeGame`, `setPaused`, `sweep`. `sweep` moves unapproved tokens
and unreserved inventory out of a vault, with an event, **only while that vault has nothing
committed**: from `commitToGame` until the game closes, nothing leaves the vault except to
winners (MINT, CQ-11), and a won prize stays locked until claimed or expired regardless. Worker
(MINT automation): `registerERC721`, `syncERC20`, `commitToGame`, `resolve`, `award`,
`closeGame` on each vault. Anyone: `open` as a bear's owner, `nominateRecipient` as a winner,
`claim` as a recipient, `expirePrize`, all reads.

*Acceptance.* When a non-owner calls `excludeRange`, `openGame` or `sweep`, or a non-worker calls `resolve` or `award`; then each reverts; and `open`, `claim` and `expirePrize` need no role.

**RAF-15 Pause.** Pausing the hub blocks `open`; pausing `PrizeDraw` blocks `resolve`, so no new
word is requested while outcomes already paid for are settled; pausing a vault blocks
registration and committing. None of them blocks `claim`, `expirePrize` or `nominateRecipient`.

*Acceptance.* Given the hub, the draw and a vault each paused; when `open`, `resolve` and `registerERC721` are called; then each reverts; and `claim`, `expirePrize` and `nominateRecipient` still succeed.

**RAF-16 Events.** Hub: `IdsExcluded(from, to)`, `GameOpened(playable, prizeCount, manifestHash)`,
`BoxOpened(openIndex, tokenId, opener)`, `GameClosed(openCount, prizesAwarded)`, `WorkerSet`,
`PausedSet`. `PrizeDraw`: `DrawRequested(openIndex, requestId)`, `OutcomeRecorded(openIndex,
opener, won, prizeIndex)`, `RecipientNominated(openIndex, recipient)`, `WorkerSet`, `PausedSet`.
Vault: `AssetApproved`, `AssetRevoked`, `DepositRegistered`, `PrizesCommitted`,
`PrizeAwarded(prizeIndex, recipient)`, `PrizeClaimed`, `PrizeExpired`, `PrizesReleased`,
`Swept`, `WorkerSet`, `PausedSet`.

*Acceptance.* When the game runs through exclusion, opening, an open, a resolution, an award, a claim and closing; then every listed event fires with the documented arguments.

**RAF-17 Reads.** Hub: game state, `PLAYABLE`, `MAX_BEARS`, `isExcluded(tokenId)`,
`opened(tokenId)`, `openIndexOf(tokenId)`, `openCount()`, `shotsLeft(wallet)`, the manifest and
its hash. `PrizeDraw`: `idsLeft()`, `prizesLeft()`, `nextToResolve()`, `outcomeOf(openIndex)`,
`recipientOf(openIndex)`, `nominationWindow`, `odds()` returning `(prizesLeft, idsLeft)`. Vault:
unreserved inventory per asset, prize by index (asset, id or amount, state, recipient),
`awardedAt(prizeIndex)`, `claimable(wallet)`, `isApproved(token)`.

*Acceptance.* When every listed read is called during an open game; then each returns without reverting and `odds()` returns `(prizesLeft, idsLeft)`.

**RAF-18 Worker sequence.** Register deposits → commit each vault → owner records the excluded
ids and opens the game → holders open boxes → relay each `BoxOpened` to `PrizeDraw` in order →
words arrive and outcomes are recorded → nomination window → post each award to its vault →
winners claim → after the claim window, expire what is unclaimed → owner closes the game → post
the close to each vault. MINT's UI shows the pool, the live odds, a wallet's shots left, its
outcomes and its claims.

*Acceptance.* When the worker sequence runs on the testnets from registration to posting the close; then each step succeeds in the listed order and a relay offered out of turn is refused.

**RAF-19 Acceptance cases.** Token baskets group correctly; two NFTs from one collection can go
to two different wallets; a deposit registered after the game opens cannot enter the pool; a
committed prize cannot be withdrawn or swept; an excluded id cannot be opened, before or after
it is sold; an id already opened cannot be opened by its buyer; a holder who sells a bear after
opening it still claims what it won; exactly the prize count is awarded when every playable id
is played; the pool neither empties early nor is left over; a relay out of order is refused; an
award that does not match `OutcomeRecorded` is detectable; a prize on ApeChain is claimed by a
nominated recipient; an unclaimed prize expires and can be withdrawn after the game closes.

*Acceptance.* When the tranche-2 test suite runs; then every listed case has a passing deterministic test.
<!-- openspec:end -->

<!-- openspec:begin retired -->
**Retired identifiers.** DEL-4 (verified testnet addresses) → OPS-3 and OPS-4; DEL-5 (deployment scripts and runbook) → OPS-2 and OPS-5; RAF-1 (a single raffle chain) → RAF-24 and RAF-26; RAF-7 (passive ownership snapshot) → RAF-28; RAF-9 (draw over calldata entries) → RAF-30; RAF-10 (carry forward between rounds) → RAF-31; RAF-12 (round cancellation) → RAF-31; RAF-13 (per-round `minLevel` eligibility) → RAF-27; RAF-20 (rounds on the hub) → RAF-26; RAF-21 (entry into a round) → RAF-28; RAF-22 (one seed per round) → RAF-29; RAF-23 (the per-round draw) → RAF-30.
<!-- openspec:end -->

## 7. Operations, roles and handover (OPS)


<!-- openspec:begin family OPS -->
MINT needs to receive contracts that are correct from their first block, verified on every chain, and handed over with every key, role and a runbook — so that operating them after 19 November needs nothing from Calea.

**OPS-1 Addresses.** The three control keys are recorded before mainnet deployment; the
royalty receiver follows, before the first sale (COL-6). `→ CQ-12`, `→ CQ-15`.

| Role | Holds | Recommendation |
|---|---|---|
| Admin | owner of every contract on every chain | Safe multisig controlled by Iñigo; one EOA per chain if Safe's interface does not cover a chain |
| Worker | `MysteryBox`, every `PrizeVault`, `PrizeDraw` | EOA held by MINT automation, funded on each chain |
| Eligibility signer | `WhitelistClaim.signer` | Backend key held by MINT; rotatable by the admin |
| Royalty receiver | ERC-2981 receiver — the pot | MINT, separate from the admin |
| Prize vaults | the `PrizeVault` contracts, one per prize chain | — |

`DirectBurnAdapter` has no role.

*Acceptance.* When the mainnet deploy scripts run; then the admin, worker and signer addresses they read are the ones MINT recorded; and the royalty receiver is set in Studio before the first sale.

**OPS-2 Deployment order.** Every address a contract needs at birth is a constructor argument,
so a contract is correct from its first block and is never deployed-but-unconfigured (MINT,
CQ-12). Two cannot be: `Activation.setCrediter`, because the adapter does not exist until
`Activation` does, and `WhitelistClaim.setSigner`, because a signer key has to be rotatable.
Both stay owner-only. Robinhood Chain: `MintABear(name, symbol, [SeaDrop])` →
`setMaxSupply(4444)` → `setTransferValidator(V3)` (COL-7) → two-step ownership transfer →
provenance, `baseURI` and royalties set by Iñigo through Studio, before the drop page is
published (COL-5, COL-6, COL-10). `WhitelistClaim(signer, openAt, closeAt)` →
ownership, before the campaign opens. `Activation(bears, thresholds, weights)` →
`DirectBurnAdapter(mntd, activation)` → `setCrediter(adapter)` → `setPaused(true)` until the
switch-on date → ownership; requires $MNTD on 4663. `MysteryBox(bears, worker)` →
ownership; `PrizeVault(worker)` → `approveAsset` per prize asset → ownership. Ethereum and
ApeChain: `PrizeVault(worker)` → approvals → ownership. The Chainlink chain:
`PrizeDraw(coordinator, subscriptionId, keyHash, worker, playable, prizeCount, manifestHash)` →
added as consumer → ownership. Each contract is deployed
before the page that depends on it is published.

*Acceptance.* When the deploy script runs on a fresh chain; then each contract is created with its constructor arguments in the listed order and is never left deployed-but-unconfigured; and only `setCrediter` and `setSigner` are called after construction.

**OPS-3 Verification.** Sourcify for 4663 and 46630 (mainnet Blockscout's API sits behind a bot
challenge); Etherscan for Ethereum and Sepolia; Apescan for ApeChain and Curtis; Basescan for
Base and Base Sepolia.

*Acceptance.* When a contract is deployed on 4663 or 46630; then its source is verified through Sourcify and readable there.

**OPS-4 Rehearsal on testnets (46630, Sepolia, Curtis, Base Sepolia).** Studio attaches to and
manages a self-deployed, validated `MintABear`; both mint paths (OpenSea and the getminted.io
mirror); a whitelist claim from voucher to exported allowlist to a two-per-wallet allowlist mint; a
burn through the adapter against $MNTD on 46630 through to a credited level; a full multi-chain
game — deposits on the testnets, commit, exclude, open, boxes opened, relays, words, outcomes,
awards, claims and expiry, including one open that wins and one that does not; an OpenSea testnet
listing of the validated collection. On mainnet, before the drop page is published: one team bear
listed and sold on OpenSea (COL-7).

*Acceptance.* When the rehearsal runs on 46630, Sepolia, Curtis and Base Sepolia; then each listed path completes end to end, including one open that wins and one that does not.

**OPS-5 Handover.** Calea deploys, configures, transfers ownership, verifies source, and delivers
the runbook; after that it holds no key and no role. Technical support runs through
19 November 2026 with agreed response hours (DEL-10). The runbook is one document, produced via
`forge script` tooling, covering deploy order (OPS-2), the enforcement toggle (OPS-6) and
Activation's pause/unpause around the burn switch-on date (ACT-11), the whitelist export (WL-4),
and the mystery-box worker sequence (RAF-18).

*Acceptance.* When handover completes; then every contract's owner is MINT's admin, every source is verified and the runbook is delivered; and Calea holds no key and no role.

**OPS-6 Enforcement runbook.** Enabled at deployment: `MintABear.setTransferValidator(0x721C002B…)`
with the validator's zero-state policy. Optional, from the admin: `createList`,
`addAccountsToWhitelist`, `addAccountsToAuthorizers`, `applyListToCollection`,
`setTransferSecurityLevelOfCollection` (never level 5 or above). Disable:
`setTransferValidator(address(0))`. Every step is an owner call and reversible.

*Acceptance.* Given enforcement enabled; when the admin calls `setTransferValidator(address(0))` and then sets V3 again; then each call emits `TransferValidatorUpdated` and the policy follows the current value.

**OPS-7 Chain constraints.** On Robinhood Chain `block.number` is the L1 height — contracts and
scripts key on timestamps. Sequencer-level compliance screening can block an individual
holder's transactions, so nothing in the system requires a holder to act by a deadline in
order for the system to stay correct: an unclaimed prize expires back to inventory, a missed
box left unopened is a shot not taken, and nothing else depends on either. Robinhood Chain
applies an Arbitrum-style per-transaction gas limit, which is why no call in this system loops
over the collection.
Randomness is not available on Robinhood Chain or ApeChain, which is why the seed comes from
Base.
<!-- openspec:end -->

## 8. Calendar (CAL)

Three anchors are fixed by MINT: TGE on 20 October, the mint on 29 October, and burns, level-up
and the first mystery box round starting on 29 October; they carry basis *MINT*. The Basis
column gives the source of every other row — *fixed* the call itself, *SoW* a date the statement
of work sets, *derived* one that follows from an anchor, *proposed* Calea's suggestion, and
*SoW; to confirm* a SoW date nobody has yet held. Every row but the three anchors and the call
is MINT's to confirm or move (`→ CQ-1`, §10 D7).

| Date (2026) | Outcome | Lead | Basis |
|---|---|---|---|
| 21 Sep | Call: the decisions in §10 | Iñigo; Calea | fixed |
| 22 Sep – 2 Oct | `MintABear` final, reviewed, deployed with the validator set; OpenSea page and URL live before promotion; team bear listed and sold; `WhitelistClaim` deployed and signer set; Studio attach proven on testnet | Calea; Iñigo | SoW |
| by 5 Oct | $MNTD test deployment on 46630 for the adapter rehearsal | MINT (Lorenzo) | proposed |
| 5 – 9 Oct | `MysteryBox`, the vaults, `PrizeDraw`, the worker and the UI tested on testnets, baskets and the win rule included; reports and runbooks; no open Critical/High | Calea; Javier; MINT | SoW |
| 6 – 26 Oct | Whitelist campaign open on getminted.io/mintabear | Iñigo; Javier; Vlad; Lorenzo | proposed |
| 12 – 14 Oct | `MysteryBox`, `PrizeDraw` and the vaults deployed, verified and funded on every prize chain; roles and official addresses verified; a multi-chain game rehearsed | Calea; Iñigo; Javier; MINT | SoW |
| 20 Oct | TGE: $MNTD live on Robinhood Chain; `Activation` and `DirectBurnAdapter` deployed, verified against the real token, paused | MINT; Calea | MINT |
| 20 – 28 Oct | Real burns rehearsed by MINT and Calea on mainnet, in windows the owner opens and closes again; `Activation` is paused outside them | Calea; MINT | derived |
| 26 Oct | Whitelist campaign closes; list exported, loaded into the Studio whitelist stage, proofs published | Iñigo; Calea | proposed |
| 29 Oct | Mint: whitelist stage, then the other stages per Studio; `Activation` unpaused — burns, level-up and Status linking open; the mystery box opens | Iñigo; Javier; Calea | MINT |
| 1 Nov | Excluded ids and the prize pool published alongside the opening; the game runs continuously from 29 Oct | Iñigo; Calea | proposed |
| from 29 Oct | Wins claimed on each prize chain — 30 days from each award (RAF-11); expiry afterwards | Winners; MINT worker | proposed |
| 5 Nov | First royalty closing block and pot split; thereafter at each ETH cap or countdown (§2) | MINT | SoW; to confirm |
| 19 Nov | Operations handed over; technical support ends (OPS-5, DEL-10) | Iñigo/Robert; Calea | SoW; to confirm |

Two decouplings hold whatever moves: the collection deploys and mints without the hub, the
vaults or the adapter being live, and `Activation` opens to holders only once the adapter has
been exercised against real $MNTD — which the owner does by unpausing for a rehearsal and
pausing again (ACT-11). One compression to note: burns open nine days after TGE, so the mainnet
rehearsal against the real token has that window; the testnet deployment on 5 October takes the
pressure off it. One overhang to note: the game runs continuously from 29 October and every win
carries its own 30-day claim window, so claims outlive the 19 November handover and the end of
technical support; the worker has to keep posting awards after both.

## 9. Deliverables and acceptance (DEL)


<!-- openspec:begin family DEL -->
The engagement needs each deliverable and the bar it is accepted against written down — so that both parties can tell when the work is done and what remains.

**DEL-1 Source.** Warning-free `forge build`; Slither with no High or Critical finding, every
accepted Medium documented.

**DEL-2 Tests.** Deterministic unit and integration tests with a branching tree per contract;
at least 90% line coverage.

**DEL-3 Review report.** Static and manual review, plus fuzzing and invariant harnesses, written
and run by Calea's internal auditor independently of the developer; report delivered with each
tranche.

*Acceptance.* When a tranche is delivered; then the internal auditor's report, with the fuzzing and invariant results, is delivered with it.

**DEL-6 Integration package.** Interfaces, events, roles and calldata examples for every
contract; a **TypeScript** client library for getminted.io, typed against the ABIs and covering
every call the app makes — mint (SeaDrop stages, allowlist proofs, `mintPublic`), whitelist claim
(voucher check and `claim`), burn (`costToReach`, approve, `burn`), link, and the mystery box (open
and prize claims on each chain) — together with its own tests and the revert reasons a caller has
to handle, so that MINT integrates against a library that has been exercised rather than against an
ABI (`→ CQ-19`); a reference script that reproduces the royalty split from `Activation.snapshot`,
dead-address exclusion included, so that "allocations plus carried rounding equal funding" is
testable by MINT.

*Acceptance.* When MINT integrates the play page; then every contract call it makes is covered by the typed TypeScript library, with passing tests and documented revert reasons, and the reference script reproduces the royalty split.

**DEL-7 Existing-contract review.** A read of the contract MINT names, within the agreed line
limit; findings only, no remediation. Unscheduled: no contract has been named, so it books no
time until one is (`→ CQ-13`).

*Acceptance.* Given MINT has named a contract within the line limit; when the review is delivered; then it lists findings only, with no remediation.

**DEL-8 Audit tranches.** Tranche 1: `MintABear`, `WhitelistClaim`, `Activation` and
`DirectBurnAdapter`. Tranche 2: `MysteryBox`, `PrizeVault` and `PrizeDraw`, once CQ-9's remaining
questions and CQ-20 are answered. Iñigo accepts after Calea and MINT sign off; anything not
accepted stays disabled in the UI.

**DEL-9 Repository.** The contracts live in MINT's monorepo (`github.com/mintdotio/NFT`) as
`packages/contracts` (`@mint/contracts`), a Foundry package with a thin `package.json` so
`pnpm -r build|test|check` reach it, with the Foundry dependencies as git submodules that CI
checks out; CI runs `forge fmt --check`, `forge build --sizes`, `forge test`, and Calea owns
that configuration. This is Calea's recommendation and what it builds if the decision is
deferred (`→ CQ-14`, `→ CQ-19`).

*Acceptance.* When the contracts land in the monorepo; then `pnpm -r build|test|check` reach the Foundry package and CI runs the three forge gates.

**DEL-10 Commercial items for Rayco's agreement.** Listed here so nothing is implied: prize
intake and unique-winner logic; weight interfaces; Studio and frontend assistance; mainnet
execution and role handover on every chain; technical support through 19 November with agreed
response hours; the existing-contract review; and two items beyond the SoW's single-chain vault
and collection: the **whitelist registry** (WL) and **multi-chain prize delivery** (a vault per
prize chain, the seed relay, the recipient nomination).

**DEL-11 Frontend collaboration.** MINT builds and owns the page holders play on — mint, raffle,
burn and level-up — in TypeScript, served from **getminted.io** (MINT, CQ-19). Calea owns the
Solidity and the TypeScript client library of DEL-6, and reviews every change that touches a
contract call before it merges. The Framer landing page stays where it is and is neither built
nor reviewed by Calea. Which repository holds these packages is `→ CQ-14`.

**DEL-12 Review sign-off.** Every Critical and High finding from DEL-3's review is fixed before
mainnet deployment.
<!-- openspec:end -->

## 10. Decisions

The call of 21 September 2026 worked through the nine decisions this document carried into it.
Seven are settled and are written into the requirements above as final state; the rest, with
what the call opened, are listed after them. Each open item states Calea's recommendation, which
is also what Calea builds if the decision is deferred.

### Settled at the call of 21 September 2026

| | Decision | Recorded in |
|---|---|---|
| **D1** | $MNTD is **native** to Robinhood Chain — canonical supply issued there, `burnFrom` reduces it; MINT's staking sits beside it and touches nothing here (CQ-2) | ACT-7 |
| **D2** | The burn thresholds are **cumulative**: 1,666 / 3,333 / 8,333 / 16,666 / 41,666 $MNTD is the total to reach each level, so level 5 costs 41,666 in all (CQ-4) | ACT-2 |
| **D4** | Whitelist claims go in an **on-chain registry** and the holder pays the gas; the CSV loaded into OpenSea is exported from that registry (CQ-18) | WL-3, WL-4 |
| **D5** | The mystery box is **instant**: one bear is one shot, the open spends that id, and the outcome is known then and there. Ownership is checked on 4663, the win is decided by a Chainlink word on the VRF chain, and each prize is claimed where it sits (CQ-9) | §6 |
| **D6** | MINT creates, funds and owns the **VRF subscription**; Calea adds `PrizeDraw` as a consumer at deployment (CQ-17) | RAF-8 |
| **D8** | The **existing-contract review** stands as a deliverable but is unscheduled; no contract has been named (CQ-13) | DEL-7 |
| **D9** | MINT builds the page holders play on, in **TypeScript on getminted.io**; Calea delivers a typed, tested TypeScript client library; the Framer landing page is out of scope (CQ-19) | DEL-6, DEL-11 |

Settled earlier and not reopened: **CQ-3** the `credit` design; **CQ-5** the weights
1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00; **CQ-6** no burn, supply 4,444 forever; **CQ-7**
royalties enforced from deployment; **CQ-10** the 30-day claim window; **CQ-11** nothing leaves a
vault while it is committed; **CQ-16** no freeze and no clawback.

### Open after the call

**O1 — Prize count, excluded ids and prize chains (CQ-20).** How many prizes there are and what
each one is; which token ids are out of play, as ranges; and the closed list of chains that hold
prizes, since each needs its own vault deployed and funded. The prize count and the excluded set
together are the odds, and both freeze when the game opens. Nothing in tranche 2 can be deployed
without them.

**O2 — Confirm the mystery box as specified (CQ-9).** MINT set the shape; §6 settles the four
things the shape left open, and Calea asks MINT to confirm them rather than assume them. An open
is decided by **its own Chainlink word**, not a shared or pre-committed seed, which is the only
arrangement in which an instant outcome is unpredictable to everyone including MINT — at the cost
of one VRF request per open. A win is drawn **from a fixed pool without replacement**, so exactly
the prize count is awarded once every playable id is played and every holder faces the same odds
going in. There is **no cap on how many prizes one wallet may win**. Prizes never won return to
MINT when the game closes.

**O3 — VRF network and the subscription wallet (CQ-17).** **Calea recommends Base**: MINT
already uses it, a request costs cents where Ethereum costs dollars, and two-second blocks keep
the wait a holder sees down to seconds. The subscription must carry one request per open for the
whole playable collection, so it is funded for that and watched with a balance alarm. Name the
wallet that will hold it.

**O4 — Addresses (CQ-12).** Admin, worker and eligibility signer before anything reaches
mainnet; the royalty receiver before the first sale (CQ-15). Supplied as constructor arguments
wherever a contract needs one at birth, as MINT asked. **Recommended:** a Safe for the admin if
its interface supports Robinhood Chain, otherwise one EOA per chain held by Iñigo; EOAs for
worker and signer; a royalty receiver that is the pot and not the admin.

**O5 — The $MNTD interface (CQ-2).** Not a decision but a dependency: does the deployed token
expose `burnFrom(address, uint256)`, how many `decimals`, and can a copy be on testnet 46630 for
the adapter rehearsal? `decimals` fixes `Activation`'s constructor values and is needed before it
is deployed.

**O6 — Calendar (CQ-1).** Left to be decided at the call. The three anchors stand — TGE
20 October, mint 29 October, burns and level-up from 29 October — and every other row of §8
carries its basis and is not a commitment until MINT confirms it. One consequence to weigh: the
game runs continuously and each win carries its own 30-day claim window, so awards and claims
outlive the 19 November handover and the end of technical support.

**O7 — Repository and CI (CQ-14).** Not reached at the call, and no longer settled by CQ-19.
**Recommended:** `packages/contracts` as `@mint/contracts` beside a typed
`packages/contracts-client`, Foundry dependencies as git submodules that CI checks out, and Calea
owning the CI configuration. Which repository holds them needs naming, against the getminted.io
split D9 made.

**O8 — One question the whitelist answer leaves (CQ-18).** Confirm that the OpenSea CSV is
exported *from* the registry rather than written *into* it, and say whether MINT ever needs to
place an address on the whitelist without a wager voucher — for a partner or a correction. If it
does, that is an owner function with its own event and it should be named now, because it changes
what the registry guarantees.

## 11. Sign-off

| Party | Name | Date | Signature |
|---|---|---|---|
| MINT | Iñigo Gaston | | |
| Calea | Bojan Jovin | | |
| Rayco | | | |

Version 2.1, 21 September 2026. The version signed carries the open items of §10 resolved;
amendments are issued as new versions of this document; requirement identifiers are never
reused.
