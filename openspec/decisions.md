# Decisions

Persistent register. One namespace, one id for life; the lifecycle lives in `State`
(open → follow-up → resolved | deferred), never in the id. Fields are the bullets right
under each heading; everything after the first blank line is the decision's own record,
verbatim in the tracker and in the client document.

## ADDED Decisions

### CQ-1 — Dates after the 29 October mint
- **Statement:** Dates after the 29 Oct mint
- **State:** follow-up
- **Status note:** call, 21 September 2026
- **Section:** CAL
- **Needed by:** 2026-10-29 — before the mint
- **Resolution:** the three anchors stand — TGE 20 October, mint 29 October, burns and level-up from 29 October. Every other row of §8 is unconfirmed.
- **Summary:** To be decided; the anchors stand, every other §8 row unconfirmed

**Question.** The SoW schedule chains off a 15 October mint. With the mint at 29 October, which
dates hold and which move?

**Answer (MINT).** "Final dates are TGE 20th Oct and NFT mint 29th Oct. So any other
activations happen after 29th, such as opening the first mystery box raffle; burn and level-up
should kick off 29th as well."

**Recorded as.** §8 calendar: the three anchors are fixed; every other row is derived and marked
*proposed*.

**Answer (call, 21 September 2026).** To be decided. The dates below were not settled, so §8's
non-anchor rows stay marked with their basis and none of them is a commitment.

**Remaining.** Please confirm or move the proposed rows: whitelist campaign 6–26 October; round 1
entries 29 October to 1 November, draw 1 November, claims to 1 December; first royalty closing
block 5 November; operations handed over 19 November. Two consequences of the anchors to be
aware of: burns open nine days after TGE, so the burn is rehearsed against real $MNTD on
Robinhood Chain between 20 and 28 October, and a $MNTD deployment on testnet 46630 by 5 October
makes that rehearsal independent of TGE (CQ-2).

### CQ-2
- **Statement:** $MNTD burn route
- **State:** follow-up
- **Status note:** call, 21 September 2026
- **Section:** ACT
- **Needed by:** 2026-10-20 — before `Activation` is deployed
- **Resolution:** option (a1) — $MNTD is **native** to Robinhood Chain, burned by `Activation` in the same transaction as the record.
- **Summary:** Native on Robinhood Chain, with burning and staking beside it; token interface to confirm
- **Blocks:** ACT-7, OPS-2, OPS-4

**Question.** On which chain does the $MNTD burn happen, what does the token's level-up function
do, and does it call our contract?

**Answer (MINT).** "Burn will be on Robinhood in the end, so burn will live on RH. Simple, and I
believe that would be the answer."

**Recorded as.** ACT-7: the burn happens on 4663, in `Activation`; a burn on Base and
cross-chain messaging are not selected. The burn route is in audit tranche 1 (DEL-8).

**Remaining.** What the token on Robinhood Chain *is* decides what a burn means:

- **(a1) Native — recommended.** $MNTD's canonical supply is issued on Robinhood Chain.
  `burnFrom` reduces it. Nothing else to decide.
- **(a2) Bridged representation.** Canonical supply lives elsewhere (Base) and a bridge mints a
  mirror on Robinhood Chain. Burning the mirror leaves the canonical tokens locked in the bridge
  forever — removed from circulation, not from `totalSupply`. Acceptable only if MINT states
  publicly that locked-forever counts as burned.
- **(a3) Mint-and-burn bridge (OFT-style).** Each chain's supply is native to it and the bridge
  burns on one side to mint on the other. A burn on Robinhood Chain reduces the global supply,
  so it is equivalent to (a1) for our purpose.

**Answer (call, 21 September 2026).** "Token will be native, and the supporting infra (burning,
staking) will also be on Robinhood Chain." That is option (a1): the canonical supply is issued
on 4663 and `burnFrom` reduces it, so a burn is a burn with nothing to qualify publicly. Staking
is MINT's and touches nothing here — `Activation` reads only `MintABear` and burns only the
caller's own $MNTD.

**Recorded as (call).** ACT-7: the token is native on 4663; the bridged and mint-and-burn
readings are dropped. §10 D1 is closed.

**Remaining — interface, not a decision.** Does the token expose `burnFrom(address, uint256)`
(OpenZeppelin `ERC20Burnable`), reverting rather than returning false on failure? How many
`decimals`? Is its address final — a proxy, or a contract MINT will not redeploy? `Activation`
fixes the address in its constructor, so a different token later means a new `Activation`. Who
deploys it, and can a copy be on testnet 46630 for the burn rehearsal? Is it live on 4663 at TGE?
All of it is needed before `Activation` is deployed.

### CQ-9 — Raffle entry model
- **Statement:** Mystery box model
- **State:** follow-up
- **Status note:** call, 21 September 2026
- **Section:** RAF
- **Needed by:** 2026-10-05 — before tranche 2 starts
- **Resolution:** **instant reveal**. A holder opens a box with a bear they own and learns the outcome then; one bear is one shot and the id is spent by it. Rounds, entry windows and the scheduled draw are dropped.
- **Summary:** Instant reveal on opening; one bear is one shot and the id is spent
- **Blocks:** RAF-28

**Question.** Every bear at a published block is a ticket and holders do nothing — or an
explicit opt-in?

**Answer (MINT).** "Not passive; they need to enter the raffle by clicking 'open mystery box'
for the raffle entry. Once they click we do the relevant ownership/spend checks — he might have
already opened twice and holds 10 bears, so we would say 8/10 lucky tries left, for example."

**Recorded as.** RAF-28: a holder opens a box with a bear they own and learns the outcome then;
one bear is one shot; the outcome belongs to the wallet that opened it; an opened bear is
"spent" for good, stays freely transferable, and cannot be opened again by its buyer.
`shotsLeft` gives the 8/10.

**Answer (call, 21 September 2026).** "Rewards are immediate upon opening a mystery box by a
user that owns an NFT or multiple NFTs. One NFT — one shot at prize, consuming one ID per
attempt out of 4,444. There is a very high chance that team allocations will be removed from
this functionality and will not be eligible for prizes. The amount of prizes is to be decided
(for example 5 prizes for 4,444 NFTs − team allocation NFTs). Verifiable random function
mechanics will handle randomization behind the mystery box on a separate chain since Robinhood
lacks native verifiable random function support. So — Robinhood Chain for proof of NFT
ownership. Any network that supports Chainlink for determining if player wins a prize. User
claims his prizes from multiple chains."

**What changes.** This is the *instant* model, not the scheduled draw §10 D5 recommended, and it
replaces the round structure rather than adjusting it. Rounds, entry windows, `minLevel` gating,
the per-round draw and the winners root all go; what takes their place is one game over the
4,444 ids, each id spendable once, each spend resolved on its own.

**Calea's note on the tradeoff, for the record.** Robinhood Chain produces no randomness, so an
instant outcome is only unpredictable if a fresh Chainlink word backs it. One VRF request per
open is unpredictable but costs a fee per open and takes a callback's latency; a seed
pre-committed by MINT costs nothing but lets whoever holds it foresee every outcome, and a seed
published before the opens lets anyone compute which bears win. The shape that keeps both the
instant feel and the guarantee is the open question below.

**Settled by Calea in §6 (21 September 2026), for MINT to confirm.** MINT set the shape; four
things the shape left open are now specified, and they are stated here so MINT confirms rather
than inherits them:

- **Each open is decided by its own Chainlink word** (RAF-29, RAF-30), not by a shared or
  pre-committed seed. It is the only arrangement in which an instant outcome is unpredictable to
  everyone, MINT included; it costs one VRF request per open, which is what the subscription has
  to carry (RAF-8).
- **A win is drawn from a fixed pool without replacement** (RAF-30): each open wins with
  probability `prizesLeft / idsLeft`, so exactly the prize count is awarded once every playable
  id has been played, every holder faces the same odds before opening, and the pool can neither
  run dry early nor be left over.
- **No cap on how many prizes one wallet may win** (RAF-30). One bear is one shot, so a holder
  of twenty bears has twenty of them.
- **Prizes never won return to MINT when the game closes** (RAF-31).

**Remaining.** Confirm the four above, and supply the prize count and the excluded team ids
(CQ-20).

### CQ-11 — May the owner withdraw inventory?
- **Statement:** Owner withdrawals
- **State:** follow-up
- **Status note:** MINT reply, September 2026; reopened by the call, 21 September 2026
- **Section:** RAF
- **Resolution:** no withdrawal while a prize is committed to the live game.
- **Summary:** Not while a prize is committed to the live game
- **Blocks:** RAF-14
- **Needed by:** 2026-10-05 — before tranche 2 starts

**Question.** May the admin withdraw *unreserved* inventory, or is everything that enters the
vault committed to future rounds?

**Answer (MINT).** "We allow admin to withdraw as long as the mystery box is not active, so admin
can fill X prizes and activate the raffle mystery box when ready. But when live, none can be
withdrawn from inventory in the wallet."

**Recorded as.** RAF-14: `sweep` is refused for anything committed to the game; a won prize
stays locked until claimed or expired regardless.

**Effect of the call.** MINT's rule was written against rounds — "withdraw as long as the mystery
box is not active". Instant reveal has no rounds and the box is open continuously, so the rule
needs restating as: a prize withdrawable while the game is closed, and locked from the moment it
is committed to the pool until it is won and claimed, or the game is closed. Confirm that
reading with CQ-9.

### CQ-12 — Addresses and the admin wallet
- **Statement:** Addresses; Safe on 4663
- **State:** open
- **Status note:** call, 21 September 2026: still to be supplied
- **Section:** OPS
- **Needed by:** 2026-10-02 — before anything is deployed to mainnet
- **Resolution:** Open; supplied on time, as constructor parameters where possible
- **Default if deferred:** a Safe for the admin; EOAs for worker and signer.

**Question.** Four addresses, as OPS-1 records them: the **admin** (owner of every contract on
every chain), the **worker** key (raffle lifecycle, seed relay, winners root), the **eligibility
signer** (signs whitelist vouchers, WL-2) and the **royalty receiver** (the pot, CQ-15). The
first three are needed before mainnet deployment, the receiver before the first sale (COL-6).
Also name, per prize chain, the account that tops the worker's gas up; it holds no role.
Calea recommends a Safe for the admin; Safe's contracts are
deployed on Robinhood Chain but whether its web interface supports chain 4663 is unverified — has
MINT used one there? If not, one EOA per chain held by Iñigo is the fallback.

**Answer (MINT).** "Address and admin wallet will be shared shortly."

**Answer (call, 21 September 2026).** Kept open: the addresses will be supplied in time, and MINT
asked that they be **constructor parameters** where possible rather than post-deployment setter
calls.

**Recorded as (call).** OPS-2: every address a contract needs at birth is a constructor
argument, so a contract is correct from its first block and there is no window in which it is
deployed but unconfigured. The one address set by a call rather than a constructor argument is
`WhitelistClaim.setSigner`'s, owner-only, because a signer key must be rotatable.

### CQ-13 — Existing smart-contract review: which contract, source, line limit
- **Statement:** Existing-contract review target
- **State:** open
- **Status note:** call, 21 September 2026
- **Section:** DEL
- **Needed by:** whenever MINT names a contract
- **Resolution:** none; no contract is available to review yet.
- **Summary:** Not available; deferred until MINT names one

**Question.** Which existing smart contract should Calea review, where is its source, and what is
the agreed line limit?

**Answer (MINT).** "Needs to be discussed with Lorenzo so he can say; I guess it's the main
staking contract."

**Answer (call, 21 September 2026).** "Not available at the moment."

**Recorded as (call).** DEL-7 stands as a deliverable but is unscheduled: it is drawn on when
MINT names a contract, and books none of the auditor's time until then.

**Remaining.** The contract's name, its source (repository path or a verified address), and its
size in lines, so the line limit in Rayco's agreement can be set. Findings only, no remediation
(DEL-7).

### CQ-14 — Monorepo placement and CI
- **Statement:** Monorepo and CI
- **State:** open
- **Status note:** call, 21 September 2026: not reached
- **Section:** DEL
- **Needed by:** before the tranche 1 handover
- **Resolution:** Undecided; `packages/contracts`, submodules, Calea owns CI
- **Default if deferred:** `packages/contracts` as `@mint/contracts`; Foundry dependencies as git submodules; Calea ports its CI workflow.

**Question.** Confirm the package location; whether `lib/` dependencies are git submodules or
vendored copies; and who owns the CI configuration.

**Answer (MINT).** "Let's discuss this in the call Monday."

**Answer (call, 21 September 2026).** Not reached. CQ-19 settled who builds what, but not where
the code lives, so the repository question stands on its own now rather than riding on CQ-19.

**Remaining.** Which repository holds `packages/contracts` and the client library; whether the
Foundry dependencies are git submodules or vendored; who owns the CI configuration. Calea's
default is unchanged. Note that the monorepo named in earlier drafts,
`github.com/mintdotio/NFT`, needs confirming against the getminted.io split in CQ-19.

### CQ-15
- **Statement:** Royalty rate and receiver
- **State:** follow-up
- **Status note:** MINT reply, September 2026
- **Section:** COL
- **Needed by:** 2026-10-02 — the receiver before the first sale (the team bear); the rate is settled
- **Resolution:** 5% (500 basis points); receiver to follow.
- **Summary:** 5%; receiver to follow
- **Blocks:** COL-6

**Question.** The ERC-2981 royalty percentage and the address that receives it.

**Answer (MINT).** "Royalties — let's make them 5%; receiver I will send once we have the Studio
collection owner wallet set up."

**Recorded as.** COL-6.

**Remaining.** The receiver address. Calea recommends that it is *not* the Studio owner (admin)
wallet: the receiver is the royalty pot, a treasury that is swept on every cap or countdown, while
the admin is a control key that should hold nothing. Either works technically; it is set through
Studio at any time before the first sale.

### CQ-17 — VRF subscription
- **Statement:** VRF subscription and network
- **State:** follow-up
- **Status note:** call, 21 September 2026
- **Section:** RAF
- **Needed by:** 2026-10-12 — before `PrizeDraw` is deployed
- **Resolution:** option (a) — MINT creates, funds and owns the subscription from a wallet it controls; Calea adds `PrizeDraw` as a consumer during deployment. The network is still to pick.
- **Summary:** MINT creates, funds and owns it; the network is Calea's to recommend

**Question.** The Chainlink VRF v2.5 subscription on Base: MINT creates and funds it and adds the
`PrizeDraw` as a consumer. Confirm, and name the account that will hold it.

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
  Calea adds `PrizeDraw` as a consumer during deployment — recommended.** MINT already owns
  every admin role and will be topping the balance up after handover.
- **(b) Calea creates and funds it for the rehearsal and transfers it to MINT's wallet at
  handover.** Same result, one extra transfer.

**Answer (call, 21 September 2026).** Option (a): "MINT creates and funds the subscription on the
VRF network from a wallet it controls; Calea adds `SeedRequester` as a consumer during
deployment. VRF network to be decided. Calea recommendation welcome." (The contract MINT calls
`SeedRequester` there is `PrizeDraw` in §6: it now decides the outcome, not only fetches a word.)

**Calea's recommendation on the network: Base.** Chainlink VRF v2.5 is live there
(coordinator `0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634`), MINT already uses the chain, fees are
a few cents rather than the dollars a request costs on Ethereum, and blocks are two seconds, so a
request and its fulfilment complete inside a few seconds — which matters now that CQ-9 has made
the outcome something a holder waits for. Ethereum
(`0xD7f86b4b8Cae7D942340FF628F82735b7a20893a`) is the alternative and is correct but slow and
expensive at one request per open or per batch. ApeChain and Robinhood Chain have no Chainlink
VRF at all, checked 18 September 2026.

**Remaining.** Confirm Base, and name the wallet that will hold the subscription. How much the
subscription has to hold depends on how often a word is requested, which is CQ-9's remaining
question.

### CQ-20 — Prize count, odds and the token ids out of play
- **Statement:** Prize count, odds and excluded ids
- **State:** open
- **Status note:** new; from the call, 21 September 2026
- **Section:** RAF
- **Needed by:** 2026-10-05 — before tranche 2 starts; the numbers are deployment values
- **Resolution:** To supply: how many prizes, and which token ids are out of play
- **Default if deferred:** none; the game cannot be deployed without them.

**Question.** The instant mystery box (CQ-9) needs three numbers that only MINT can give.

- **How many prizes**, and what each one is: which asset, on which chain, and in what quantity.
  MINT's illustration was "5 prizes for 4,444 NFTs − team allocation NFTs"; five is an example,
  not a decision.
- **Which token ids are out of play.** MINT expects team allocations to be excluded from prize
  eligibility. Give the ids as ranges. They have to be fixed before the first open and frozen
  after it, because a set that can change mid-game changes everybody's odds; and an excluded bear
  is excluded whoever holds it, so a team bear that is sold stays out.
- **Whether every prize chain is known.** Each chain holding a prize needs its own vault deployed,
  verified and funded, so the list closes before tranche 2 deploys and cannot be added to
  afterwards without a new deployment.

**Why it cannot wait.** The prize count and the excluded set together fix the odds of an open,
and the odds are the product. They are also immutable once the game opens, in the same way the
burn thresholds are immutable once `Activation` is deployed.

### CQ-18 — How whitelist claims are recorded
- **Statement:** Whitelist claim recording
- **State:** follow-up
- **Status note:** call, 21 September 2026; the export direction and any owner bulk-add still to confirm (§10 O8)
- **Section:** WL
- **Needed by:** before the campaign opens
- **Resolution:** option **(A)** — an on-chain registry on Robinhood Chain; the holder sends the claim and pays the gas. The CSV loaded into OpenSea is exported from that registry.
- **Summary:** On-chain registry, holder pays gas (A); the OpenSea CSV is exported from it

**Question.** MINT provides the Privy mirror login and an API for the signed-in account's
wagering; Calea records the whitelist claims of those who meet the requirement. Where is the
record kept, and who sends the claim?

**Options.**
- **(A) On-chain registry, holder pays — recommended.** MINT's backend checks the wager API and
  signs a short-lived voucher; the holder submits it from the chosen NFT wallet. The contract
  holds the 1,000-spot counter, refuses a claim once sold out, allows two allocations per wallet
  and two per getminted.io account, and records every claim in order. The live counter is read
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

**Answer (call, 21 September 2026).** Option (A), with the export named explicitly:
"CodeCraft will provide a CSV file of wallet addresses for OpenSea, which can be populated
directly from the on-chain registry export to maintain security."

**Reading of the export direction.** Calea reads this as the registry being the source and the
CSV its output — the direction WL-4 already specifies. It is the only reading in which "to
maintain security" means anything: a CSV derived from a public registry is one anybody can
recompute and check against the chain, whereas a registry filled from a CSV would merely mirror
a private list and would prove nothing. Taken the other way it would also need an owner function
that writes claims in bulk — a key able to create whitelist spots out of nothing, which is
exactly the power §2's trust model says nobody has.

**Recorded as (call).** WL-3 and WL-4 stand: claims are made by holders against signed vouchers,
and the Studio allowlist is exported from `claimants(offset, limit)`. §10 D4 is closed.

**Remaining.** Confirm the export direction, and say whether MINT ever needs to place an address
on the whitelist without a wager voucher — for a partner or a correction. If it does, that is an
owner function with its own event, and it should be named now rather than added later, because
it changes what the registry guarantees.

**Also to confirm.** "1,000 spots" means 1,000 allocations, so a holder at $100 takes two of
them; the campaign's open and close dates (proposed 6 and 26 October; it must close at least
48 hours before the whitelist mint stage opens); the account that holds the eligibility signer
key; the other mint stages (team and treasury, public) and their order, so the whitelist stage's
place in Studio is known; and that Season 1 wagering and the $50 back-credit are MINT's data,
with Calea recording only the result.

### CQ-21 — How MINT's Status counts links across an account's wallets
- **Statement:** Status links per account
- **State:** open
- **Status note:** new; from the tranche-1 review, 24 September 2026
- **Section:** ACT
- **Needed by:** 2026-10-29 — before burns, level-up and Status linking open
- **Resolution:** Open; Calea recommends the account's single highest-level link
- **Default if deferred:** MINT's Status counts one link per getminted.io account: the highest-level bear among the links of the account's wallets.
- **Blocks:** ACT-9, DEL-6

**Question.** `Activation` lets each **wallet** nominate one bear to carry its Status boost
(ACT-9), and a getminted.io account may use several wallets — the whitelist already counts two
per account across them (WL-1, WL-3). So one account can hold several links at once, one per
wallet. How does MINT's Status treat them: one link per account (and if so, which — the highest
level, the most recent, a wallet the account marks as primary), or every wallet's link, each
boosting the account?

**In plain words.** A holder with two wallets could link a bear in each. The contract records
both and reads each bear's current level; what the Status boost is worth, and whether two links
count twice, is MINT's rule, off-chain.

**Calea's recommendation.** One boost per account: MINT reads `linkOf` for every wallet the
account's Privy login ties to it and applies the highest level among them. It keeps "one Status
boost" true per account whatever the number of wallets, needs nothing from the holder beyond the
links they already make, and needs no contract change. Any other answer needs no contract change
either — only MINT's Status service and the portal's wording follow it.

## RESOLVED Decisions

### CQ-3 — Confirm the token-agnostic `credit` design
- **Statement:** Token-agnostic `credit` design
- **State:** resolved
- **Status label:** Closed
- **Status note:** superseded by Calea, 24 September 2026 (tranche-1 review)
- **Section:** ACT
- **Resolution:** superseded: `Activation` takes $MNTD in its constructor and burns it itself (ACT-1, ACT-4, ACT-7).
- **Summary:** Superseded — `Activation` burns $MNTD itself; MINT's reply concerned the royalty pot (§2)
- **Blocks:** ACT-1

**Question.** `Activation` never touches $MNTD; it accepts `credit(tokenId, burner, amount,
nonce, ref)` from one crediter and requires that the burner still owns the bear and that the
bear has not moved since the counter was read. Does MINT agree?

**Answer (MINT).** "Not sure I understand this question properly. So basically the process would
be: once threshold/countdown is met, half of that ETH is used to buy $MNTD, and both the $MNTD and
ETH are sent to a splitter/multisender wallet, and that wallet executes the crediting to accounts
on mint.io."

**In plain words.** The question was about the *level* record, not the royalty pot.

**Superseded (Calea, 24 September 2026).** $MNTD is native to Robinhood Chain (CQ-2), so the
indirection that kept `Activation` token-agnostic no longer buys anything, and it let the owner
record levels without a burn by pointing the crediter at an address of their own. `Activation`
takes $MNTD in its constructor: recording the level and burning the tokens are two steps of one
transaction, the record first, and any revert undoes both. A different token address means a new
`Activation` (CQ-2, *Remaining*).

**Recorded as.** ACT-1 carries the plain-language version. MINT's description of the royalty pot
— ETH cap or countdown, half the ETH buys $MNTD, a splitter wallet credits the accounts — is
recorded in §2 under *Off-chain (MINT)*, where the accounts are getminted.io's (CQ-19).

### CQ-4 — Burn thresholds
- **Statement:** Five burn thresholds
- **State:** resolved
- **Status note:** call, 21 September 2026
- **Section:** ACT
- **Resolution:** 1,666 / 3,333 / 8,333 / 16,666 / 41,666 $MNTD, read **cumulatively**: level 5 costs 41,666 $MNTD in all.
- **Summary:** 1,666 / 3,333 / 8,333 / 16,666 / 41,666, read cumulatively
- **Blocks:** ACT-2

**Question.** The five thresholds, in whole $MNTD, for levels 1–5.

**Answer (MINT).** "Burn thresholds I think will be different than those: 1,666 / 3,333 / 8,333 /
16,666 / 41,666 as an initial final list of burn rate per tier."

**Recorded as.** ACT-2, with both readings side by side.

**Answer (call, 21 September 2026).** "The thresholds are cumulative." So the figures are the
total burned to reach each level and the per-level reading is dropped.

**Recorded as (call).** ACT-2 carries the cumulative column as the constructor's values; §10 D2
is closed. The two readings were:

| Level | MINT's figure | Cumulative (recommended): total to reach the level | Per level: total to reach the level |
|---|---|---|---|
| 1 | 1,666 | 1,666 | 1,666 |
| 2 | 3,333 | 3,333 | 4,999 |
| 3 | 8,333 | 8,333 | 13,332 |
| 4 | 16,666 | 16,666 | 29,998 |
| 5 | 41,666 | 41,666 | 71,664 |

Under the cumulative reading a bear reaches level 5 after 41,666 $MNTD in total; under the
per-level reading it would have been 71,664. The figures are in whole $MNTD and become base
units once `decimals` is known (CQ-2).

### CQ-5 — Royalty weights
- **Statement:** Weight table
- **State:** resolved
- **Status note:** MINT reply, September 2026
- **Section:** ACT
- **Resolution:** 1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00 for levels 0–5; six levels.
- **Summary:** 1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00, six levels
- **Blocks:** ACT-3, CQ-4

**Question.** MINT's brief lists five weights (1.00–3.50) and the SoW six (1.00–2.00). Which
applies?

**Answer (MINT).** "Yes, the same royalty weights apply: 1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00."

**Recorded as.** ACT-3, final; six levels 0–5 confirmed, which fixes five thresholds in CQ-4.

### CQ-6
- **Statement:** May holders burn bears?
- **State:** resolved
- **Status note:** MINT reply, September 2026
- **Section:** COL
- **Resolution:** no burn; supply is 4,444 forever.
- **Summary:** No; supply stays 4,444
- **Blocks:** COL-8

**Question.** Should a holder be able to destroy their own bear? The choice is permanent.

**Answer (MINT).** "There should be no specific function to burn the bear; they can always send
to a burn address anyway if they want, but supply would remain 4,444 if they lose access to that
bear."

**Recorded as.** COL-8: the transfer hook refuses burns (`BurnDisabled`), so the inherited burn
function always reverts. A bear sent to an address nobody controls stays in the supply; nobody
can enter it in a raffle, and the royalty snapshot excludes the canonical dead address so it
does not dilute the pot (ACT-10).

### CQ-7 — Enforce royalties via the transfer validator
- **Statement:** Enforce royalties on-chain
- **State:** resolved
- **Status note:** MINT reply, September 2026
- **Section:** COL
- **Resolution:** enforced from deployment.
- **Summary:** Yes, from deployment
- **Blocks:** COL-7, OPS-6

**Question.** Does MINT want creator earnings enforced on-chain, and from when?

**Answer (MINT).** "Enforce royalties always."

**Recorded as.** COL-7 and OPS-6: the validator is set at deployment. With it, holder-initiated
transfers always pass; sales settle only through OpenSea's SignedZone orders or a Payment
Processor marketplace, and creator earnings are collected on each. OpenSea's handling of a
validated collection on Robinhood Chain has not yet been observed, so it is proven on testnet
with Studio and then with one team bear listed and sold on mainnet before the drop page is
published; if OpenSea cannot fill orders, one owner call lifts enforcement until it can.

### CQ-8
- **Statement:** Where the prize assets live
- **State:** resolved
- **Status note:** call, 21 September 2026
- **Section:** RAF
- **Needed by:** before the vaults are deployed
- **Resolution:** prizes sit on several chains and are NFTs and tokens alike; each is claimed on the chain it sits on.
- **Summary:** Several chains; NFTs and tokens alike
- **Blocks:** RAF-24

**Question.** On which chain are the prize assets held, and where should the vault live?

**Answer (MINT).** "The prize assets will be held on different EVM chains — some on Robinhood,
others on Ethereum, some on ApeChain — and these will vary in token and NFT."

**Recorded as.** RAF-24: one `PrizeVault` on every chain that holds prizes, alongside
`MysteryBox` on Robinhood Chain, where ownership is checked and the id is spent, and `PrizeDraw`
on the Chainlink chain, which decides each open. A prize can only be handed over where it sits,
so the outcome travels to that chain as one award the worker posts and anyone can check.

**Answer (call, 21 September 2026).** Confirmed and widened: "Token prizes may span multiple
chains, and consist of various NFTs (not to be confused with MintABear NFT) and tokens." The
chains are not fixed to the three named above; each prize chain needs its own vault, so the
list has to be closed before tranche 2 is deployed.

**Recorded as (call).** §6: proof of ownership stays on Robinhood Chain, the win is determined
on a chain with Chainlink VRF, and the holder claims each prize on the chain it sits on. How
many prizes there are, and on which chains, is CQ-20.

### CQ-10
- **Statement:** Claim window
- **State:** resolved
- **Status note:** MINT reply, September 2026; carried over at the call, 21 September 2026
- **Section:** RAF
- **Resolution:** 30 days, now running from the win rather than from a round's root; an unclaimed prize is renounced.
- **Summary:** 30 days, from the win
- **Blocks:** RAF-11

**Question.** How long does a winner have to claim?

**Answer (MINT).** "The claim is held for 30 days, yes; if not claimed we assume it is renounced
and it gets rolled into a new mystery box round."

**Recorded as.** RAF-11: the 30-day window and `expirePrize` returning an unclaimed prize to
unreserved inventory; RAF-5 for the states it passes through.

**Effect of the call.** With instant reveal there are no rounds to roll into, so the window runs
from the moment the win is recorded and an expired prize returns to the inventory the game still
draws from. Where it goes once the game is over is part of CQ-9's remaining question on prizes
never won.

### CQ-16 — Compliance requirements
- **Statement:** Compliance (freeze / clawback)
- **State:** resolved
- **Status note:** MINT reply, September 2026
- **Section:** OPS
- **Resolution:** no freeze, no clawback; no admin path into a holder's bear.
- **Summary:** None
- **Blocks:** ACT-12, RAF-14, RAF-28

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

**Recorded as.** ACT-12 and RAF-14: no admin path into a holder's bear anywhere; RAF-28
defines *spent*.

### CQ-19 — Frontend and repository
- **Statement:** Frontend and integration
- **State:** resolved
- **Status note:** call, 21 September 2026
- **Section:** DEL
- **Needed by:** before the tranche 1 handover
- **Resolution:** MINT builds the app that holders use, in TypeScript, on **getminted.io**; Calea delivers a typed, tested TypeScript library for every contract interaction. The Framer landing page stays and is out of scope. Where the code lives is CQ-14.
- **Summary:** MINT builds the play page on getminted.io in TypeScript; Calea ships a tested typed client library

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

**Answer (call, 21 September 2026).** "Landing page will probably stay on Framer, but that is
out of our scope. The page where people will actually play (get NFTs, raffle, burn to up tier
levels, …) will be developed by client. IMPORTANT: everything related to this project
functionality will live on getminted.io, nothing will be related to mint.io. Frontend will be in
TypeScript. We will build interactions with smart contracts in TypeScript and test them in order
to simplify integration to the client. This will cover smart contract calls, error handling,
etc."

**Recorded as (call).** DEL-6 and DEL-11: the play page is MINT's, built in TypeScript against
Calea's library; that library is TypeScript, typed against the ABIs, covers every call the app
makes — mint with allowlist proofs, whitelist claim, burn, link, mystery box open and prize
claims on each chain — carries its own tests, and documents the revert reasons a caller has to
handle. The Framer landing page is neither built nor reviewed by Calea. §10 D9 is closed on the
frontend; the repository half stays with CQ-14.

**Consequence: the getminted.io / mint.io split.** The specification tied the account a wallet
belongs to, the wagering history, the two-per-account whitelist cap and the royalty crediting to
*mint.io accounts*. Since nothing in this project is to touch mint.io, all four are now
getminted.io accounts — recorded in §2, WL-1, WL-3 and ACT-10. Please confirm the reading, since
it also says where the wager API and the splitter wallet read and write.
