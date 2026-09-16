# MintABear — Open questions for MINT

Register of decisions that belong to MINT. Each entry names the specification section it
affects, the date by which Calea needs the answer, and the default Calea builds if none arrives.
`docs/tools/build_client_doc.py` inserts these entries into the client document under the
sections they belong to.

Status values: **Open** · **Answered** (with date and source) · **Closed** (resolved by a source
document; recorded so it is not re-asked).

## Register

| ID | Section | Question | Default | Needed by | Status |
|---|---|---|---|---|---|
| CQ-1 | CAL | Revised dates after the 29 Oct mint | SoW dates +14 d after mint; TGE 20 Oct | 18 Sep | Open |
| CQ-2 | ACT | $MNTD burn route and the shape of $MNTD's level-up function | (b) Base burn + attested credit | 25 Sep | Open |
| CQ-3 | ACT | Confirm the token-agnostic `credit` design | proceed | 25 Sep | Open |
| CQ-4 | ACT | Five burn thresholds | 5k / 15k / 40k / 100k / 250k | Activation deploy | Open |
| CQ-5 | ACT | Which weight table: the brief's five (1.00–3.50) or the SoW's six (1.00–2.00); immutable | SoW's six, 1.00–2.00 | Activation deploy | Open |
| CQ-6 | COL | May holders burn bears? | standard burn available | 18 Sep | Open |
| CQ-7 | COL | Enforce royalties via the transfer validator, and when | deploy unset | non-blocking | Open |
| CQ-8 | RAF | Raffle chain; where the prize assets live | Base | 25 Sep | Open |
| CQ-9 | RAF | Confirm passive-snapshot entry | passive | 25 Sep | Open |
| CQ-10 | RAF | Claim window | 30 days | vault deploy | Open |
| CQ-11 | RAF | May the owner sweep unreserved inventory? | yes, evented | vault deploy | Open |
| CQ-12 | OPS | Admin, worker, attester, treasury addresses; Safe on 4663 | Safe admin, EOA worker | collection deploy | Open |
| CQ-13 | DEL | Existing smart-contract review: which contract, source, line limit | not started | 18 Sep | Open |
| CQ-14 | DEL | Monorepo placement, `lib/` handling, CI ownership | `packages/contracts`, submodules | before migration | Open |
| CQ-15 | COL | Royalty rate and receiver | — | collection deploy | Open |
| CQ-16 | OPS | Compliance requirements (freeze / clawback) | none | 18 Sep | Open |
| CQ-17 | RAF | VRF subscription ownership and funding | MINT | vault deploy | Open |

## Questions

### CQ-1 — Revised dates after the 29 October mint
- **Section:** CAL
- **Needed by:** 18 September 2026
- **Status:** Open
- **Default if unanswered:** every SoW date after the mint shifts by the same 14 days; TGE stays 20 October.

**Question.** The SoW schedule chains off a 15 October mint. With the mint at 29 October, which
of these hold and which move: TGE (20 Oct); first holder-only raffle (16–19 Oct, which needs
minted bears); burns and Status linking enabled (27 Oct); first royalty round close (5 Nov);
operations handover (19 Nov)? Please give UTC dates.

**Why it matters.** The raffle vault's deployment and the burn-route go-live are scheduled
against these dates; the collection deployment is not affected.

### CQ-2 — $MNTD burn route
- **Section:** ACT
- **Needed by:** 25 September 2026
- **Status:** Open
- **Default if unanswered:** route (b), burn on Base with an attested credit on Robinhood Chain.

**Question.** $MNTD is native to Base; the bears and their levels live on Robinhood Chain. The
meeting mentioned that $MNTD will have a level-up / burn function. On which chain does it live,
what does it do, and does it call our contract? Will $MNTD have a representation on Robinhood
Chain (bridge or OFT), and does MINT control canonical mint and burn on Base?

**Options.**
- **(a) $MNTD on Robinhood Chain.** Direct `burnFrom` in one transaction; simplest for holders.
  If the token there is a bridged representation, burning it locks canonical supply in the
  bridge rather than destroying it — the SoW's own caveat.
- **(b) Burn on Base, credit on Robinhood Chain — default.** A `BurnForBear` contract on Base
  burns canonical $MNTD and emits an event; MINT's attester relays it as a credit. Canonical
  supply is provably reduced; the level lives beside the token; one trusted relay, auditable
  by anyone against Base events.
- **(c) Cross-chain messaging.** Trust-minimised but no messaging endpoint is verified on
  Robinhood Chain; additional scope and time, as the SoW anticipates.

### CQ-3 — Confirm the token-agnostic `credit` design
- **Section:** ACT
- **Needed by:** 25 September 2026
- **Status:** Open
- **Default if unanswered:** proceed as specified.

**Question.** `Activation` never touches $MNTD; it accepts `credit(tokenId, burner, amount,
nonce, ref)` from a single crediter address and requires that the burner still owns the bear
and that the bear has not moved since the counter value was read (ACT-4, ACT-7). Whichever
route is chosen only changes who the crediter is. Does MINT agree, or prefer a different shape?

### CQ-4 — Burn thresholds
- **Section:** ACT
- **Needed by:** before `Activation` is deployed
- **Status:** Open
- **Default if unanswered:** 5,000 / 15,000 / 40,000 / 100,000 / 250,000 $MNTD.

**Question.** The five cumulative thresholds, in whole $MNTD, for levels 1–5. They are
constructor values with no setter and cannot be changed after deployment.

### CQ-5 — Royalty weights
- **Section:** ACT
- **Needed by:** before `Activation` is deployed
- **Status:** Open
- **Default if unanswered:** the SoW table, 1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00.

**Question.** The two documents Calea received state different weight tables. MINT's original
brief lists five weight levels: 1.00 / 1.30 / 1.75 / 2.40 / 3.50 (100–350 share units). The
statement of work of 14 September lists six, one per level 0–5: 1.00 / 1.10 / 1.25 / 1.45 /
1.70 / 2.00, "proposed for launch". Please confirm which table applies, or supply the final
one. The weights are constructor values and immutable; MINT's accounting reads them from the
contract at every closing block.

**Why it matters.** The table's length is also the number of levels. The specification
(ACT-2, ACT-3) and the thresholds in CQ-4 are written for six levels, 0–5; a five-entry table
changes both.

### CQ-6 — May holders burn bears?
- **Section:** COL
- **Needed by:** 18 September 2026 (it is a code decision in the first audit tranche)
- **Status:** Open
- **Default if unanswered:** the standard SeaDrop burn stays available.

**Question.** Should a holder be able to destroy their own bear? With burn available, supply
can fall below 4,444, a burned bear disappears from raffles and royalty weight, and Studio's
burn-to-redeem features remain possible. With burn refused, none of that can happen, ever.
The choice is permanent.

### CQ-7 — Enforce royalties via the transfer validator
- **Section:** COL
- **Needed by:** non-blocking; the switch is an owner operation after deployment
- **Status:** Open
- **Default if unanswered:** deployed unset; decided after the mainnet rehearsal.

**Question.** Enforcement (COL-7) makes creator earnings mandatory on OpenSea and Payment
Processor marketplaces and reverts every other marketplace transfer. Given that the royalty pot
funds the holder rewards, does MINT want it enabled, and if so from launch or after the first
observed sale? Iñigo's Studio check on "ERC-721C with enforced royalties" answers the same
question from OpenSea's side.

### CQ-8 — Raffle chain and prize assets
- **Section:** RAF
- **Needed by:** 25 September 2026
- **Status:** Open
- **Default if unanswered:** Base.

**Question.** On which chain are the prize assets ($MNTD, other ERC-20s, NFTs) held today?
Should the vault live on Base — prizes native, VRF native, ownership imported as a verifiable
snapshot from Robinhood Chain — or on Robinhood Chain, with prizes bridged there and
randomness relayed from another chain? Both have exactly one relayed input; Base relays
ownership (auditable against chain state), Robinhood relays randomness.

### CQ-9 — Passive-snapshot entry
- **Section:** RAF
- **Needed by:** 25 September 2026
- **Status:** Open
- **Default if unanswered:** passive.

**Question.** Every bear at the published snapshot block is a ticket for its owner; holders do
nothing and pay nothing to enter, and a bear can never count twice. The SoW's "open the raffle
on 16 Oct" is then the announcement, not an entry window. Does MINT confirm, or want an
explicit opt-in?

### CQ-10 — Claim window
- **Section:** RAF
- **Needed by:** before the vault is deployed
- **Status:** Open
- **Default if unanswered:** 30 days.

**Question.** How long does a winner have to claim before the prize returns to inventory? The
SoW's seven days applies to royalty credits; raffle prizes are unspecified.

### CQ-11 — Owner sweep of unreserved inventory
- **Section:** RAF
- **Needed by:** before the vault is deployed
- **Status:** Open
- **Default if unanswered:** allowed, with an event; reserved and won prizes are never sweepable.

**Question.** The SoW forbids withdrawing *live-round reserves*. May the admin withdraw
*unreserved* inventory — for a mistaken deposit, or to move prizes elsewhere — or should
everything that enters the vault be committed to future rounds?

### CQ-12 — Addresses and the admin wallet
- **Section:** OPS
- **Needed by:** before the collection is deployed
- **Status:** Open
- **Default if unanswered:** a Safe for the admin; EOAs for worker and attester.

**Question.** The admin address (owner of all three contracts), the worker key, the attester
key (route b), and the royalty treasury. Calea recommends a Safe for the admin; Safe's
contracts are deployed on Robinhood Chain but whether its web interface supports chain 4663 is
unverified — has MINT used one there?

### CQ-13 — Existing smart-contract review: which contract, source, line limit
- **Section:** DEL
- **Needed by:** 18 September 2026
- **Status:** Open
- **Default if unanswered:** not started.

**Question.** Which existing smart contract should Calea review, where is its source, and what
is the agreed line limit? It is not in the `NFT` monorepo.

### CQ-14 — Monorepo placement and CI
- **Section:** DEL
- **Needed by:** before the migration
- **Status:** Open
- **Default if unanswered:** `packages/contracts` as `@mint/contracts`; Foundry dependencies as git submodules; Calea ports its CI workflow.

**Question.** The monorepo has no Solidity, no CI and no submodules today. Confirm the package
location; whether `lib/` dependencies are git submodules (CI must check them out) or vendored
copies; and who owns the CI configuration.

### CQ-15 — Royalty rate and receiver
- **Section:** COL
- **Needed by:** before the collection is deployed
- **Status:** Open
- **Default if unanswered:** none; the collection cannot be configured without it.

**Question.** The ERC-2981 royalty percentage and the treasury address that receives it.

### CQ-16 — Compliance requirements
- **Section:** OPS
- **Needed by:** 18 September 2026
- **Status:** Open
- **Default if unanswered:** no freeze, no clawback; no admin path into a holder's bear.

**Question.** Does any compliance requirement call for an admin ability to freeze a bear or
claw one back? None is specified; adding one later would reshape the permission model of every
contract.

### CQ-17 — VRF subscription
- **Section:** RAF
- **Needed by:** before the vault is deployed
- **Status:** Open
- **Default if unanswered:** MINT owns and funds it.

**Question.** The Chainlink VRF v2.5 subscription on the raffle chain: MINT creates and funds
it (LINK or native), and adds the vault as a consumer. Confirm, and name the account that will
hold it.

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
