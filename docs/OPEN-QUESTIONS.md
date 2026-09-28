<!-- GENERATED sections between openspec markers are written by docs/tools/spec_tools/render_calea_prose.py from openspec/. Edit openspec/ and the narrative here, then run docs/tools/board.sh. -->
# MintABear — Open questions for MINT

Register of decisions that belong to MINT. Each entry names the specification section it
affects, the date by which Calea needs the answer, and the resolution — MINT's answer where one
exists, otherwise the default Calea builds if none arrives. `docs/tools/build_client_doc.py`
inserts these entries into the client document under the sections they belong to: settled
entries as green confirmations, open ones as yellow decisions.

Status values: **Open** · **Follow-up** (answered in part; the remaining question is stated) ·
**Answered** (with source) · **Closed** (no decision left; recorded so it is not re-asked).

Answers come from these sources:
- **MINT's written reply to specification v1.0** (September 2026) answered the questions in the
  order they appear in that document (1–17).
- **CQ-18 and CQ-19** were added afterwards, from the *WL Wager Based Checker* brief and MINT's
  frontend proposal.
- **The call of 21 September 2026** worked through D1–D9 in §10 of the specification, and CQ-20
  is new from it.
- **The call of 28 September 2026** worked through O1–O9 of specification v2.3, with a follow-up
  the same day. CQ-22 and CQ-23 are new from it.

Answers from each call are marked as such below.

## Register


<!-- openspec:begin register -->
| ID | Section | Question | Resolution / default | Needed by | Status |
|---|---|---|---|---|---|
| CQ-1 | CAL | Dates after the 29 Oct mint | Anchors stand; whitelist frozen by 27 October; other §8 rows unconfirmed | 2026-10-29 | Follow-up |
| CQ-2 | ACT | $MNTD burn route | Native; OpenZeppelin `ERC20Burnable`, 18 decimals, immutable; addresses to follow | 2026-10-20 | Follow-up |
| CQ-12 | OPS | Addresses; Safe on 4663 | Admin `0x1530…6141` (EOA) for every contract, to confirm; worker to follow | 2026-10-02 | Follow-up |
| CQ-13 | DEL | Existing-contract review target | Not available; deferred until MINT names one | whenever MINT names a contract | Open |
| CQ-14 | DEL | Monorepo and CI | Recommendation accepted; repository to be named | before the tranche 1 handover | Follow-up |
| CQ-17 | RAF | VRF subscription and network | Arbitrum One; MINT owns the subscription (assumed) | 2026-10-12 | Follow-up |
| CQ-20 | RAF | Prize count, odds and excluded ids | the owner sets each cycle's prize count and prize list from MINT's admin page; **222** team ids are excluded, fixed for good; prizes are held on Robinhood Chain, Ethereum and possibly ApeChain in MINT's prize wallet. | 2026-10-05 | Follow-up |
| CQ-22 | RAF | Prize delivery from the prize wallet | Open; Calea recommends that MINT pushes each win to the opener | 2026-10-12 | Open |
| CQ-23 | OPS | Worker operator after handover | Open; assumed that Calea operates the worker | 2026-10-12 | Open |
| CQ-3 | ACT | Token-agnostic `credit` design | Superseded — `Activation` burns $MNTD itself; MINT's reply concerned the royalty pot (§2) | — | Closed |
| CQ-4 | ACT | Five burn thresholds | 1,666 / 3,333 / 8,333 / 16,666 / 41,666, read cumulatively | — | Answered |
| CQ-5 | ACT | Weight table | 1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00, six levels | — | Answered |
| CQ-6 | COL | May holders burn bears? | No; supply stays 4,444 | — | Answered |
| CQ-7 | COL | Enforce royalties on-chain | Yes, from deployment | — | Answered |
| CQ-8 | RAF | Where the prize assets live | MINT's prize wallet on Robinhood Chain, Ethereum and possibly ApeChain; no vaults | before the vaults are deployed | Answered |
| CQ-9 | RAF | Mystery box model | Owner-scheduled cycles; one shot per bear per cycle; own VRF word; fixed pool, unawarded prizes roll forward | — | Answered |
| CQ-10 | RAF | Claim window | Superseded by CQ-22 (prize delivery) | — | Closed |
| CQ-11 | RAF | Owner withdrawals | Superseded — custody is MINT's wallet | — | Closed |
| CQ-15 | COL | Royalty rate and receiver | 5% to `0xf7E7…0e63` | — | Answered |
| CQ-16 | OPS | Compliance (freeze / clawback) | None | — | Answered |
| CQ-19 | DEL | Frontend and integration | MINT builds the play page on getminted.io in TypeScript; Calea ships a tested typed client library | before the tranche 1 handover | Answered |
| CQ-21 | ACT | Status links per account | Out of scope — Status links are off-chain; ACT-9 removed | — | Closed |
| CQ-18 | WL | Whitelist claim recording | Off-chain register in MINT's backend (B); Studio's root checked against the CSV | — | Answered |
<!-- openspec:end -->

## Questions


<!-- openspec:begin questions -->
### CQ-1 — Dates after the 29 October mint
- **Section:** CAL
- **Needed by:** 2026-10-29 — before the mint
- **Status:** Follow-up (call, 28 September 2026)
- **Resolution:** the three anchors stand — TGE 20 October, mint 29 October, burns and level-up from 29 October. The whitelist is frozen by 27 October, 48 hours before the whitelist stage. Every other row of §8 is unconfirmed.

**Question.** The SoW schedule chains off a 15 October mint. With the mint at 29 October, which
dates hold and which move?

**Answer (MINT).** "Final dates are TGE 20th Oct and NFT mint 29th Oct. So any other
activations happen after 29th, such as opening the first mystery box raffle; burn and level-up
should kick off 29th as well."

**Recorded as.** §8 calendar: the three anchors are fixed; every other row is derived and marked
*proposed*.

**Answer (call, 21 September 2026).** To be decided. The dates below were not settled, so §8's
non-anchor rows stay marked with their basis and none of them is a commitment.

**Answer (call, 28 September 2026).** "We can leave the 3 anchors stand. The only change is that
they need the WhitelistClaim contract ASAP. Tomorrow if possible." The registry is delivered to
MINT's repository and is expected to be deployed the same day, outside the audit (DEL-8, DEL-9).

**Remaining.** The whitelist campaign's window in MINT's backend. The whitelist stage's start,
which fixes the freeze 48 hours earlier. The first mystery-box cycle's window, which the owner
sets (RAF-32). The first royalty closing block. The 19 November handover. Burns open nine days
after TGE, so the burn is rehearsed against real $MNTD on Robinhood Chain between 20 and
28 October, and the testnet $MNTD makes that rehearsal independent of TGE (CQ-2).

### CQ-2 — $MNTD burn route
- **Section:** ACT
- **Needed by:** 2026-10-20 — before `Activation` is deployed
- **Status:** Follow-up (call, 28 September 2026; the testnet and mainnet addresses to follow)
- **Resolution:** option (a1) — $MNTD is **native** to Robinhood Chain, burned by `Activation` in the same transaction as the record. The token is OpenZeppelin `ERC20Burnable` with 18 decimals, fixed supply and no owner or proxy, so its address is final once deployed.

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

**Answer (call, 28 September 2026).** "It does expose burnFrom, 18 decimals, address will be
final, copy will be on test net 46630 but it is not there yet. They will notify us when it is
ready. The token will look exactly like this one:
https://sepolia.basescan.org/address/0xa21273093af1b3b880b73afd54514bb3d6269968#code"

**Read from the reference token** (Base Sepolia `0xa21273093af1b3b880b73afd54514bb3d6269968`,
verified source, read 28 September 2026). `MNTD is ERC20, ERC20Burnable, ERC20Permit` on
OpenZeppelin 5.5: the whole supply of 1,000,000,000 is minted once to a distributor in the
constructor, and there is no owner, no mint function and no proxy. `decimals` is 18.
`burnFrom(account, value)` spends the caller's allowance, then burns, and reverts on failure with
`ERC20InsufficientAllowance(spender, allowance, needed)` or
`ERC20InsufficientBalance(sender, balance, needed)`; an unlimited approval is never used down. The
client library already names both errors. It also supports EIP-2612 `permit`; `Activation` does
not use it, and a one-transaction burn with a permit would be a change to ACT-12's interface,
not proposed. Compiled for `cancun`, which Robinhood Chain runs apart from `blobbasefee`.

**Remaining.** The address of the copy on testnet 46630 when MINT deploys it, and the mainnet
address at TGE, each confirmed to carry this bytecode.

### CQ-12 — Addresses and the admin wallet
- **Section:** OPS
- **Needed by:** 2026-10-02 — before anything is deployed to mainnet
- **Status:** Follow-up (call, 28 September 2026; admin supplied, signer and worker to follow)
- **Resolution:** admin `0x153052B43c8fD4ec01f14D1Edd8660778daa6141`, an EOA, assumed to own every contract on every chain; the worker to follow. No eligibility signer is needed (CQ-18).

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

**Answer (call, 28 September 2026).** "0x153052B43c8fD4ec01f14D1Edd8660778daa6141 this is the
collection owner wallet. 0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63 this is the royalty
receiver wallet. That is all we have for now." In the follow-up: assume `0x1530…6141` is the
owner of every contract on every chain, to be confirmed.

**Read on-chain (28 September 2026).** `0x1530…6141` is an externally owned account with
transactions on 4663 and Ethereum; no Safe is involved. The accepted risk that the collection's
owner can add a minter (§2, HANDOVER) was mitigated by a Safe admin; with one EOA it rests on the
key alone, and the runbook's reset of the minter list at handover is the remaining check.

**Remaining.** Confirm `0x1530…6141` for every contract on every chain, or name the exceptions.
The worker's address follows CQ-23. The whitelist is off-chain (CQ-18), so there is no signer.

### CQ-13 — Existing smart-contract review: which contract, source, line limit
- **Section:** DEL
- **Needed by:** whenever MINT names a contract
- **Status:** Open (call, 21 September 2026)
- **Resolution:** none; no contract is available to review yet.

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
- **Section:** DEL
- **Needed by:** before the tranche 1 handover
- **Status:** Follow-up (call, 28 September 2026; repository to be named)
- **Resolution:** Calea's recommendation accepted: `packages/contracts` as `@mint/contracts` beside `packages/contracts-client`, Foundry dependencies as git submodules, Calea owns CI.

**Question.** Confirm the package location; whether `lib/` dependencies are git submodules or
vendored copies; and who owns the CI configuration.

**Answer (MINT).** "Let's discuss this in the call Monday."

**Answer (call, 21 September 2026).** Not reached. CQ-19 settled who builds what, but not where
the code lives, so the repository question stands on its own now rather than riding on CQ-19.

**Answer (call, 28 September 2026).** "They do accept our recommendation, however we will need to
update plan in order to facilitate the early delivery of WhitelistClaim contract." In the
follow-up: MINT will provide the repository; the first delivery is only the whitelist registry
and its client module.

**Recorded as (28 September).** DEL-9.

**Remaining.** The repository's URL and Calea's access to it. With the whitelist off-chain
(CQ-18) nothing is due on 29 September. The client library's mint and allowlist-proof calls are
needed before the whitelist stage.

### CQ-17 — VRF subscription
- **Section:** RAF
- **Needed by:** 2026-10-12 — before `PrizeDraw` is deployed
- **Status:** Follow-up (call, 28 September 2026; the network is settled, the subscription's holder is assumed)
- **Resolution:** **Arbitrum One**; the subscription is assumed to be owned and funded by MINT, with `PrizeDraw` as consumer.

**Question.** The Chainlink VRF v2.5 subscription on Base: MINT creates and funds it and adds the
`PrizeDraw` as a consumer. Confirm, and name the account that will hold it.

**Answer (MINT).** "Would like to understand this better."

**In plain words.** Chainlink VRF is a paid service that returns a random number nobody can
predict or alter, with a proof checked on-chain. Whoever uses it holds a **subscription** — an
account on Chainlink's coordinator contract — which is topped up with LINK or with ETH and lists
the contracts allowed to draw from it. Each mystery box open makes one request, paid from the
subscription; on Arbitrum One a request costs the network fee plus Chainlink's premium, so the
balance needs a top-up now and then. The subscription is managed through Chainlink's web interface by the wallet that
created it.

**Options.**
- **(a) MINT creates and funds it, from the admin wallet or another wallet MINT controls, and
  Calea adds `PrizeDraw` as a consumer during deployment — recommended.** MINT already owns
  every admin role and will be topping the balance up after handover.
- **(b) Calea creates and funds it for the rehearsal and transfers it to MINT's wallet at
- **Blocks:** RAF-8
- **Default if deferred:** MINT creates, funds and owns the subscription on Arbitrum One; Calea adds `PrizeDraw` as a consumer at deployment.
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

**Answer (call, 28 September 2026).** "MINT will no longer use Base, and agreement was reached to
use Arbitrum." Calea had proposed Arbitrum for speed; Base is out of the picture. On the
subscription: "There is a chance that we pay the VRF service and charge MINT through invoice."
In the follow-up: assume MINT owns the subscription, and leave it open.

**Recorded as (28 September).** RAF-8: `PrizeDraw` on Arbitrum One, VRF v2.5 coordinator
`0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e` (Arbitrum Sepolia
`0x5CE8D5A2BC84beb22a398CCA51996F7930313D61`), both read on-chain on 28 September 2026 as VRF v2.5
coordinators. How the chains combine: an open on Robinhood Chain emits `BoxOpened`; the worker
relays it in order to `PrizeDraw` on Arbitrum, where a Chainlink word decides it; a win is paid
from MINT's prize wallet on the prize's chain and recorded on `PrizeDraw` (RAF-29, RAF-33). No
bridge is involved; the worker is the one trusted relay, and it can delay an open but cannot
change or reorder one.

**Remaining.** Who holds the subscription. If Calea holds and funds it and invoices MINT, Calea
keeps a role after handover (OPS-5) and it becomes a priced item (DEL-10). A request's cost on
Arbitrum is small — the network fee plus Chainlink's premium per word — and the subscription is
funded for a cycle's worth of opens, at most 4,222.

### CQ-20 — Prize count, odds and the token ids out of play
- **Section:** RAF
- **Needed by:** 2026-10-05 — before tranche 2 starts; the numbers are deployment values
- **Status:** Follow-up (call, 28 September 2026; the excluded ids to follow)
- **Resolution:** the owner sets each cycle's prize count and prize list from MINT's admin page; **222** team ids are excluded, fixed for good; prizes are held on Robinhood Chain, Ethereum and possibly ApeChain in MINT's prize wallet.

**Question.** The instant mystery box (CQ-9) needs three numbers that only MINT can give.

- **How many prizes**, and what each one is: which asset, on which chain, and in what quantity.
  MINT's illustration was "5 prizes for 4,444 NFTs − team allocation NFTs"; five is an example,
  not a decision.
- **Which token ids are out of play.** MINT expects team allocations to be excluded from prize
  eligibility. Give the ids as ranges. They have to be fixed before the first open and frozen
  after it, because a set that can change mid-game changes everybody's odds; and an excluded bear
  is excluded whoever holds it, so a team bear that is sold stays out.
- **Whether every prize chain is known.** Each chain holding a prize needs its own vault deployed,
- **Summary:** Prizes per cycle by the owner; 222 ids excluded for good (which, to follow); prize chains Robinhood, Ethereum, maybe ApeChain
  verified and funded, so the list closes before tranche 2 deploys and cannot be added to
  afterwards without a new deployment.

**Why it cannot wait.** The prize count and the excluded set together fix the odds of an open,
and the odds are the product. They are also immutable once the game opens, in the same way the
burn thresholds are immutable once `Activation` is deployed.

**Answer (call, 28 September 2026).** "Prize count and prize distribution (how many prizes there
are, and what they constitute of) will be decided by an admin (owner) via a special admin page
in the app. This owner account will have the ability to freeze and open Raffle game." In the
follow-up: team ids are excluded, 222 of them, fixed for good; the ids themselves are MINT's to
supply; ApeChain is not yet confirmed, and no contract goes on any prize chain.

**Recorded as (28 September).** RAF-27: the excluded ranges are recorded once and frozen when the
first cycle is scheduled, so `PLAYABLE` is 4,222. RAF-32: each cycle's prize count and the hash of
its published prize list are set by the owner. DEL-6: the admin page's calls are in the client
library.

**Remaining.** The 222 excluded ids, as ranges. Whether ApeChain holds prizes. It needs no
deployment either way, but the UI names the chains.

### CQ-22 — How a prize is delivered
- **Section:** RAF
- **Needed by:** 2026-10-12 — before `PrizeDraw` is deployed
- **Status:** Open (new; from the call, 28 September 2026)
- **Resolution:** Open; Calea recommends that MINT pushes each win to the opener

**Question.** Prizes sit in MINT's prize wallet `0xf6c0…e3e3` (CQ-8), an externally owned
account, and are paid by transfer. Two things follow that only MINT can decide.

- **Who sends the payout.** Either MINT, by hand from the wallet, or automation. Automation puts
  the prize wallet's key on the worker's server, which Calea would be operating if CQ-23 goes
  that way.
- **Push or request.**
  - (a) MINT pushes every win to the opener's address. This is recommended: no holder action, no
    window, and nothing depends on a holder acting by a deadline (OPS-7).
  - (b) The winner requests the prize in the app within 30 days, or it is renounced (CQ-10).

**Recorded as.** RAF-33: whichever way it is paid, each payout is recorded on `PrizeDraw` with
`recordPayout(openIndex, chainId, txHash)`, so a win without a `PrizePaid` is visible to anyone.

### CQ-23 — Who operates the worker
- **Section:** OPS
- **Needed by:** 2026-10-12 — before `PrizeDraw` is deployed
- **Status:** Open (new; from the call, 28 September 2026)
- **Resolution:** Open; assumed that Calea operates the worker

**Question.** The worker relays every open from Robinhood Chain to `PrizeDraw` on Arbitrum, in
order, and records every payout (RAF-18, RAF-33). The mystery box runs cycle after cycle past the
19 November handover. Who runs it then: MINT's automation, as the SoW assumed, or Calea as a
service?

**Recorded as (28 September).** Assumed Calea, and left open. The worker holds only `resolve`
and `recordPayout` on `PrizeDraw`. It cannot change an outcome, reorder opens or move a bear or a
prize, and the admin can replace it (OPS-5, RAF-14). If Calea operates it, it is the one role
Calea keeps after handover, and operating it beyond 19 November is a priced item (DEL-10).

### CQ-3 — Confirm the token-agnostic `credit` design
- **Section:** ACT
- **Needed by:** —
- **Status:** Closed (superseded by Calea, 24 September 2026 (tranche-1 review))
- **Resolution:** superseded: `Activation` takes $MNTD in its constructor and burns it itself (ACT-1, ACT-4, ACT-7).

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
- **Section:** ACT
- **Needed by:** —
- **Status:** Answered (call, 21 September 2026)
- **Resolution:** 1,666 / 3,333 / 8,333 / 16,666 / 41,666 $MNTD, read **cumulatively**: level 5 costs 41,666 $MNTD in all.

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
transfers always pass; sales a marketplace operates settle only through OpenSea's SignedZone
orders or a Payment Processor marketplace, and creator earnings are collected on each; a sale
arranged outside a marketplace pays none (COL-7). OpenSea's handling of a
validated collection on Robinhood Chain has not yet been observed, so it is proven on testnet
with Studio and then with one team bear listed and sold on mainnet before the drop page is
published; if OpenSea cannot fill orders, one owner call lifts enforcement until it can.

### CQ-8 — Where the prize assets live
- **Section:** RAF
- **Needed by:** before the vaults are deployed
- **Status:** Answered (call, 28 September 2026)
- **Resolution:** prizes are NFTs and tokens held in MINT's prize wallet `0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3` on Robinhood Chain, Ethereum and possibly ApeChain, and paid from it to the winner on the prize's chain; no contract is deployed on a prize chain.

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

**Answer (call, 28 September 2026).** "Chains that will hold the prizes will certainly be
Robinhood, Ethereum and maybe Apechain (yet to be confirmed). The raffle prize wallet will be
0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3. This address will hold rewards on all 2 or 3
chains." And in the follow-up: the wallet is the custody itself, and "there will not be a vault
nor registry on Apechain" — nor on any prize chain.

**Recorded as (28 September).** RAF-33: the prize wallet holds every prize and pays it by
transfer; the vault contracts and their rules (RAF-2 to RAF-6, RAF-11, RAF-24) are retired. The
wallet is an externally owned account, active on 4663 and Ethereum (read 28 September 2026).

### CQ-9 — Raffle entry model
- **Section:** RAF
- **Needed by:** —
- **Status:** Answered (call, 28 September 2026)
- **Resolution:** **cycles**. The owner schedules each cycle's window and prizes; in a cycle each playable bear is one shot, decided instantly by its own Chainlink word, from a fixed pool without replacement; prizes not awarded stay with MINT and may roll into a later cycle; the only cap on a wallet's wins is one shot per bear per cycle.

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

**Answer (call, 28 September 2026).** "Yes on Chainlink. [...] The only cap on how many prizes a
wallet can win depends on the number of NFTs held by that wallet (1 NFT - one chance per cycle).
Confirmation on everything else." On O1: "Once opened the game will last for a pre-determined
period of time, but the owner dictates when the next game starts after the current is closed,
thus effectively having the ability to freeze the game until rewards for the following cycle
are in place." In the follow-up: every playable bear gets one shot per cycle and may be opened
again in the next, whoever holds it; the owner sets each cycle's start and end before it starts;
and for a cycle that ends with bears unopened, option (a): the odds stay fixed and the prizes not
awarded roll forward.

**Recorded as (28 September).** RAF-32 (cycles), RAF-28 (one shot per bear per cycle), RAF-29
and RAF-30 (per-cycle counters, one `openIndex` sequence), RAF-8 (Arbitrum). RAF-26 and RAF-31
are retired. The four points §6 settled are confirmed: an open's own Chainlink word, the fixed
pool without replacement, no cap beyond one shot per bear, and prizes not awarded returning to
MINT.

### CQ-10 — Claim window
- **Section:** RAF
- **Needed by:** —
- **Status:** Closed (superseded at the call, 28 September 2026)
- **Resolution:** superseded: there is no vault to claim from; a win is paid from MINT's prize wallet, pushed or requested as CQ-22 decides, and a 30-day window applies only if it is requested.

**Question.** How long does a winner have to claim?

**Answer (MINT).** "The claim is held for 30 days, yes; if not claimed we assume it is renounced
and it gets rolled into a new mystery box round."

**Recorded as.** RAF-11: the 30-day window and `expirePrize` returning an unclaimed prize to
unreserved inventory; RAF-5 for the states it passes through.

**Effect of the call.** With instant reveal there are no rounds to roll into, so the window runs
from the moment the win is recorded and an expired prize returns to the inventory the game still
draws from. Where it goes once the game is over is part of CQ-9's remaining question on prizes
never won.

**Superseded (call, 28 September 2026).** Prizes are held in MINT's prize wallet and paid by
transfer (CQ-8, RAF-33), so there is no `claim` or `expirePrize` on-chain. Whether the winner
has to request a prize within 30 days is part of CQ-22.

### CQ-11 — May the owner withdraw inventory?
- **Section:** RAF
- **Needed by:** —
- **Status:** Closed (superseded at the call, 28 September 2026)
- **Resolution:** superseded: prizes are held in MINT's own wallet, so nothing on-chain locks or releases them; MINT's rule that nothing is withdrawn while a cycle is live is MINT's to keep.

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

**Superseded (call, 28 September 2026).** With the prizes in MINT's externally owned prize
wallet (CQ-8, RAF-33) there is no vault to refuse a withdrawal. The published prize list of a
cycle (RAF-27) is MINT's commitment, and every win and every payout is on the record, but only
MINT's own practice keeps a committed prize in the wallet until it is won.

### CQ-15 — Royalty rate and receiver
- **Section:** COL
- **Needed by:** —
- **Status:** Answered (call, 28 September 2026)
- **Resolution:** 5% (500 basis points) to `0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63`.

**Question.** The ERC-2981 royalty percentage and the address that receives it.

**Answer (MINT).** "Royalties — let's make them 5%; receiver I will send once we have the Studio
collection owner wallet set up."

**Recorded as.** COL-6.

**Answer (call, 28 September 2026).** "0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63 this is the
royalty receiver wallet." It is not the admin, as Calea recommended; an unused externally owned
account on 4663 (read 28 September 2026).

**Recorded as (28 September).** COL-6, OPS-1: set through Studio before the first sale.

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

**Recorded as.** ACT-12 and RAF-14: no admin path into a holder's bear anywhere; RAF-28
defines *spent*.

### CQ-19 — Frontend and repository
- **Section:** DEL
- **Needed by:** before the tranche 1 handover
- **Status:** Answered (call, 21 September 2026)
- **Resolution:** MINT builds the app that holders use, in TypeScript, on **getminted.io**; Calea delivers a typed, tested TypeScript library for every contract interaction. The Framer landing page stays and is out of scope. Where the code lives is CQ-14.

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

### CQ-21 — How MINT's Status counts links across an account's wallets
- **Section:** ACT
- **Needed by:** —
- **Status:** Closed (call, 28 September 2026: out of scope)
- **Resolution:** out of scope: MINT assigns Status links to holders' Privy accounts off-chain; the on-chain link (ACT-9) is removed.

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

**Answer (call, 28 September 2026).** "Status links will be assigned to their users Privy accounts
off-chain, so this one falls out of scope for us." In the follow-up: the on-chain link can be
removed.

**Recorded as (28 September).** ACT-9 is retired. `linkBear`, `unlinkBear`, `linkOf`,
`BearLinked` and `BearUnlinked` leave `Activation` and the client library. MINT's Status reads
`levelOf` for the bear the account names.

### CQ-18 — How whitelist claims are recorded
- **Section:** WL
- **Needed by:** —
- **Status:** Answered (MINT's reply, 28 September 2026)
- **Resolution:** option **(B)** — an off-chain register in MINT's backend. No whitelist contract is deployed; the final CSV is loaded into Studio and Calea checks Studio's root against it.

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

**Answer (call, 28 September 2026).** "Whitelist will entirely be provided by csv and will be
entirely inputed by contract owner in bulk, as per their wish." Calea did not accept this at the
call because it is wholly centralised, and put a counter-offer to MINT, whose answer is awaited.

**The counter-offer.**
- **(A) Vouchers, as built (WL-3).** The chain enforces the 1,000 cap, two per wallet, two per
  account, the window and the order of claims. Nobody, the owner included, can add, remove or
  reassign a claim outside a signed voucher. The signer decides who is eligible.
- **(A′) Relayed vouchers.** The same, with MINT's backend submitting each voucher and paying the
  gas, so holders do nothing on-chain before the mint.
- **(A+) Vouchers plus an owner allocation**, within the same caps and with its own event, for
  partners and corrections.
- **(B) No registry.** MINT's CSV goes straight to Studio.

A registry filled by the owner from a CSV proves no more than Studio's allowlist root does, so if
MINT wants the whole list to be its own, the honest options are (B) or the frozen import below.

**Recorded as (28 September).** WL-7: `WhitelistImport`, which MINT's admin fills from the CSV in
batches within the 1,000 total and two per wallet. The admin can correct it until `closeAt`, and
after that it is frozen for good and `claimsOf` is the eligibility read. It is built beside
`WhitelistClaim`, and MINT deploys one of the two. Neither is audited (DEL-8).

**Answer (MINT, 28 September 2026).** MINT proposed the simplest flow instead of either registry:
the holder signs in through Privy or pastes a wallet, sees what has been wagered and what is left
to unlock a spot, and claims; the claim is stored off-chain. "Most other WL things are being done
through off chain wallet recording in a csv", and spots from collaborations and giveaways are
kept in the same backend. "This way there is no security check to do for any contract or
anything and we can get this pushed asap." MINT then accepted Calea's conditions:
- a wallet signature, which costs no gas, for a pasted address;
- one row per wallet with its total;
- a counter that cannot hand out the last spot twice;
- the list frozen at least 48 hours before the whitelist stage;
- the whitelist stage first, with no stage overlapping it.

The team bears are minted from the owner wallet and are not on the whitelist.

**Recorded as (reply of 28 September).** WL-8, the off-chain register, and WL-1, WL-2, WL-4 and WL-5. WL-3, WL-6 and WL-7
are retired. `WhitelistClaim` and `WhitelistImport` stay in Calea's repository, unused, as a
fallback.

**Also to confirm.** Whether spots from collaborations and giveaways count toward the 1,000, and
whether they may take a wallet above two (WL-1).
<!-- openspec:end -->

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
| Royalty pot mechanics | ETH cap or countdown; half the ETH buys $MNTD; a splitter wallet credits getminted.io accounts; MINT-side | MINT reply, Sep 2026 |
