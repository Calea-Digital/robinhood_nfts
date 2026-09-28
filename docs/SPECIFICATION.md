<!-- GENERATED sections between openspec markers are written by docs/tools/spec_tools/render_calea_prose.py from openspec/. Edit openspec/ and the narrative here, then run docs/tools/board.sh. -->
# MintABear — Specification

<!-- openspec:begin version -->
**Version** 2.5 · **Date** 28 September 2026 · **Status** records the decisions of the
MINT–Calea calls of 21 and 28 September 2026, the tranche-1 build and review of 22–25 September
and MINT's choice of an off-chain whitelist the same day; sign-off follows the open items in §10
<!-- openspec:end -->

Prepared by Calea for MINT. Sources: *MINTaBear development statement of work* (MINT, 14 September
2026); *Mint <> Calea* meeting (15 September 2026); *MintABear questionnaire v2.0*; MINT's written
answers to specification v1.0 (September 2026); *WL Wager Based Checker* (MINT, September 2026);
the MINT–Calea calls of 21 and 28 September 2026. Where the sources differ, this document states the
resolution. Where a point is still MINT's to decide, the requirement states Calea's recommendation
— which is also what Calea builds if the decision is deferred — and points to the question (`→
CQ-n`) in the register. Section 10 records what the calls settled and what is still open.

**How to read.** Requirements carry stable identifiers: `COL-n` collection contract, `WL-n`
whitelist claim, `ACT-n` activation and burn route, `RAF-n` mystery box raffle, `OPS-n`
operations and handover, `DEL-n` deliverables. The system overview and the calendar carry the
section tags `SYS` and `CAL`, which route questions to them and carry no requirements of their
own. Each requirement is a single testable statement. An identifier
is never given a new meaning; a requirement superseded in this version is marked retired and
points to its replacement. In the client document, green callouts record MINT's answers as
confirmed; yellow callouts are decisions for the call.

## Where the work stands

As of 28 September 2026. Tranche 1 is built and reviewed: the collection, the activation
contract, and the TypeScript client library the play page is built on. The whitelist is
off-chain, in MINT's backend, and no contract is deployed for it. Calea checks the list MINT
loads into Studio. Nothing is deployed yet. The mystery box is specified in its new shape, cycles
the owner schedules, and is built once MINT supplies the excluded ids (CQ-20).

| Item | Where it stands |
|---|---|
| `MintABear` (§3) | Built and reviewed. Deploys with the transfer validator set, `maxSupply` at 4,444, and ownership offered to MINT's admin in two steps |
| Whitelist (§4) | Off-chain, in MINT's backend (WL-8). Calea checks that Studio's allowlist root is MINT's final CSV (WL-4). Two registry contracts built earlier, `WhitelistClaim` and `WhitelistImport`, stay in Calea's repository, unused |
| `Activation` (§5) | Built and reviewed. Burns $MNTD itself; paused from deployment until the switch-on date. The Status link comes out (ACT-9 retired) |
| Client library (DEL-6) | Built and reviewed. One TypeScript client for every tranche-1 call: mint with allowlist proofs, burn for a level, transfers and reads. Every error carries a stable code and a message ready to show a holder. Runnable examples cover each flow, and a reference for the voucher backend is included. The admin page's calls join it with the mystery box |
| Royalty split (DEL-6) | Built. The reference script reproduces the split at a closing block, dead-address exclusion included, and refuses inputs that miss a bear (ACT-10) |
| Deployment, verification, enforcement (§7) | Scripts written and tested. The runbook covers the handover, the whitelist check, enforcement, royalties and `Activation` |
| Tests | 242 deterministic contract tests at full line and branch coverage, and 133 client-library tests run against a local chain with the contracts deployed. Fuzzing, invariants and fork tests are the internal auditor's (DEL-3) |
| Review | Every tranche-1 requirement and the client library reviewed with Calea's reviewer; the defects found were fixed in the code, tests and documents before hand-off to the auditor |
| Testnet rehearsal (OPS-4) | Next, once MINT's testnet $MNTD is on 46630 (CQ-2) |
| Mystery box (§6) | Specified: `MysteryBox` on Robinhood Chain and `PrizeDraw` on Arbitrum One, with prizes paid from MINT's wallet. Built once the 222 excluded ids arrive (CQ-20) |

**What the client library needs from MINT.** None of these changes a contract. Each is needed
before the page it serves goes live.

- **The final whitelist CSV**, one row per wallet with its total, frozen at least 48 hours before
  the whitelist stage (WL-4, WL-5).
- **OpenSea's fee recipient for the drop**, which every mint names. Also access to OpenSea's
  listings API, so the page can warn a holder whose bear is listed before a burn.
- **An archive RPC endpoint for Robinhood Chain**, for the royalty split at each closing block
  (ACT-10).
- **The wording of the messages holders see.** The library carries plain-English defaults for
  every error, and MINT may replace or translate them by code.

**Changes since version 2.3.** From the call of 28 September 2026 and its follow-up.

- **Mystery box.**
  - It runs in cycles the owner schedules, each with its window, its prize count and the hash of
    its published prize list (RAF-32).
  - Each playable bear has one shot per cycle, and every bear gets a shot again in the next
    (RAF-28). 222 team ids are excluded for good (RAF-27).
  - Within a cycle the odds are fixed, and prizes not awarded stay with MINT to roll forward
    (RAF-30).
  - The draw runs on Arbitrum One (RAF-8).
  - Prizes are held in MINT's prize wallet on Robinhood Chain, Ethereum and possibly ApeChain,
    paid by transfer and recorded on `PrizeDraw` (RAF-33). No contract is deployed on a prize
    chain: the vaults and the on-chain nomination are retired.
- **Whitelist.** Off-chain, in MINT's backend (WL-8). There is no whitelist contract to deploy
  or audit. The final CSV goes into Studio, and Calea checks Studio's root against it (WL-4).
  The voucher registry is retired (WL-3), and so is the owner-imported one built as a variant on
  28 September (WL-7).
- **Activation.** The Status link is removed. MINT assigns Status links to holders' Privy
  accounts off-chain (ACT-9 retired, CQ-21).
- **Addresses.**
  - the collection owner `0x1530…6141`, assumed to own every contract;
  - the royalty receiver `0xf7E7…0e63`;
  - the prize wallet `0xf6c0…e3e3` (OPS-1).
- **$MNTD.** Read from the reference token MINT pointed to: OpenZeppelin `ERC20Burnable`, 18
  decimals, fixed supply, no owner and no proxy (CQ-2).
- **Repository.** Calea's recommendation is accepted (DEL-9).

## 1. Scope

### 1.1 In scope — Calea / Rayco

- **MintABear** collection contract on Robinhood Chain (chain id 4663), SeaDrop-compatible,
  managed through OpenSea Studio by MINT, royalties enforced.
- **Whitelist support**: the check that Studio's allowlist is MINT's final CSV, and the mint
  proofs built from it (WL-4). The whitelist itself is MINT's, off-chain (WL-8).
- **Activation** contract on Robinhood Chain: burns $MNTD for a bear and records it, level
  derivation (0–5), royalty-weight table.
- **Mystery box**: `MysteryBox` on Robinhood Chain (ownership, cycles, the bear spent for the
  cycle, the open register) and `PrizeDraw` on Arbitrum One (one VRF word per open, the win rule,
  the outcome, the payout record) (`→ CQ-20`).
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
purchase, the splitter wallet and the crediting of getminted.io accounts, Calea delivering only a
reference script that reproduces the split (DEL-6); the Status boost and the Status links, kept
against Privy accounts; holding and paying the prizes, from MINT's prize wallet (RAF-33); the admin
page; monitoring and alerts (MINT); bridging prize assets between chains; cross-chain messaging
infrastructure.

### 1.3 Parties and responsibilities

| Party | Responsibility |
|---|---|
| Iñigo (MINT) | Collection management in OpenSea Studio; admin of every contract; approves prize assets; funds treasury with Robert; UI with Javier; accepts deliverables |
| Robert (MINT) | Funds treasury and reserves; settlement |
| Javier (MINT) | UI on getminted.io (`→ CQ-19`) |
| Lorenzo (MINT) | Shared Privy login; account, Status and wager APIs; names the contract for review (`→ CQ-13`) |
| Vlad (MINT) | Privy connect on getminted.io and the wager API, with Lorenzo |
| Guri (MINT) | Eligibility checker |
| MINT | Admin (`0x1530…6141`): the excluded ids, each cycle's schedule and prize list, pauses. Prize wallet (`0xf6c0…e3e3`): holds and pays the prizes. Backend: the off-chain whitelist register (WL-8) |
| Worker | Relays each open to the draw in order and records each payout. Assumed to be operated by Calea (`→ CQ-23`) |
| Calea / Rayco | Contracts, tests, scripts, runbook, testnets, review, integration support; deploys and hands over; keeps no owner key, and no role but the worker's if CQ-23 gives it |
| Calea internal auditor | Fuzzing and invariant harnesses, review report |

## 2. System overview (SYS)

**Chains.**

| Chain | Id | Hosts | Testnet |
|---|---|---|---|
| Robinhood Chain | 4663 | `MintABear`, `Activation`, `MysteryBox`; prizes in MINT's wallet | 46630 |
| Arbitrum One | 42161 | `PrizeDraw` (Chainlink VRF v2.5) | Arbitrum Sepolia 421614 |
| Ethereum | 1 | prizes in MINT's wallet; no contract | Sepolia 11155111 |
| ApeChain | 33139 | prizes in MINT's wallet if MINT confirms it; no contract (`→ CQ-20`) | Curtis 33111 |

Robinhood Chain stores the bears and is the source of truth for ownership, levels
and which bears have been opened in a cycle. Randomness comes from Arbitrum One, which has
Chainlink VRF v2.5; Robinhood Chain and ApeChain have none. Prizes stay in MINT's prize wallet
`0xf6c0…e3e3` on the chain where each one sits, and are paid from there (RAF-33).

**Contracts.**

| Contract | Chain | Purpose |
|---|---|---|
| `MintABear` | 4663 | ERC721SeaDrop collection, 4,444 supply, transfer counter, enforced royalties |
| `Activation` | 4663 | $MNTD burned for a bear → level → weight |
| `MysteryBox` | 4663 | Cycles, the excluded ids, the ownership check and the open register |
| `PrizeDraw` | 42161 | One VRF word per open, the win rule, the recorded outcome, the payout record |

The whitelist has no contract: it is MINT's register, off-chain (WL-8).

**Trust model.**
- **The contracts enforce** ownership, supply, the transfer counter, level derivation, the weights
  table, one shot per bear per cycle, the excluded ids, and the
  draw and its order.
- **MINT holds the admin key**, one externally owned account for every contract (assumed, `→
  CQ-12`). It schedules each cycle and publishes its prize list.
- **MINT's prize wallet holds and pays the prizes.** Nothing on-chain forces a payout, and MINT can
  move any prize at any time. What the chain does guarantee is the record: every win is an
  `OutcomeRecorded` on Arbitrum, and every payout a `PrizePaid` naming the chain and the
  transaction.
- **The worker relays each open** from Robinhood Chain to the draw, and records each payout. It is
  publicly checkable against `BoxOpened` and `OutcomeRecorded`. The draw refuses an open out of
  turn, so the worker cannot choose which open meets which state of the pool. It can delay one,
  and a delayed open is visible. The worker cannot alter weights or thresholds, raise a level
  without a burn, open a box, change an outcome, or put a wallet on the whitelist.
- **The whitelist is MINT's word.** MINT's backend decides who is on it and keeps the count. The
  chain holds only Studio's allowlist root, which Calea checks against MINT's final CSV.

**On-chain.** Ownership and transfers; the transfer counter and its event; the whitelist's allowlist
root; recorded burns, cumulative totals, levels and weights; cycles, excluded ids and opens;
words, outcomes and payout records.

**Off-chain (MINT).**
- Wager measurement and the Season 1 back-credit, and the whitelist register itself (WL-8).
- The Privy login that ties a wallet to a getminted.io account, and the Status links kept against
  it.
- The royalty pot and its split: when the pot reaches its ETH or its countdown ends, half the ETH
  buys $MNTD, and ETH and $MNTD move to a splitter wallet that credits getminted.io accounts by
  wallet weight (ACT-10). Crediting an account requires knowing which account a holding wallet
  belongs to, which the Privy login supplies and the chain does not.
- The prize lists and the prizes.
- The Status boost; indexing, alerts, the UI and the admin page.

What level 5 is *worth* is MINT's to define; the chain records that it was reached.

**Flow.**
1. **Whitelist.** Holders check their wagering on getminted.io and claim their spots, which MINT's
   backend records. When the list is frozen, MINT loads the final CSV into the Studio allowlist
   stage, and Calea checks the root.
2. **Drop.** Iñigo runs the drop in Studio; holders mint via OpenSea or the getminted.io mirror.
3. **Burn.** Holders burn $MNTD for a bear on `Activation`, which records the burn, and the bear's
   level and weight follow.
4. **Transfer.** Any transfer advances the counter and voids level and weight.
5. **Mystery box.** The owner records the excluded ids once. For each cycle it publishes the prize
   list and schedules the cycle on both chains. A holder opens a box with a bear, which spends
   that bear for the cycle. The worker relays the open in turn, and a Chainlink word decides it.
   A win is paid from MINT's prize wallet on the prize's chain and recorded on `PrizeDraw`.
6. **Royalties.** MINT reads `Activation.snapshot` at each royalty closing block and splits the pot
   off-chain.

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

**COL-3 Transfer counter.** `transferNonce(tokenId)` increments on every transfer except mint — sales, gifts,
self-initiated moves and return transfers to a previous owner alike — and never resets. It is
the mechanism by which every ownership change resets level and weight (ACT-5).

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
receiver the royalty-pot address MINT names, distinct from the admin and from the prize wallet (RAF-33). Set
by Iñigo in Studio at any point before the first sale; it does not hold up deployment. `→ CQ-15`
(receiver).

*Acceptance.* Given royalty info set in Studio to 500 basis points and the pot address; when `royaltyInfo(id, salePrice)` is read; then it returns the pot address and 5% of `salePrice`.

**COL-7 Creator token and enforced royalties.** `MintABear` implements `ICreatorToken` (ERC-721C)
and is deployed with the transfer validator **set**:
`setTransferValidator(0x721C002B0059009a671D00aD1700c9748146cd1B)`, Limit Break validator V3 on
4663, with the validator's zero-state policy — security level 0 (operator whitelist,
holder-initiated transfers always allowed, no receiver constraint) and list 0 (Limit Break
Payment Processor whitelist with OpenSea's SignedZone `0x000056F7000000EcE9003ca63978907a00FFD100`
as authorizer). Consequence: a transfer the holder makes itself always passes; a sale a marketplace
operates settles only through OpenSea (SignedZone-restricted orders) or a Payment Processor
marketplace, and creator earnings are collected on every such sale; a Seaport order from any
other venue reverts. Because the holder's own transfers pass, a sale arranged outside a
marketplace — directly, or through an escrow contract the holder sends the bear to — pays no
creator earnings; every level that lets holders move their own bears allows it.
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
remains a bear in the supply: nobody can open a mystery box with it (RAF-28), and the royalty
snapshot excludes the canonical dead address (ACT-10).

*Acceptance.* When anyone, the owner included, calls `burn` or transfers a bear to the zero address; then it reverts with `BurnDisabled`; and `totalSupply` is unchanged.

**COL-9 No token-bound accounts.** ERC-6551 is not part of the collection. It can be added later
without any change to `MintABear`: the canonical registry
`0x000000006551c19487814612e58FE06813775758` derives an account address from
`(chainId, tokenContract, tokenId)` for any ERC-721. The one property that cannot be retrofitted
is a token-side guard against sending a bear into a bear's account.

*Acceptance.* When the deployed `MintABear` is inspected; then it holds no ERC-6551 account code, no account guard and no registry call.

**COL-10 Ownership.** Deployed by Calea; ownership transferred to MINT's admin address by the
inherited two-step process (`transferOwnership`, then `acceptOwnership` from the admin) before
the drop page is published. Calea retains no role. The collection always has an owner:
`renounceOwnership` reverts for every caller, the owner included, because an ownerless collection
would freeze every owner setting — Studio's drop configuration, `baseURI`, royalties and the
transfer-validator lift and restore (OPS-6) — and a pending ownership offer would survive it.

*Acceptance.* Given Calea has called `transferOwnership(admin)`; when the admin calls `acceptOwnership`; then the admin is the owner; and Calea holds no role, and `renounceOwnership` reverts for the admin as for anyone else.

**COL-11 What Studio owns.** Mint stages, dates and pricing; allowlists and per-wallet limits,
including the whitelist stage loaded from MINT's final CSV (WL-4); payout address; `maxSupply`
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

**WL-1 Rules.** From MINT's brief, as MINT's backend applies them (WL-8):

- **1,000 spots**, each the right to mint one bear in the whitelist stage. A spot is an
  allocation: an account at $100 holds two of the 1,000.
- **First come, first served** through getminted.io/mintabear. Reaching a threshold makes the
  getminted.io account eligible for the spot it unlocks; it reserves nothing. A spot belongs to a
  wallet once the backend has recorded its claim.
- **$50 wagered unlocks spot 1; $100 unlocks spot 2.** Historical wagering (Season 1) counts up
  to $50, so spot 2 always needs at least $50 of in-campaign wagering. A holder with $16,361 of
  historical wagering is shown $50: one spot claimable, and $50 more to wager for the second.
- **Live counter** "wagering spots left — X / 1,000", read from MINT's backend. A claim that
  arrives after the last spot is refused whole.
- **The holder selects the NFT wallet** before claiming.
- **Two per wallet, two per account.** Whether spots from collaborations and giveaways count
  toward the 1,000, and whether they may take a wallet above two, is `→ CQ-18`.

**WL-2 Division of work.** **MINT's part:**
- the Privy login on getminted.io;
- the wager API, which returns historical wagering capped at $50 and in-campaign wagering;
- the eligibility check and the UI;
- the off-chain register with its counter, and the wallet signature for pasted addresses (WL-8);
- the final CSV.

**Calea's part:**
- the check that Studio's allowlist root is the CSV's (WL-4);
- the mint proofs for the getminted.io mirror, built from the same CSV (DEL-6);
- a review of the backend's claim rules, on request.

**WL-4 Into the mint.** When the list is frozen (WL-5), MINT exports the final CSV — `wallet,allocations`, one row per
wallet — and Iñigo loads it as the whitelist stage's allowlist in Studio. SeaDrop allowlist
entries carry a per-wallet mint limit, so "one or two" is enforced by the mint itself.

That limit counts every bear minted to the wallet in any stage. So:
- the whitelist stage is the first stage in which any wallet can mint, apart from the team's
  (COL-11);
- no other stage overlaps it;
- a later stage's per-wallet limit counts the whitelist mints too.

Calea's `compare` rebuilds the allowlist root from the CSV and the stage's parameters, and fails
unless it is the root on SeaDrop. The getminted.io mirror builds its Merkle proofs from the same
CSV (DEL-6).

*Acceptance.* Given MINT's final CSV and the whitelist stage Studio has set; when `compare` runs over the CSV and the stage; then it passes only if the root on SeaDrop is the root of the CSV's rows, and fails naming the difference otherwise.

**WL-5 Timing.** MINT's backend accepts claims only within the campaign window, and the list is frozen at least
48 hours before the whitelist stage opens. That leaves time for the Studio upload, the root check
and a fix before minting. With the whitelist stage opening with the mint on 29 October, the list
is frozen by 27 October, at the same time of day. The 48 hours is Calea's buffer, not a SeaDrop
rule. Dates `→ CQ-1`; calendar in §8.

**WL-8 Off-chain register.** The whitelist is kept off-chain, in MINT's backend (MINT, 28 September 2026, `→ CQ-18`). No
contract is deployed for it.

**The flow.**
1. A holder signs in on getminted.io through Privy, or pastes a wallet address.
2. The eligibility check shows what the account has wagered and what is left to unlock a spot or
   the next one.
3. The holder claims the spots unlocked. A pasted address proves itself with a wallet signature,
   which costs no gas; a wallet connected through Privy already has.
4. The backend records the claim.

MINT's backend keeps the 1,000-spot counter so that two simultaneous claims cannot take the last
spot. It also records whitelist spots from any other source, such as collaborations and
giveaways, in the same register. The final list has **one row per wallet with its total**,
merged across sources, and is the CSV loaded into Studio (WL-4). Nothing about the whitelist is
public until Studio's allowlist root is set; the root is its only trace on-chain.
<!-- openspec:end -->

## 5. Activation and burn route (ACT)


<!-- openspec:begin family ACT -->
Holders need to burn $MNTD to raise a bear's level and weight, and MINT needs to read those weights for the royalty split, in a way no key can forge and every transfer resets — so that a level is always evidence of a burn by the current owner.

**ACT-1 One token, one collection.** `Activation` holds one token reference, $MNTD, fixed in its constructor, and
uses it for one thing: burning the caller's own $MNTD in `burn` (ACT-7). It records burned
amounts per bear and derives level and weight from them. It reads `MintABear` (`ownerOf`,
`transferNonce`, `exists`); `MintABear` never calls it, so no defect in `Activation` can affect a
transfer. In plain terms: recording the level and burning the tokens are two steps of one
transaction, the record first — `Activation` adds the amount to the bear, then burns it from the
holder — and any revert undoes both.

*Acceptance.* When `Activation`'s code and constructor are inspected; then its only calls to $MNTD are `decimals` in the constructor and `burnFrom` of the caller's own balance in `burn`, and it moves no other token; and it reads only `MintABear`'s `ownerOf`, `transferNonce` and `exists`.

**ACT-2 Thresholds.** Five cumulative thresholds `T1 < T2 < T3 < T4 < T5`, supplied to the
constructor in whole $MNTD and scaled there by the token's `decimals` into base units, which are
immutable; `DECIMALS` reads the value used. A bear's level is the highest `k` with
`cumulative ≥ Tk`, or 0. `thresholdFor(level)` and `costToReach(tokenId, level)` expose them in
base units. The figures are 1,666 / 3,333 / 8,333 / 16,666 / 41,666 $MNTD, read cumulatively:
each is the total a bear must have burned to stand at that level, so level 5 costs 41,666 $MNTD in
all (MINT, CQ-4).

| Level | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Total burned to reach it | 1,666 | 3,333 | 8,333 | 16,666 | 41,666 |

*Acceptance.* Given the thresholds 1,666 / 3,333 / 8,333 / 16,666 / 41,666 whole $MNTD and a token with 18 decimals; when a bear's cumulative reaches 8,333 $MNTD; then `levelOf` reads 3 and `costToReach(id, 4)` reads 8,333 × 10^18.

**ACT-3 Weights.** Six royalty weights for levels 0–5, basis 100, supplied to the constructor
and immutable: `100 / 110 / 125 / 145 / 170 / 200` (1.00× to 2.00×), confirmed by MINT.
`weightFor(level)` returns the table entry; `weightOf(tokenId)` returns the weight of the bear's
current level.

*Acceptance.* Given the weights 100 / 110 / 125 / 145 / 170 / 200; when a bear at level 3 is read; then `weightOf` returns 145 and `weightFor(5)` returns 200.

**ACT-4 Burn record.** `burn(uint256 tokenId, uint128 amount)` reverts unless: not paused
(`ContractPaused`); `amount > 0` (`ZeroAmount`); `ownerOf(tokenId) == msg.sender`
(`NotBearOwner`); the bear is below level 5 (`AlreadyAtMaxLevel`); `amount ≤ costToReach(tokenId,
5)` (`Overshoot`, ACT-8). Effects, in order: the cumulative for the bear's current counter value
increases by `amount`; `lifetimeBurned` increases by `amount`; `BearActivated(tokenId, burner,
previousLevel, newLevel, amount, cumulative)` is emitted; then `MNTD.burnFrom(msg.sender, amount)`.
The owner check and the counter are read in the same call as the record, so a burn is never
recorded for a bear its burner does not hold. `burn` is non-reentrant: a call made from inside the
token's `burnFrom` is refused.

*Acceptance.* Given the owner of a bear below level 5 who has approved `Activation` on $MNTD; when the owner calls `burn(tokenId, amount)`; then the cumulative and `lifetimeBurned` grow by `amount`, `BearActivated` is emitted and the owner's $MNTD falls by `amount`; and a `burn` made from inside the token's `burnFrom` reverts.

**ACT-5 Reset.** Cumulative and level read as zero, and the weight reads the level-0 weight (ACT-3), whenever
the counter value they were recorded at differs from the current `transferNonce`. The reset is
a consequence of the transfer (COL-3), not an action: it cannot be skipped and cannot block a
transfer. Return transfers reset like any other.

*Acceptance.* Given a bear at level 2; when it is transferred to another wallet; then `levelOf` and `cumulativeOf` read zero and `weightOf` reads `weightFor(0)`, with no call into `Activation`.

**ACT-6 Lifetime.** `lifetimeBurned(tokenId)` accumulates every burn ever recorded for a bear
and never resets.

*Acceptance.* Given a bear burned for twice with a transfer in between; when `lifetimeBurned` is read; then it is the sum of both burns.

**ACT-7 Burn route.** $MNTD is native to Robinhood Chain (MINT, CQ-2): its canonical supply is
issued there and `burnFrom` reduces it, so a burn removes supply outright and needs nothing said
about it publicly. `Activation` takes its address as an immutable constructor argument; a
different token address means a new `Activation`, so the address must be final before deployment
(`→ CQ-2`). The holder approves `Activation` on $MNTD once and calls `burn(tokenId, amount)`
(ACT-4), which records the burn and calls `MNTD.burnFrom(msg.sender, amount)` in the same
transaction. Requirements on $MNTD: an ERC-20 on 4663 exposing `decimals()` and
`burnFrom(address, uint256)` (OpenZeppelin `ERC20Burnable`) that reverts rather than returning
false on failure. A bridged or mint-and-burn representation, a burn on another chain with an
attested record on 4663, and cross-chain messaging are all out. MINT's staking sits beside the
token on the same chain and touches nothing here. The token's `burnFrom`, `decimals` and the
finality of its address are still to be confirmed against the deployed contract (`→ CQ-2`).

*Acceptance.* Given the holder has approved `Activation` on $MNTD; when the holder calls `burn(tokenId, amount)` for a bear below level 5; then the burn is recorded and `burnFrom` executes in one transaction, and `BearActivated` is emitted; and a call by a non-owner reverts with `NotBearOwner`.

**ACT-8 Overshoot.** `burn` refuses any amount beyond what level 5 needs, so no $MNTD is
destroyed for nothing. The portal sizes each burn with `costToReach(tokenId, targetLevel)`,
which returns the exact remainder or zero.

*Acceptance.* Given a bear whose `costToReach(id, 5)` reads x; when the holder calls `burn(id, x + 1)`; then it reverts with `Overshoot` and no $MNTD is burned.

**ACT-10 Snapshot view.** `snapshot(uint256[] ids) → (address owner, uint8 level, uint16
weight)[]`, returning zeroes for ids that do not exist. MINT's royalty accounting counts, at each
closing block, every bear that has an owner among ids `1..4444`: a wallet's weight is the sum over
its bears, and the total eligible weight is the sum over all bears whose owner is not the canonical
dead address `0x000000000000000000000000000000000000dEaD` (COL-8). Because transfers reset weight
without any call into `Activation`, there is no on-chain running total; the sum is taken off-chain.
The reference script (DEL-6) reads the inputs from an archive node at the closing block, in either
of two ways that agree:
- owners from the collection's `Transfer` events and weights from `weightOf`, for owned ids only,
  since `weightOf` answers the level-0 weight for an id never minted;
- `snapshot`, paged by a gas budget. Each id's owner lookup walks back to the start of its mint
  batch, so one call over the whole range is not dependable (56.2M gas at two bears per wallet).

The script refuses inputs that miss a minted bear, and its allocations plus the rounding carried to
the next distribution equal the funding. MINT credits the resulting shares to getminted.io accounts
through its wallet (§2).

*Acceptance.* When `snapshot([1, 2, 4445])` is read; then it returns owner, level and weight for ids 1 and 2 and zeroes for the id that does not exist.

**ACT-15 Pause.** The owner may pause. While paused, `burn` reverts; reads and every transfer are unaffected. No
$MNTD is burned while paused, which is how burns stay closed between deployment and the
switch-on date (§8). The pause admits no exemption: no address may burn while it is on. So the
mainnet rehearsal against real $MNTD runs in a window the owner opens and closes again (§8).
`renounceOwnership` reverts for every caller, so the pause can always be set and lifted.

*Acceptance.* Given the owner has paused; when a holder calls `burn`; then it reverts with `ContractPaused`; and reads and every transfer still succeed.

**ACT-12 Roles.** Owner (MINT's admin): `setPaused` and ownership transfer; `renounceOwnership` reverts. A bear's
owner: `burn` for that bear. Nothing else is administrable: the token, thresholds, weights and
records are immutable, and no address can record a level without burning. There is no freeze or
clawback path into a bear anywhere (MINT, CQ-16). Which bear carries an account's Status boost
is MINT's, recorded against the holder's Privy account off-chain (MINT, CQ-21); `Activation`
records levels only.

*Acceptance.* When a non-owner calls `setPaused`, or anyone calls `renounceOwnership`; then it reverts; and no function anywhere changes the token, thresholds, weights or a bear's record other than its owner's `burn`.

**ACT-13 Events.** `BearActivated(tokenId, burner, previousLevel, newLevel, amount, cumulative)` (ACT-4) and
`PausedSet(paused)`.

*Acceptance.* When a burn and a pause happen; then `BearActivated` and `PausedSet` are emitted with the documented arguments.

**ACT-14 Reads.** `levelOf`, `cumulativeOf`, `lifetimeBurned`, `weightOf`, `weightFor`, `thresholdFor`,
`costToReach`, `snapshot`, `paused`, `BEARS`, `MNTD`, `DECIMALS`.

*Acceptance.* When every listed read is called for a bear that has been burned for; then each returns without reverting; and `BEARS` and `MNTD` return the deployed addresses and `DECIMALS` the token's decimals.
<!-- openspec:end -->

## 6. Mystery box raffle (RAF)


<!-- openspec:begin family RAF -->
A holder opens a mystery box with a bear they own and learns the outcome there and then. The box
runs in cycles the owner schedules: within a cycle each playable bear is one shot, and the next
cycle gives every bear a shot again, whoever holds it (MINT, CQ-9). Two contracts: `MysteryBox`
on Robinhood Chain, where the bears are, so an open is checked against live ownership, and
`PrizeDraw` on Arbitrum One, which decides each open with a Chainlink word of its own and records
each payout. The prizes stay in MINT's prize wallet on the chain where each one sits, and are paid
from there.

**RAF-32 Cycles.** The mystery box runs in **cycles**, and the owner (MINT's admin) sets each one before it starts
(MINT, CQ-9, CQ-20). `scheduleCycle(start, end, prizeCount, manifestHash)` on `MysteryBox`
records the next cycle:
- the window in which boxes may be opened;
- how many prizes it carries;
- the hash of the prize list MINT publishes for it (RAF-27).

Scheduling is refused while a cycle is open (`CycleInProgress`). It is also refused for a
window that starts in the past, starts before the previous cycle ends or ends before it starts
(`InvalidWindow`), and for a prize count of zero or above `PLAYABLE` (`InvalidPrizeCount`).

A cycle scheduled but not yet started may be replaced by scheduling again. From its `start` its
terms are fixed. A cycle is **open** from `start` to `end` inclusive, and nothing opens a box
outside it. When `end` passes, the cycle is over: the opens made inside it are still resolved
(RAF-29). The prizes it did not award stay in MINT's prize wallet (RAF-33), for MINT to carry
into a later cycle's list. The owner decides when the next cycle starts, so the game can stand
still between cycles for as long as MINT needs to fund the next one.

`PrizeDraw` carries each cycle's `prizeCount` and `manifestHash` too, set by the owner with
`scheduleCycle(cycleId, prizeCount, manifestHash)` before the cycle's first open is resolved.
Both chains emit `CycleScheduled`, so anyone can check that they were given the same cycle.

*Acceptance.* Given the owner has scheduled cycle 1 from `start` to `end` with 5 prizes; when a holder opens a box before `start`, between `start` and `end`, and after `end`; then only the open between `start` and `end` succeeds, and the others revert with `CycleNotOpen`; and scheduling cycle 2 while cycle 1 is open reverts with `CycleInProgress`.

**RAF-27 Playable ids and the prize pool.** Two numbers fix the odds of a cycle: the playable ids and the cycle's prize count.

**Excluded ids.** The owner records them as ranges with `excludeRange(from, to)` (event
`IdsExcluded`). This is allowed only until the first cycle is scheduled, and the set is frozen
for good after that (`ExclusionFrozen`). MINT excludes **222** team bears; which ids is
`→ CQ-20`. An excluded bear is out of play whoever holds it, so a team bear that is sold stays
out. `PLAYABLE = MAX_BEARS − excluded`, 4,222 with MINT's figure. It is fixed when the first
cycle is scheduled, and it is `PrizeDraw`'s constructor argument, so the excluded ranges are
final before `PrizeDraw` is deployed.

**Prize list.** Each cycle's prize list is published by MINT before the cycle starts: for each
prize, its chain, its token and its id or amount, in order. Its hash is the cycle's
`manifestHash` (RAF-32). The *n*-th prize awarded in a cycle is entry *n* of its list. Only the
count and the hash are on-chain. The prizes themselves are in MINT's prize wallet (RAF-33), so
the list is MINT's commitment, and the contracts cannot check it against a balance.

*Acceptance.* Given ranges excluded totalling 222 ids; when the owner schedules the first cycle; then `PLAYABLE` reads 4,222 and `excludeRange` reverts with `ExclusionFrozen`.

**RAF-28 Opening a box.** `open(uint256 tokenId)` on `MysteryBox`, by the wallet that is `ownerOf(tokenId)` at that
moment. It reverts in any of these cases:
- the hub is paused (`ContractPaused`);
- no cycle is open (`CycleNotOpen`);
- the caller is not `ownerOf(tokenId)` (`NotBearOwner`);
- the id is excluded (`IdExcluded`);
- the id has already been opened in this cycle (`AlreadyOpened`).

Effects: the id is spent for the cycle, the next `openIndex` is assigned (one sequence across
all cycles), and `BoxOpened(openIndex, cycleId, tokenId, opener)` is emitted. Opening is free
apart from gas.

**One bear, one shot per cycle** (MINT, CQ-9): a spent bear stays freely transferable, and
nobody can open it again in the same cycle, its buyer included. In the next cycle whoever holds
it may open it again. `shotsLeft(wallet)` returns the wallet's playable bears not yet opened in
the open cycle: a holder of ten bears who has opened two sees eight.

*Acceptance.* Given an open cycle and a holder of a playable bear not yet opened in it; when the holder calls `open(tokenId)`; then `BoxOpened(openIndex, cycleId, tokenId, opener)` is emitted and `shotsLeft(holder)` falls by one; and the buyer of that bear cannot open it again in the same cycle, reverting with `AlreadyOpened`, and may open it in the next.

**RAF-29 Resolution, in order.** Each open is resolved on `PrizeDraw` by `resolve(uint64 openIndex, uint64 cycleId,
address opener)`, which the worker relays from the `BoxOpened` event. `PrizeDraw` refuses:
- any `openIndex` but the next unresolved one (`OutOfOrder`), so the worker cannot choose which
  open meets which state of the pool;
- a cycle it has not been given, or one earlier than the last it resolved (`UnknownCycle`).

The worker can only delay an open, and a delayed open is visible as a `BoxOpened` with no
`OutcomeRecorded`. `resolve` requests one Chainlink word and emits
`DrawRequested(openIndex, requestId)`. Several requests may be in flight at once. Outcomes are
applied strictly in `openIndex` order as the words arrive, so an open waits on the words of the
opens before it and on nothing else. An open made before its cycle's `end` is resolved even if
the word arrives after it.

*Acceptance.* Given opens 1 and 2 recorded and neither resolved; when the worker calls `resolve(2, cycleId, opener)`; then it reverts with `OutOfOrder`; and `resolve(1, cycleId, opener)` requests one Chainlink word and emits `DrawRequested`.

**RAF-30 The win rule (normative).** Within a cycle, let `idsLeft` be the playable ids not yet resolved and `prizesLeft` the prizes
not yet awarded. They start at `PLAYABLE` and the cycle's prize count. On the word `w` for
`openIndex i`:

- `won = (w mod idsLeft) < prizesLeft`;
- if `won`, the next unawarded entry of the cycle's prize list is assigned to `i`'s opener, and
  `prizesLeft` decreases by one;
- `idsLeft` decreases by one either way;
- `OutcomeRecorded(openIndex, cycleId, opener, won, prizeIndex)` is emitted, where `prizeIndex`
  is the entry of the list and carries no meaning when `won` is false.

Properties:
- every holder faces the same odds before opening, `prizesLeft / idsLeft`;
- a cycle in which every playable bear is opened awards exactly its prize count;
- a cycle that ends with bears unopened awards fewer, with the rest staying in MINT's wallet
  (RAF-32) — MINT's choice, fixed odds over prizes rolled forward (CQ-9);
- a wallet's chances are proportional to the playable bears it holds, with one shot per bear per
  cycle as the only cap (MINT, CQ-9).

*Acceptance.* Given a cycle with `idsLeft` at 10, `prizesLeft` at 2 and a word w with `w mod 10 == 1`; when the open is resolved; then `won` is true, the next entry of the cycle's prize list is assigned, `prizesLeft` reads 1 and `idsLeft` reads 9.

**RAF-8 Randomness.** Chainlink VRF v2.5, with one request and one word per open. `PrizeDraw` runs on **Arbitrum One**
(chain id 42161), agreed with MINT on 28 September 2026: coordinator
`0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e`, and on Arbitrum Sepolia (421614)
`0x5CE8D5A2BC84beb22a398CCA51996F7930313D61`. `PrizeDraw` is the subscription's consumer. The
subscription is assumed to be owned and funded by MINT (`→ CQ-17`). One request per open is what
buys an outcome nobody can predict, MINT included. The subscription is funded for a cycle's
worth of requests, at most `PLAYABLE`, and topped up on a balance alarm, not on a schedule.
Robinhood Chain has no Chainlink VRF and no usable `prevrandao`, which is why the draw is not on
the chain the bears live on.

*Acceptance.* When `resolve` runs; then exactly one VRF v2.5 request is made from the subscription with `PrizeDraw` as consumer; and the outcome uses that request's word alone.

**RAF-33 Prize custody and the payout record.** Prizes are held in MINT's prize wallet `0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3`, an
externally owned account, on each chain that holds a prize (MINT, CQ-8, CQ-20): Robinhood Chain,
Ethereum and possibly ApeChain. No contract is deployed on a prize chain and no contract holds a
prize. A prize is paid by an ordinary transfer from that wallet to the opener's address on the
prize's chain. Whether MINT pushes every win or the winner requests it within a window is
`→ CQ-22`; the default is that MINT pushes. Nothing on-chain forces a payout, and MINT can move
any prize at any time: custody is MINT's by its choice, and the chain records what was paid.

The worker records each payout on `PrizeDraw` with `recordPayout(openIndex, chainId, txHash)`.
The call is refused unless the outcome of `openIndex` is a win (`NotAWin`) and has not been
recorded as paid (`AlreadyPaid`). It emits `PrizePaid(cycleId, openIndex, chainId, txHash)`, so
anyone can match each recorded win to a transfer on the named chain, and see a win with no
`PrizePaid`. The recipient is the opener. There is no on-chain nomination: a holder whose
address cannot receive on a prize chain is MINT's to settle by hand, and the UI warns
contract-wallet holders before they open.

*Acceptance.* Given open 7 recorded as a win; when the worker calls `recordPayout(7, 1, txHash)`; then `PrizePaid(cycleId, 7, 1, txHash)` is emitted; and a second `recordPayout` for open 7 reverts with `AlreadyPaid`, and one for an open that did not win reverts with `NotAWin`.

**RAF-14 Roles.** Owner (MINT's admin):
- on `MysteryBox`: `excludeRange`, `scheduleCycle`, `setPaused`;
- on `PrizeDraw`: `scheduleCycle`, `setWorker`, `setPaused`;
- ownership transfer on both.

`renounceOwnership` reverts on both.

Worker: `resolve` and `recordPayout` on `PrizeDraw`. Its operator is `→ CQ-23`.

Anyone: `open` as a bear's owner, and all reads.

No role can open a box for a holder, change an outcome, or move a bear.

*Acceptance.* When a non-owner calls `excludeRange`, `scheduleCycle` or `setWorker`, or a non-worker calls `resolve` or `recordPayout`; then each reverts; and `open` needs no role but the bear's ownership.

**RAF-34 Pause.** Pausing the hub blocks `open`. Pausing `PrizeDraw` blocks `resolve`, so no new word is requested,
while words already requested are still applied when they arrive. Neither pause blocks
`recordPayout` or any read. A cycle's window runs on while the hub is paused: a pause shortens
the time holders have, and it does not move `end`.

*Acceptance.* Given the hub and the draw each paused; when `open` and `resolve` are called; then each reverts with `ContractPaused`; and `recordPayout` and every read still succeed.

**RAF-16 Events.** The events each contract emits:
- **Hub:** `IdsExcluded(from, to)`, `CycleScheduled(cycleId, start, end, prizeCount,
  manifestHash)`, `BoxOpened(openIndex, cycleId, tokenId, opener)`, `PausedSet`.
- **`PrizeDraw`:** `CycleScheduled(cycleId, prizeCount, manifestHash)`,
  `DrawRequested(openIndex, requestId)`, `OutcomeRecorded(openIndex, cycleId, opener, won,
  prizeIndex)`, `PrizePaid(cycleId, openIndex, chainId, txHash)`, `WorkerSet`, `PausedSet`.

*Acceptance.* When a cycle runs through exclusion, scheduling, an open, a resolution and a payout record; then every listed event fires with the documented arguments.

**RAF-17 Reads.** The reads each contract answers:
- **Hub:** `MAX_BEARS`, `PLAYABLE`, `isExcluded(tokenId)`, `currentCycle()` and each cycle's
  `(start, end, prizeCount, manifestHash)`, `isOpen()`, `opened(cycleId, tokenId)`,
  `openCount()`, `shotsLeft(wallet)`.
- **`PrizeDraw`:** `PLAYABLE`, each cycle's `(prizeCount, manifestHash, idsLeft, prizesLeft)`,
  `nextToResolve()`, `outcomeOf(openIndex)`, `payoutOf(openIndex)`, and `odds(cycleId)`
  returning `(prizesLeft, idsLeft)`.

*Acceptance.* When every listed read is called during an open cycle; then each returns without reverting and `odds(cycleId)` returns `(prizesLeft, idsLeft)`.

**RAF-18 Worker sequence.** The sequence, in order:
1. The owner records the excluded ids, once, before the first cycle.
2. For each cycle, the owner publishes the prize list, schedules the cycle on the hub and on
   `PrizeDraw` with the same count and hash, and MINT's prize wallet holds the prizes.
3. Holders open boxes inside the window.
4. The worker relays each `BoxOpened` to `PrizeDraw` in order.
5. Words arrive and outcomes are recorded.
6. Each win is paid from the prize wallet on its chain and recorded with `recordPayout`.
7. After `end`, the owner schedules the next cycle whenever MINT is ready.

MINT's UI shows the cycle's window, its prize list, the live odds, a wallet's shots left, its
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
- a cycle in which every playable bear is opened awards exactly its prize count, and the pool
  neither empties early nor is left over;
- a cycle that ends early awards no more than its prize count;
- a win is recorded as paid once, and a loss cannot be;
- a holder who sells a bear after opening it keeps its outcome.

*Acceptance.* When the tranche-2 test suite runs; then every listed case has a passing deterministic test.
<!-- openspec:end -->

<!-- openspec:begin retired -->
**Retired identifiers.** ACT-9 (the on-chain Status link) → ACT-12; ACT-11 (pause over burns and links) → ACT-15; DEL-4 (verified testnet addresses) → OPS-3 and OPS-4; DEL-5 (deployment scripts and runbook) → OPS-2 and OPS-5; RAF-1 (a single raffle chain) → RAF-32 and RAF-33; RAF-7 (passive ownership snapshot) → RAF-28; RAF-9 (draw over calldata entries) → RAF-30; RAF-10 (carry forward between rounds) → RAF-32; RAF-12 (round cancellation) → RAF-32; RAF-13 (per-round `minLevel` eligibility) → RAF-27; RAF-20 (rounds on the hub) → RAF-32; RAF-21 (entry into a round) → RAF-28; RAF-22 (one seed per round) → RAF-29; RAF-23 (the per-round draw) → RAF-30; RAF-2 (vault addresses) → RAF-33; RAF-3 (asset approval on the vaults) → RAF-27 and RAF-33; RAF-4 (deposit intake) → RAF-33; RAF-5 (vault inventory states) → RAF-30 and RAF-33; RAF-6 (committing prizes from the vaults) → RAF-27 and RAF-32; RAF-11 (claims from a vault) → RAF-33; RAF-15 (pause with vault claims) → RAF-34; RAF-24 (a prize vault per chain) → RAF-33; RAF-25 (recipient nomination) → RAF-33; RAF-26 (one game over the collection) → RAF-32; RAF-31 (closing the game) → RAF-32 and RAF-33; WL-3 (the voucher registry `WhitelistClaim`) → WL-8; WL-6 (the off-chain register as an alternative) → WL-8; WL-7 (the owner-imported registry `WhitelistImport`) → WL-8.
<!-- openspec:end -->

## 7. Operations, roles and handover (OPS)


<!-- openspec:begin family OPS -->
MINT needs to receive contracts that are correct from their first block, verified on every chain, and handed over with every key, role and a runbook — so that operating them after 19 November needs nothing from Calea.

**OPS-1 Addresses.** The control keys are recorded before mainnet deployment, and the royalty receiver before the
first sale (COL-6). `→ CQ-12`, `→ CQ-15`.

| Role | Holds | Address or holder |
|---|---|---|
| Admin | owner of every contract on every chain | `0x153052B43c8fD4ec01f14D1Edd8660778daa6141`, an EOA (MINT, 28 September 2026; for every contract, still to confirm) |
| Worker | `resolve` and `recordPayout` on `PrizeDraw` | EOA, funded on Arbitrum; operated by Calea (assumed, `→ CQ-23`) |
| Royalty receiver | ERC-2981 receiver — the pot | `0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63` (MINT, 28 September 2026) |
| Prize wallet | every prize, on every prize chain (RAF-33) | `0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3`, an EOA (MINT, 28 September 2026) |
| VRF subscription | the Chainlink subscription `PrizeDraw` draws on | MINT (assumed, `→ CQ-17`) |

*Acceptance.* When the mainnet deploy scripts run; then the admin and worker addresses they read are the ones MINT recorded; and the royalty receiver is set in Studio before the first sale.

**OPS-2 Deployment order.** Every address a contract needs at birth is a constructor argument, so a contract is correct
from its first block and is never deployed-but-unconfigured (MINT, CQ-12).
The calls made after construction are settings
and hand-overs, each in the order listed: `setMaxSupply`, `setTransferValidator`,
`setPaused(true)` and ownership transfers. Each contract is deployed before the page that
depends on it is published.

**Robinhood Chain:**
- `MintABear(name, symbol, [SeaDrop])` → `setMaxSupply(4444)` → `setTransferValidator(V3)`
  (COL-7) → two-step ownership transfer → provenance, `baseURI` and royalties set by Iñigo
  through Studio, before the drop page is published (COL-5, COL-6, COL-10).
- `Activation(bears, mntd, thresholds, weights)`, thresholds in whole $MNTD (ACT-2) →
  `setPaused(true)` until the switch-on date → ownership; requires $MNTD on 4663.
- `MysteryBox(owner, bears)`.

**Arbitrum One:** `PrizeDraw(owner, coordinator, subscriptionId, keyHash, worker, playable)` →
added as the subscription's consumer. No contract is deployed on a prize chain (RAF-33).

*Acceptance.* When the deploy script runs on a fresh chain; then each contract is created with its constructor arguments in the listed order and is never left deployed-but-unconfigured; and no address is set after construction; every call after construction is a listed setting or ownership transfer, in the listed order.

**OPS-3 Verification.** Sourcify for 4663 and 46630, because mainnet Blockscout's API sits behind a bot challenge.
Arbiscan (Etherscan's API) for Arbitrum One and Arbitrum Sepolia.

*Acceptance.* When a contract is deployed on 4663 or 46630; then its source is verified through Sourcify and readable there.

**OPS-4 Rehearsal on testnets (46630, Arbitrum Sepolia, Sepolia).** The rehearsal covers these paths:
- Studio attaches to and manages a self-deployed, validated `MintABear`.
- Both mint paths: OpenSea and the getminted.io mirror.
- The whitelist: a CSV from MINT's register loaded into Studio, `compare` passing against it, and
  a two-per-wallet allowlist mint.
- A burn through `Activation` against $MNTD on 46630, through to a recorded level.
- Two mystery-box cycles:
  - exclusion;
  - scheduling on 46630 and Arbitrum Sepolia;
  - boxes opened;
  - relays, words and outcomes, including one open that wins and one that does not;
  - a win paid from a prize wallet on 46630 or Sepolia and recorded with `recordPayout`;
  - a bear opened again in the second cycle.
- An OpenSea testnet listing of the validated collection.

On mainnet, before the drop page is published: one team bear listed and sold on OpenSea (COL-7).

*Acceptance.* When the rehearsal runs on 46630, Arbitrum Sepolia and Sepolia; then each listed path completes end to end, including one open that wins and one that does not.

**OPS-5 Handover.** Calea deploys, configures, transfers ownership, verifies source, and delivers the runbook. After
that it holds no owner key. The one role it may keep is the worker's, if Calea operates the
worker (`→ CQ-23`); `setWorker` lets MINT's admin take that role back at any time. Technical
support runs through 19 November 2026 with agreed response hours (DEL-10).

The runbook is one document, produced via `forge script` tooling. It covers:
- the deploy order (OPS-2);
- the enforcement toggle (OPS-6);
- `Activation`'s pause and unpause around the burn switch-on date (ACT-15);
- loading MINT's whitelist CSV into Studio and checking it (WL-4);
- the mystery-box cycle and worker sequence (RAF-18).

*Acceptance.* When handover completes; then every contract's owner is MINT's admin, every source is verified and the runbook is delivered; and Calea holds no owner key, and no role other than the worker's where CQ-23 gives it one.

**OPS-6 Enforcement runbook.** Enabled at deployment: `MintABear.setTransferValidator(0x721C002B…)`
with the validator's zero-state policy. Optional, from the admin: `createList`,
`addAccountsToWhitelist`, `addAccountsToAuthorizers`, `applyListToCollection`,
`setTransferSecurityLevelOfCollection` (never level 5 or above). Disable:
`setTransferValidator(address(0))`. Every step is an owner call and reversible.

*Acceptance.* Given enforcement enabled; when the admin calls `setTransferValidator(address(0))` and then sets V3 again; then each call emits `TransferValidatorUpdated` and the policy follows the current value.

**OPS-7 Chain constraints.** On Robinhood Chain `block.number` is the L1 height, so contracts and scripts key on timestamps.
Sequencer-level compliance screening can block an individual holder's transactions, so nothing
in the system requires a holder to act by a deadline for the system to stay correct: a box left
unopened in a cycle is a shot not taken, and nothing else depends on it. Robinhood Chain applies
an Arbitrum-style per-transaction gas limit, which is why no call in this system loops over the
collection. Randomness is not available on Robinhood Chain or ApeChain, which is why the draw
runs on Arbitrum One.
<!-- openspec:end -->

## 8. Calendar (CAL)

MINT fixes four dates:
- the whitelist list frozen by 27 October, 48 hours before the whitelist stage;
- TGE on 20 October;
- the mint on 29 October;
- burns and level-up starting on 29 October.

These carry basis *MINT*. The Basis column gives the source of every other row:
- *fixed*: the call itself;
- *SoW*: a date the statement of work sets;
- *derived*: a date that follows from an anchor;
- *proposed*: Calea's suggestion;
- *SoW; to confirm*: a SoW date nobody has yet held.

Every other row is MINT's to confirm or move (`→ CQ-1`). The mystery box's cycles are set by the
owner and are not calendar rows (RAF-32).

| Date (2026) | Outcome | Lead | Basis |
|---|---|---|---|
| 28 Sep | Call: the decisions in §10 | Iñigo; Calea | fixed |
| 29 Sep – 2 Oct | `MintABear` final, reviewed, deployed with the validator set; OpenSea page and URL live before promotion; team bear listed and sold; Studio attach proven on testnet | Calea; Iñigo | SoW |
| when MINT deploys it | $MNTD test deployment on 46630 for the burn rehearsal | MINT (Lorenzo) | MINT |
| 5 – 9 Oct | `MysteryBox`, `PrizeDraw`, the worker and the UI tested on 46630 and Arbitrum Sepolia, two cycles included; reports and runbooks; no open Critical/High | Calea; Javier; MINT | SoW |
| to MINT's dates | Whitelist campaign open on getminted.io/mintabear, claims recorded in MINT's backend | Iñigo; Javier; Vlad; Lorenzo | to confirm |
| by 27 Oct | Whitelist frozen; final CSV loaded into the Studio whitelist stage; Calea's root check passes; proofs published | Iñigo; Calea | derived |
| 12 – 14 Oct | `MysteryBox` and `PrizeDraw` deployed and verified; roles and official addresses verified; the VRF subscription funded; a cycle rehearsed on the testnets | Calea; Iñigo; MINT | SoW |
| 20 Oct | TGE: $MNTD live on Robinhood Chain; `Activation` deployed, verified against the real token, paused | MINT; Calea | MINT |
| 20 – 28 Oct | Real burns rehearsed by MINT and Calea on mainnet, in windows the owner opens and closes again; `Activation` is paused outside them | Calea; MINT | derived |
| 29 Oct | Mint: whitelist stage, then the other stages per Studio; `Activation` unpaused, so burns and level-up open | Iñigo; Javier; Calea | MINT |
| after 29 Oct | The first mystery-box cycle, scheduled by the owner with its prize list | Iñigo; Calea | MINT |
| 5 Nov | First royalty closing block and pot split; thereafter at each ETH cap or countdown (§2) | MINT | SoW; to confirm |
| 19 Nov | Operations handed over; technical support ends (OPS-5, DEL-10) | Iñigo/Robert; Calea | SoW; to confirm |

Two decouplings hold whatever moves:
- the collection deploys and mints without the mystery box or `Activation` being live;
- `Activation` opens to holders only once its burn has been exercised against real $MNTD, which
  the owner does by unpausing for a rehearsal and pausing again (ACT-15).

Three things to note:
- **The burn rehearsal is tight.** Burns open nine days after TGE, so the mainnet rehearsal
  against the real token has that window; the testnet $MNTD takes the pressure off it.
- **The worker outlives support.** Cycles run after the 19 November handover and the end of
  technical support, and the worker keeps relaying opens and recording payouts after both
  (`→ CQ-23`).
- **The whitelist freeze is two days before the mint.** The list is final by 27 October so the
  Studio upload and the root check fit before the whitelist stage (WL-5).

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

**DEL-6 Integration package.** Interfaces, events, roles and calldata examples for every contract. A **TypeScript** client
library for getminted.io, typed against the ABIs, that covers every call the app makes:
- **the play page:**
  - mint: SeaDrop stages, allowlist proofs built from MINT's whitelist CSV (WL-4), `mintPublic`;
  - burn: `costToReach`, approve, `burn`;
  - the mystery box: `open`, outcomes, odds, shots left and payout records;
- **MINT's admin page:**
  - `excludeRange`;
  - `scheduleCycle` on both chains;
  - pauses;
- **the worker:** `resolve` and `recordPayout`.

It comes with its own tests and the revert reasons a caller has to handle, so that MINT
integrates against a library that has been exercised rather than against an ABI (`→ CQ-19`).
Also a reference script that reproduces the royalty split from `Activation.snapshot`,
dead-address exclusion included, so that "allocations plus carried rounding equal funding" is
testable by MINT.

*Acceptance.* When MINT integrates the play page and the admin page; then every contract call they make is covered by the typed TypeScript library, with passing tests and documented revert reasons, and the reference script reproduces the royalty split.

**DEL-7 Existing-contract review.** A read of the contract MINT names, within the agreed line
limit; findings only, no remediation. Unscheduled: no contract has been named, so it books no
time until one is (`→ CQ-13`).

*Acceptance.* Given MINT has named a contract within the line limit; when the review is delivered; then it lists findings only, with no remediation.

**DEL-8 Audit tranches.** Tranche 1: `MintABear` and `Activation`. Tranche 2: `MysteryBox` and `PrizeDraw`, once CQ-20's
remaining values are supplied. The whitelist has no contract: it is MINT's off-chain register
(WL-8), and `WhitelistClaim` and `WhitelistImport` are not deployed. Iñigo accepts after Calea and
MINT sign off; anything not accepted stays disabled in the UI.

**DEL-9 Repository.** The contracts go into MINT's repository as `packages/contracts` (`@mint/contracts`), beside
`packages/contracts-client`. `packages/contracts` is a Foundry package with a thin
`package.json`, so `pnpm -r build|test|check` reach it, and its Foundry dependencies are git
submodules that CI checks out. CI runs `forge fmt --check`, `forge build --sizes` and
`forge test`, and Calea owns that configuration (MINT accepted, 28 September 2026). MINT names
the repository (`→ CQ-14`).

The contracts go in as their tranches are accepted. The client library's mint and allowlist-proof
calls, and the root check (WL-4), are needed before the whitelist stage.

*Acceptance.* When the contracts land in the monorepo; then `pnpm -r build|test|check` reach the Foundry package and CI runs the three forge gates.

**DEL-10 Commercial items for Rayco's agreement.** Listed here so nothing is implied:
- prize logic and the unique-winner rule;
- weight interfaces;
- Studio and frontend assistance;
- mainnet execution and role handover on every chain;
- technical support through 19 November with agreed response hours;
- the existing-contract review;
- beyond the SoW's single-chain vault and collection:
  - **whitelist support**: the root check against MINT's CSV, the mint proofs and a review of the
    claim rules (WL-4, WL-8);
  - the **cross-chain draw**: the Chainlink draw on Arbitrum, the relay of each open, and the
    payout record;
  - the admin-page calls in the client library.

Two items are priced only if MINT confirms them:
- **operating the worker** after 19 November, if Calea runs it (`→ CQ-23`);
- **holding the VRF subscription** and invoicing it, if MINT does not (`→ CQ-17`).

**DEL-11 Frontend collaboration.** MINT builds and owns the page holders play on — mint, raffle,
burn and level-up — in TypeScript, served from **getminted.io** (MINT, CQ-19). Calea owns the
Solidity and the TypeScript client library of DEL-6, and reviews every change that touches a
contract call before it merges. The Framer landing page stays where it is and is neither built
nor reviewed by Calea. Which repository holds these packages is `→ CQ-14`.

**DEL-12 Review sign-off.** Every Critical and High finding from DEL-3's review is fixed before mainnet deployment of the
contract it concerns, for every contract in an audit tranche (DEL-8).
<!-- openspec:end -->

## 10. Decisions

The calls of 21 and 28 September 2026 worked through the decisions this document carried into
them. What they settled is written into the requirements as final state. What is still open is
listed after it, each item with Calea's recommendation, which is also what Calea builds if the
decision is deferred.

### Settled at the call of 28 September 2026

| | Decision | Recorded in |
|---|---|---|
| **Cycles** | The mystery box runs in cycles the owner schedules. In a cycle each playable bear is one shot, decided by its own Chainlink word from a fixed pool without replacement. Prizes a cycle does not award stay with MINT and may roll forward. One shot per bear per cycle is the only cap on a wallet's wins (CQ-9) | RAF-32, RAF-28, RAF-30 |
| **Excluded ids** | 222 team bears, fixed for good before the first cycle (CQ-20) | RAF-27 |
| **Draw chain** | Arbitrum One; Base is dropped (CQ-17) | RAF-8 |
| **Prize custody** | MINT's prize wallet `0xf6c0…e3e3` on Robinhood Chain, Ethereum and possibly ApeChain; no contract on any prize chain; each payout recorded on `PrizeDraw`; no on-chain nomination (CQ-8) | RAF-33 |
| **Status links** | Off-chain, against Privy accounts; the on-chain link is removed (CQ-21) | ACT-12 |
| **Royalty receiver** | `0xf7E7…0e63` (CQ-15) | COL-6, OPS-1 |
| **$MNTD** | OpenZeppelin `ERC20Burnable`, 18 decimals, fixed supply, immutable, as the reference token (CQ-2) | ACT-7 |
| **Repository** | Calea's recommendation accepted (CQ-14) | DEL-9 |
| **Whitelist** | Off-chain, in MINT's backend; no contract, nothing to audit; the final CSV goes into Studio and Calea checks the root (CQ-18) | WL-8, WL-4 |

Settled on 21 September and not reopened:
- **D1:** $MNTD is native to Robinhood Chain.
- **D2:** the burn thresholds are cumulative.
- **D6:** MINT funds the VRF subscription (assumed; see O5).
- **D8:** the existing-contract review is unscheduled.
- **D9:** MINT builds the play page in TypeScript on getminted.io, against Calea's client library.

Settled earlier:
- **CQ-5:** the weights.
- **CQ-6:** no burn.
- **CQ-7:** royalties enforced.
- **CQ-16:** no freeze and no clawback.

Closed as superseded:
- **CQ-3:** `credit`.
- **CQ-10:** the vault claim window, now part of CQ-22.
- **CQ-11:** vault withdrawals; custody is MINT's wallet.

### Open after the call

**O1 — Dates (CQ-1).** The whitelist campaign window and the whitelist stage's start, which
fixes the freeze 48 hours earlier; the first royalty closing block; the 19 November handover.

**O2 — The excluded ids (CQ-20).** The 222 team ids as ranges, and whether ApeChain holds prizes.
The first cycle cannot be scheduled without the ids.

**O3 — How a prize is delivered (CQ-22).** Who sends a payout from the prize wallet: MINT by hand,
or automation holding the wallet's key. And whether MINT pushes each win or the winner requests it
within 30 days. **Recommended:** MINT pushes each win to the opener, and the worker records it.

**O4 — The VRF subscription's holder (CQ-17).** Assumed MINT. If Calea holds and funds it and
invoices MINT, it becomes a priced item and a role Calea keeps (DEL-10, OPS-5).

**O5 — Who operates the worker (CQ-23).** Assumed Calea, as a service priced in Rayco's agreement
and replaceable by MINT's admin at any time. The worker's address follows from this.

**O6 — The admin for every contract (CQ-12).** Assumed to be `0x1530…6141`, an externally owned
account, for every contract on every chain. Confirm it or name the exceptions. With one EOA, the
risk that the collection's owner can add a minter rests on that key alone (§2).

**O7 — The testnet $MNTD (CQ-2).** Its address on 46630 when MINT deploys it, and the mainnet
address at TGE, each carrying the reference token's bytecode. `Activation` fixes the address in
its constructor.

**O8 — The repository (CQ-14).** Its URL and Calea's access.

**O9 — Existing-contract review (CQ-13).** Which contract, its source and its size, when MINT
has one to name.

## 11. Sign-off

| Party | Name | Date | Signature |
|---|---|---|---|
| MINT | Iñigo Gaston | | |
| Calea | Bojan Jovin | | |
| Rayco | | | |

Version 2.5, 28 September 2026. The version signed carries the open items of §10 resolved;
amendments are issued as new versions of this document; requirement identifiers are never
reused.
