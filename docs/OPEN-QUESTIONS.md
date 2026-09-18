# MintABear — Open questions for MINT

Register of decisions that belong to MINT. Each entry names the specification section it
affects, the date by which Calea needs the answer, and the resolution — MINT's answer where one
exists, otherwise the default Calea builds if none arrives. `docs/tools/build_client_doc.py`
inserts these entries into the client document under the sections they belong to: settled
entries as green confirmations, open ones as yellow decisions.

Status values: **Open** · **Follow-up** (answered in part; the remaining question is stated) ·
**Answered** (with source) · **Closed** (no decision left; recorded so it is not re-asked).

MINT's answers below come from its written reply to specification v1.0, September 2026, in which
the questions were answered in the order they appear in that document (1–17). Two new questions,
CQ-18 and CQ-19, come from the *WL Wager Based Checker* brief and from MINT's proposal to build
the frontend as its own web app.

## Register

| ID | Section | Question | Resolution / default | Needed by | Status |
|---|---|---|---|---|---|
| CQ-1 | CAL | Dates after the 29 Oct mint | Anchors fixed; other rows proposed in §8 | 21 Sep | Follow-up |
| CQ-2 | ACT | $MNTD burn route | Burn on Robinhood Chain; token form and interface to confirm | 21 Sep | Follow-up |
| CQ-3 | ACT | Token-agnostic `credit` design | Stands; MINT's reply concerned the royalty pot (§2) | — | Closed |
| CQ-4 | ACT | Five burn thresholds | 1,666 / 3,333 / 8,333 / 16,666 / 41,666; cumulative reading to confirm | 21 Sep | Follow-up |
| CQ-5 | ACT | Weight table | 1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00, six levels | — | Answered |
| CQ-6 | COL | May holders burn bears? | No; supply stays 4,444 | — | Answered |
| CQ-7 | COL | Enforce royalties on-chain | Yes, from deployment | — | Answered |
| CQ-8 | RAF | Where the prize assets live | Robinhood, Ethereum, ApeChain; option in §10 D5 | 21 Sep | Follow-up |
| CQ-9 | RAF | Raffle entry model | Active, one box per bear per round; reveal model in §10 D5 | 21 Sep | Follow-up |
| CQ-10 | RAF | Claim window | 30 days; unclaimed prizes roll over | — | Answered |
| CQ-11 | RAF | Owner withdrawals | Only while no round is live | — | Answered |
| CQ-12 | OPS | Addresses; Safe on 4663 | MINT to send | collection deploy | Open |
| CQ-13 | DEL | Existing-contract review target | Probably the staking contract; source and size | 21 Sep | Follow-up |
| CQ-14 | DEL | Monorepo and CI | Decided with CQ-19 | 21 Sep | Open |
| CQ-15 | COL | Royalty rate and receiver | 5%; receiver to follow | first sale | Follow-up |
| CQ-16 | OPS | Compliance (freeze / clawback) | None | — | Answered |
| CQ-17 | RAF | VRF subscription | MINT creates, funds and owns it | vault deploy | Open |
| CQ-18 | WL | Whitelist claim recording | On-chain registry, holder pays gas (A) | 21 Sep | Open |
| CQ-19 | DEL | Frontend and repository | Own web app in the monorepo (A) | 21 Sep | Open |

## Questions

### CQ-1 — Dates after the 29 October mint
- **Section:** CAL
- **Needed by:** 21 September 2026 (the call)
- **Status:** Follow-up (MINT reply, September 2026)
- **Resolution so far:** TGE 20 October; mint 29 October; burns, level-up and the first mystery box round all start 29 October.

**Question.** The SoW schedule chains off a 15 October mint. With the mint at 29 October, which
dates hold and which move?

**Answer (MINT).** "Final dates are TGE 20th Oct and NFT mint 29th Oct. So any other
activations happen after 29th, such as opening the first mystery box raffle; burn and level-up
should kick off 29th as well."

**Recorded as.** §8 calendar: the three anchors are fixed; every other row is derived and marked
*proposed*.

**Remaining.** Please confirm or move the proposed rows: whitelist campaign 6–26 October; round 1
entries 29 October to 1 November, draw 1 November, claims to 1 December; first royalty closing
block 5 November; operations handed over 19 November. Two consequences of the anchors to be
aware of: burns open nine days after TGE, so the adapter is rehearsed against real $MNTD on
Robinhood Chain between 20 and 28 October, and a $MNTD deployment on testnet 46630 by 5 October
makes that rehearsal independent of TGE (CQ-2).

### CQ-2 — $MNTD burn route
- **Section:** ACT
- **Needed by:** 21 September 2026 — blocks the adapter and the `Activation` constructor
- **Status:** Follow-up (MINT reply, September 2026)
- **Resolution so far:** route (a) — $MNTD on Robinhood Chain, burned by `DirectBurnAdapter` in the same transaction as the credit.

**Question.** On which chain does the $MNTD burn happen, what does the token's level-up function
do, and does it call our contract?

**Answer (MINT).** "Burn will be on Robinhood in the end, so burn will live on RH. Simple, and I
believe that would be the answer."

**Recorded as.** ACT-7: the crediter is `DirectBurnAdapter` on 4663; a burn on Base and
cross-chain messaging are not selected. The adapter moves into audit tranche 1 (DEL-8).

**Remaining.** What the token on Robinhood Chain *is* decides what a burn means:

- **(a1) Native.** $MNTD's canonical supply is issued on Robinhood Chain. `burnFrom` reduces it.
  Nothing else to decide.
- **(a2) Bridged representation.** Canonical supply lives elsewhere (Base) and a bridge mints a
  mirror on Robinhood Chain. Burning the mirror leaves the canonical tokens locked in the bridge
  forever — removed from circulation, not from `totalSupply`. Acceptable only if MINT states
  publicly that locked-forever counts as burned.
- **(a3) Mint-and-burn bridge (OFT-style).** Each chain's supply is native to it and the bridge
  burns on one side to mint on the other. A burn on Robinhood Chain reduces the global supply.

Also needed: does the token expose `burnFrom(address, uint256)` (OpenZeppelin `ERC20Burnable`)?
How many decimals? Who deploys it, and can a copy be on testnet 46630 by 5 October? Is it live
on 4663 at TGE on 20 October?

### CQ-3 — Confirm the token-agnostic `credit` design
- **Section:** ACT
- **Needed by:** —
- **Status:** Closed (MINT reply, September 2026; superseded by CQ-2)
- **Resolution:** the design stands; no decision remains.

**Question.** `Activation` never touches $MNTD; it accepts `credit(tokenId, burner, amount,
nonce, ref)` from one crediter and requires that the burner still owns the bear and that the
bear has not moved since the counter was read. Does MINT agree?

**Answer (MINT).** "Not sure I understand this question properly. So basically the process would
be: once threshold/countdown is met, half of that ETH is used to buy $MNTD, and both the $MNTD and
ETH are sent to a splitter/multisender wallet, and that wallet executes the crediting to accounts
on mint.io."

**In plain words.** The question was about the *level* record, not the royalty pot. Burning the
tokens and recording the level are two steps of one transaction: the adapter burns the holder's
$MNTD, then tells `Activation` "this wallet burned this amount for this bear". `Activation`
accepts that message from the adapter alone, so if $MNTD ever changes address or chain only the
adapter changes. With MINT's answer to CQ-2 this is settled without a further decision.

**Recorded as.** ACT-1 carries the plain-language version. MINT's description of the royalty pot
— ETH cap or countdown, half the ETH buys $MNTD, a splitter wallet credits mint.io accounts — is
recorded in §2 under *Off-chain (MINT)*.

### CQ-4 — Burn thresholds
- **Section:** ACT
- **Needed by:** 21 September 2026 — constructor values, immutable
- **Status:** Follow-up (MINT reply, September 2026)
- **Resolution so far:** 1,666 / 3,333 / 8,333 / 16,666 / 41,666 $MNTD; the cumulative reading is the default.

**Question.** The five thresholds, in whole $MNTD, for levels 1–5.

**Answer (MINT).** "Burn thresholds I think will be different than those: 1,666 / 3,333 / 8,333 /
16,666 / 41,666 as an initial final list of burn rate per tier."

**Recorded as.** ACT-2, with both readings side by side.

**Remaining.** "Burn rate per tier" admits two readings. The contract stores the *total* burned
to reach each level; MINT ticks one column:

| Level | MINT's figure | Cumulative (recommended): total to reach the level | Per level: total to reach the level |
|---|---|---|---|
| 1 | 1,666 | 1,666 | 1,666 |
| 2 | 3,333 | 3,333 | 4,999 |
| 3 | 8,333 | 8,333 | 13,332 |
| 4 | 16,666 | 16,666 | 29,998 |
| 5 | 41,666 | 41,666 | 71,664 |

Under the cumulative reading a bear reaches level 5 after 41,666 $MNTD in total; under the
per-level reading after 71,664.

### CQ-5 — Royalty weights
- **Section:** ACT
- **Needed by:** —
- **Status:** Answered (MINT reply, September 2026)
- **Resolution:** 1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00 for levels 0–5; six levels.

**Question.** MINT's brief lists five weights (1.00–3.50) and the SoW six (1.00–2.00). Which
applies?

**Answer (MINT).** "Yes, the same royalty weights apply: 1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00."

**Recorded as.** ACT-3, final; six levels 0–5 confirmed, which fixes five thresholds in CQ-4.

### CQ-6 — May holders burn bears?
- **Section:** COL
- **Needed by:** —
- **Status:** Answered (MINT reply, September 2026)
- **Resolution:** no burn; supply is 4,444 forever.

**Question.** Should a holder be able to destroy their own bear? The choice is permanent.

**Answer (MINT).** "There should be no specific function to burn the bear; they can always send
to a burn address anyway if they want, but supply would remain 4,444 if they lose access to that
bear."

**Recorded as.** COL-8: the transfer hook refuses burns (`BurnDisabled`), so the inherited burn
function always reverts. A bear sent to an address nobody controls stays in the supply; nobody
can enter it in a raffle, and the royalty snapshot excludes the canonical dead address so it
does not dilute the pot (ACT-10).

### CQ-7 — Enforce royalties via the transfer validator
- **Section:** COL
- **Needed by:** —
- **Status:** Answered (MINT reply, September 2026)
- **Resolution:** enforced from deployment.

**Question.** Does MINT want creator earnings enforced on-chain, and from when?

**Answer (MINT).** "Enforce royalties always."

**Recorded as.** COL-7 and OPS-6: the validator is set at deployment. With it, holder-initiated
transfers always pass; sales settle only through OpenSea's SignedZone orders or a Payment
Processor marketplace, and creator earnings are collected on each. OpenSea's handling of a
validated collection on Robinhood Chain has not yet been observed, so it is proven on testnet
with Studio and then with one team bear listed and sold on mainnet before the drop page is
published; if OpenSea cannot fill orders, one owner call lifts enforcement until it can.

### CQ-8 — Where the prize assets live
- **Section:** RAF
- **Needed by:** 21 September 2026
- **Status:** Follow-up (MINT reply, September 2026)
- **Resolution so far:** prizes on Robinhood Chain, Ethereum and ApeChain, tokens and NFTs alike. Recommended architecture in §6; alternatives in §10 D5.

**Question.** On which chain are the prize assets held, and where should the vault live?

**Answer (MINT).** "The prize assets will be held on different EVM chains — some on Robinhood,
others on Ethereum, some on ApeChain — and these will vary in token and NFT."

**Recorded as.** §6: a `MysteryBox` hub on Robinhood Chain (entries and the draw, next to the
bears), a `PrizeVault` on each chain that holds prizes, and a `SeedRequester` on Base for
Chainlink VRF. A prize can only be handed over on the chain where it sits, so either the draw's
result travels to each prize chain (options 1 and 2) or each chain runs its own draw (option 3).

**Remaining.** MINT chooses among the three options in §10 D5. Calea recommends option 1.

### CQ-9 — Raffle entry model
- **Section:** RAF
- **Needed by:** 21 September 2026
- **Status:** Follow-up (MINT reply, September 2026)
- **Resolution so far:** active entry, one mystery box per bear per round; scheduled draw with the reveal at draw time is the default.

**Question.** Every bear at a published block is a ticket and holders do nothing — or an
explicit opt-in?

**Answer (MINT).** "Not passive; they need to enter the raffle by clicking 'open mystery box'
for the raffle entry. Once they click we do the relevant ownership/spend checks — he might have
already opened twice and holds 10 bears, so we would say 8/10 lucky tries left, for example."

**Recorded as.** RAF-21: a holder enters bears during the round's entry window; each bear enters
once per round; the entry belongs to the wallet that made it; a bear that has entered is "spent"
for that round, stays transferable, and cannot be entered again by its new owner. `triesLeft`
gives the 8/10.

**Remaining.**
- Confirm the reading: opening a box costs nothing beyond gas; one open per bear per round.
- **Reveal model.** *Scheduled* (recommended): entries during the window, one seed, one draw;
  the UI opens every entered box at reveal time and shows what each won. *Instant*: each click
  resolves on the spot — this needs a random number at click time, which Robinhood Chain cannot
  produce; relaying Chainlink randomness per click takes minutes and costs a fee per click, and a
  seed pre-committed by MINT lets MINT foresee every outcome. §10 D5.
- Whether later rounds gate on level (`minLevel`, supported) — Status gating stays out of scope.

### CQ-10 — Claim window
- **Section:** RAF
- **Needed by:** —
- **Status:** Answered (MINT reply, September 2026)
- **Resolution:** 30 days; an unclaimed prize is renounced and rolls into the next round.

**Question.** How long does a winner have to claim?

**Answer (MINT).** "The claim is held for 30 days, yes; if not claimed we assume it is renounced
and it gets rolled into a new mystery box round."

**Recorded as.** RAF-11 (window), RAF-10 (roll-over).

### CQ-11 — May the owner withdraw inventory?
- **Section:** RAF
- **Needed by:** —
- **Status:** Answered (MINT reply, September 2026)
- **Resolution:** withdrawal only while no round is live on that vault.

**Question.** May the admin withdraw *unreserved* inventory, or is everything that enters the
vault committed to future rounds?

**Answer (MINT).** "We allow admin to withdraw as long as the mystery box is not active, so admin
can fill X prizes and activate the raffle mystery box when ready. But when live, none can be
withdrawn from inventory in the wallet."

**Recorded as.** RAF-14: `sweep` is refused from the moment a vault locks prizes for a round
until that round's result is posted or the round is cancelled; won prizes stay locked until
claimed or expired regardless. Between rounds the admin may withdraw anything unreserved.

### CQ-12 — Addresses and the admin wallet
- **Section:** OPS
- **Needed by:** before the collection is deployed (22 September – 2 October)
- **Status:** Open (MINT reply, September 2026: to be shared shortly)
- **Default if unanswered:** a Safe for the admin; EOAs for worker and signer.

**Question.** Five addresses: the **admin** (owner of every contract on every chain), the
**worker** key (raffle lifecycle, seed relay, winners root), the **eligibility signer** (signs
whitelist vouchers, WL-2), the **royalty receiver** (the pot, CQ-15), and, per prize chain, the
account that funds the worker. Calea recommends a Safe for the admin; Safe's contracts are
deployed on Robinhood Chain but whether its web interface supports chain 4663 is unverified — has
MINT used one there? If not, one EOA per chain held by Iñigo is the fallback.

**Answer (MINT).** "Address and admin wallet will be shared shortly."

### CQ-13 — Existing smart-contract review: which contract, source, line limit
- **Section:** DEL
- **Needed by:** 21 September 2026
- **Status:** Follow-up (MINT reply, September 2026)
- **Resolution so far:** probably the main staking contract; Lorenzo to confirm.

**Question.** Which existing smart contract should Calea review, where is its source, and what is
the agreed line limit?

**Answer (MINT).** "Needs to be discussed with Lorenzo so he can say; I guess it's the main
staking contract."

**Remaining.** The contract's name, its source (repository path or a verified address), and its
size in lines, so the line limit in Rayco's agreement can be set. Findings only, no remediation
(DEL-7).

### CQ-14 — Monorepo placement and CI
- **Section:** DEL
- **Needed by:** 21 September 2026
- **Status:** Open (MINT reply, September 2026: to discuss on the call)
- **Default if unanswered:** `packages/contracts` as `@mint/contracts`; Foundry dependencies as git submodules; Calea ports its CI workflow.

**Question.** Confirm the package location; whether `lib/` dependencies are git submodules or
vendored copies; and who owns the CI configuration.

**Answer (MINT).** "Let's discuss this in the call Monday."

**Remaining.** Decided together with CQ-19, which places the web app in the same repository.

### CQ-15 — Royalty rate and receiver
- **Section:** COL
- **Needed by:** receiver before the first sale; the rate is settled
- **Status:** Follow-up (MINT reply, September 2026)
- **Resolution so far:** 5% (500 basis points); receiver to follow.

**Question.** The ERC-2981 royalty percentage and the address that receives it.

**Answer (MINT).** "Royalties — let's make them 5%; receiver I will send once we have the Studio
collection owner wallet set up."

**Recorded as.** COL-6.

**Remaining.** The receiver address. Calea recommends that it is *not* the Studio owner (admin)
wallet: the receiver is the royalty pot, a treasury that is swept on every cap or countdown, while
the admin is a control key that should hold nothing. Either works technically; it is set through
Studio at any time before the first sale.

### CQ-16 — Compliance requirements
- **Section:** OPS
- **Needed by:** —
- **Status:** Answered (MINT reply, September 2026)
- **Resolution:** no freeze, no clawback; no admin path into a holder's bear.

**Question.** Does any compliance requirement call for an admin ability to freeze a bear or claw
one back?

**Answer (MINT).** "Not sure I understand this correctly either. There should be no 'freeze a
bear' ability as it's permissionless — unless that bear has already tried its luck in a current
round, therefore it's been 'spent'."

**In plain words.** The question was whether a regulator, a sanctions list or MINT's own policy
would ever require MINT to stop a specific bear from moving or to take it back; some issuers add
an admin blacklist for that. MINT's answer is no, which is what Calea recommends: every contract
stays without an admin path into a holder's bear. A "spent" bear is a raffle notion, not a
freeze: it has entered the current round, cannot enter it again, and moves freely (RAF-21).

**Recorded as.** ACT-12, RAF-14, OPS-1: no freeze or clawback anywhere; RAF-21 defines *spent*.

### CQ-17 — VRF subscription
- **Section:** RAF
- **Needed by:** before the `SeedRequester` is deployed
- **Status:** Open (MINT reply, September 2026: asked for an explanation)
- **Default if unanswered:** MINT creates, funds and owns the subscription; Calea adds the consumer during deployment.

**Question.** The Chainlink VRF v2.5 subscription on Base: MINT creates and funds it and adds the
`SeedRequester` as a consumer. Confirm, and name the account that will hold it.

**Answer (MINT).** "Would like to understand this better."

**In plain words.** Chainlink VRF is a paid service that returns a random number nobody can
predict or alter, with a proof checked on-chain. Whoever uses it holds a **subscription** — an
account on Chainlink's coordinator contract — which is topped up with LINK or with ETH and lists
the contracts allowed to draw from it. Each mystery box round makes one request, paid from the
subscription; on Base a request costs in the order of a few dollars, so the balance needs a top-up
now and then. The subscription is managed through Chainlink's web interface by the wallet that
created it.

**Options.**
- **(a) MINT creates and funds it, from the admin wallet or another wallet MINT controls, and
  Calea adds `SeedRequester` as a consumer during deployment — recommended.** MINT already owns
  every admin role and will be topping the balance up after handover.
- **(b) Calea creates and funds it for the rehearsal and transfers it to MINT's wallet at
  handover.** Same result, one extra transfer.

### CQ-18 — How whitelist claims are recorded
- **Section:** WL
- **Needed by:** 21 September 2026 — the registry must be live before the campaign opens
- **Status:** Open (new; from the *WL Wager Based Checker* brief)
- **Default if undecided:** option A — an on-chain registry on Robinhood Chain, the holder sends the claim and pays gas.

**Question.** MINT provides the Privy mirror login and an API for the signed-in account's
wagering; Calea records the whitelist claims of those who meet the requirement. Where is the
record kept, and who sends the claim?

**Options.**
- **(A) On-chain registry, holder pays — recommended.** MINT's backend checks the wager API and
  signs a short-lived voucher; the holder submits it from the chosen NFT wallet. The contract
  holds the 1,000-spot counter, refuses a claim once sold out, allows two allocations per wallet
  and two per mint.io account, and records every claim in order. The live counter is read from
  the chain; "sold out while mid-claim" is a failed transaction, nothing half-done; the whole
  campaign is auditable by anyone afterwards. Holders need a little ETH on Robinhood Chain, which
  they need for the mint anyway.
- **(A′) On-chain registry, MINT pays.** The same contract; MINT's worker submits each voucher
  and pays the gas, so holders need nothing on Robinhood Chain before the mint. Adds a small
  relay service on MINT's side.
- **(B) Off-chain register.** MINT's database with an atomic counter; Calea supplies the claim
  API contract and the export to the Studio allowlist and deploys nothing. Fastest to build and
  free of gas; claim order and sell-out rest on MINT's server, nothing is publicly checkable, and
  the SeaDrop allowlist root is the only trace on-chain.

**Also to confirm.** "1,000 spots" means 1,000 allocations, so a holder at $100 takes two of
them; the campaign's open and close dates (proposed 6 and 26 October; it must close at least
48 hours before the whitelist mint stage opens); the account that holds the eligibility signer
key; the other mint stages (team and treasury, public) and their order, so the whitelist stage's
place in Studio is known; and that Season 1 wagering and the $50 back-credit are MINT's data,
with Calea recording only the result.

### CQ-19 — Frontend and repository
- **Section:** DEL
- **Needed by:** 21 September 2026
- **Status:** Open (new; MINT's proposal)
- **Default if undecided:** option A — a standalone web app in MINT's monorepo, UI by MINT, contract calls by Calea, merged through review.

**Question.** MINT: "Since the website is on Framer, it might be best if we create it as our own
web app, separate from Framer. Considering all the things we want to add, Framer might not allow
them. It would also allow me to make the UI with Claude instead of Framer, commit it to the
GitHub repo, and you plug in the functions in the background for burning and whitelist checking,
then merge correctly through review."

**Options.**
- **(A) Standalone web app in `github.com/mintdotio/NFT` — recommended.** `apps/mintabear` holds
  the UI, which MINT builds and owns; `packages/contracts` holds the Solidity and its tests;
  `packages/contracts-client` is Calea's typed library for every contract call (mint with
  allowlist proofs, whitelist claim, burn, link, mystery box entry and claims). Calea reviews every
  pull request that touches a contract call before it merges. Framer keeps the marketing pages
  and links to the app. Everything MINT wants to add — Privy login, live counters, wallet flows,
  multi-chain claims — is ordinary web-app code, testable and reviewable in one place.
- **(B) Stay on Framer.** Calea ships a JavaScript bundle that Framer code components load.
  Wallet connection, Privy, transactions and live state inside Framer components are possible but
  awkward to test, hard to review, and every change goes through Framer's editor rather than a
  pull request.

**Also to settle (from CQ-14).** Foundry dependencies as git submodules (CI checks them out) or
vendored copies; who owns the CI configuration; the review rule for contract-touching changes.

## Closed

| Item | Resolution | Source |
|---|---|---|
| Who gates the mint | Iñigo configures stages and allowlists in Studio | SoW |
| Status uplift semantics | A 2% multiplier on platform reward rates; off-chain | Meeting 15 Sep |
| Vector-source artwork | Moot: the on-chain renderer is excluded | SoW |
| Artwork progression by level | Artwork is immutable; no on-chain progression | Meeting 15 Sep |
| Fuzzing deliverable | Written by Calea's internal auditor, not the developer | Calea, 15 Sep |
| ERC-6551 | Out of the initial release; separate scope later | Meeting 15 Sep, SoW |
| Daily pool vs stake-based Status | MINT-side product question; nothing on-chain depends on it | Handover |
| CQ-3 token-agnostic `credit` | Design stands; settled by the CQ-2 answer | MINT reply, Sep 2026 |
| Royalty pot mechanics | ETH cap or countdown; half the ETH buys $MNTD; a splitter wallet credits mint.io accounts; MINT-side | MINT reply, Sep 2026 |
