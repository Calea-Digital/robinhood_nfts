# Mystery box raffle Specification

## Purpose
A holder opens a mystery box with a bear they own and learns the outcome on the spot. The box runs in cycles MINT schedules: in each cycle every bear, the team's included, gets one shot, and the next cycle gives every bear a new one, whoever holds it. `MysteryBox` on Robinhood Chain runs the cycles and records openings. `PrizeDraw` on Arbitrum One decides each opening and records wins and payouts.

## Requirements

### Requirement: RAF-32 — Cycles
**Kind:** work-item
MINT's admin schedules each cycle before it starts: its window, its number of prizes, and a
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

#### Scenario: A cycle opens and ends on its schedule
- **GIVEN** the owner has scheduled cycle 1 from `start` to `end` with 5 prizes
- **WHEN** a holder opens a box before `start`, between `start` and `end`, and after `end`
- **THEN** only the open between `start` and `end` succeeds, and the others revert with `CycleNotOpen`
- **AND** scheduling cycle 2 while cycle 1 is open reverts with `CycleInProgress`

### Requirement: RAF-27 — Every bear plays, and the prize pool
**Kind:** work-item
Every one of the 4,444 bears plays, the team's 222 included, and a team bear can win like any
other (MINT, 12 October 2026, CQ-20). No bear is ever left out. A cycle's odds depend on two
numbers: the 4,444 bears and the cycle's number of prizes. Before each cycle MINT publishes
its prize list: each prize's chain, token and id or amount, in order. The n-th prize won in a
cycle is entry n of the list. Only the count and the list's fingerprint are on-chain. The prizes
are in MINT's prize wallet (RAF-33), so the list is MINT's commitment.

*Technical note.* `MysteryBox(owner, bears)` has no exclusion: `PLAYABLE` reads `MAX_BEARS`,
4,444, and `PrizeDraw` is deployed with `PLAYABLE` 4,444. The prize list's hash is the cycle's `manifestHash` (RAF-32); the contracts cannot check
it against a balance.

#### Scenario: Opening freezes the odds
- **GIVEN** a box deployed with no other call
- **WHEN** the owner schedules the first cycle
- **THEN** `PLAYABLE` reads 4,444 on both chains, and the holder of bear 1, a team bear, can open it

### Requirement: RAF-28 — Opening a box
**Kind:** work-item
A bear's holder opens a box with it while a cycle is open, free apart from gas. The opening is
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

#### Scenario: One bear is one shot
- **GIVEN** an open cycle and a holder of a bear not yet opened in it
- **WHEN** the holder calls `open(tokenId)`
- **THEN** `BoxOpened(openIndex, cycleId, tokenId, opener)` is emitted and `opened(cycleId, tokenId)` reads true
- **AND** the buyer of that bear cannot open it again in the same cycle, reverting with `AlreadyOpened`, and may open it in the next

### Requirement: RAF-29 — Resolution, in order
**Kind:** work-item
The worker carries each opening to the draw on Arbitrum One, which decides openings strictly in
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

#### Scenario: Relays are accepted only in order
- **GIVEN** opens 1 and 2 recorded and neither resolved
- **WHEN** the worker calls `resolve(2, cycleId, tokenId, opener)`
- **THEN** it reverts with `OutOfOrder`
- **AND** `resolve(1, cycleId, tokenId, opener)` requests one Chainlink word and emits `DrawRequested`

### Requirement: RAF-30 — The win rule (normative)
**Kind:** work-item
Each cycle is a fixed pool drawn without replacement. At every opening, the chance of winning is
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

#### Scenario: The win rule applies the word
- **GIVEN** a cycle with `idsLeft` at 10, `prizesLeft` at 2 and a word w with `w mod 10 == 1`
- **WHEN** the open is resolved
- **THEN** `won` is true, the next entry of the cycle's prize list is assigned, `prizesLeft` reads 1 and `idsLeft` reads 9

### Requirement: RAF-8 — Randomness
**Kind:** work-item
Each opening gets its own random number from Chainlink on Arbitrum One (agreed 28 September
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

#### Scenario: One request, one word, per open
- **WHEN** `resolve` runs
- **THEN** exactly one VRF v2.5 request is made from the subscription with `PrizeDraw` as consumer
- **AND** the outcome uses that request's word alone

### Requirement: RAF-33 — Prize custody and the payout record
**Kind:** work-item
Each cycle's prizes are held by the prize vault on their chain (RAF-35), funded from MINT's prize
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

#### Scenario: A win is paid once, and on the record
- **GIVEN** open 7 recorded as a win
- **WHEN** the worker calls `recordPayout(7, 1, txHash)`
- **THEN** `PrizePaid(cycleId, 7, 1, txHash)` is emitted
- **AND** a second `recordPayout` for open 7 reverts with `AlreadyPaid`, and one for an open that did not win reverts with `NotAWin`

### Requirement: RAF-14 — Roles
**Kind:** work-item
**MINT's admin** schedules cycles, registers each cycle's prizes on the vaults, withdraws what
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

#### Scenario: Roles hold
- **WHEN** a non-owner calls `scheduleCycle` or `setWorker`, or a non-worker calls `resolve` or `recordPayout`
- **THEN** each reverts
- **AND** `open` needs no role but the bear's ownership

### Requirement: RAF-34 — Pause
**Kind:** work-item
Pausing the mystery box stops new openings. Pausing the draw stops new random numbers being
requested, while numbers already requested are still applied. Pausing a prize vault stops
claims, for instance while a suspected key leak is handled. No pause stops payout records,
reads, registration or withdrawal, and no pause extends a cycle or a claim window; it only
shortens the time holders have.

*Technical note.* Pausing the hub blocks `open`; pausing `PrizeDraw` blocks `resolve`; pausing
`PrizeVault` blocks `claim`. None blocks `recordPayout`, `registerCycle`, `withdraw`, `release`
or any read, and no pause moves `end` or `end + CLAIM_GRACE`.

#### Scenario: Pause stops new opens and new requests
- **GIVEN** the hub and the draw each paused
- **WHEN** `open` and `resolve` are called
- **THEN** each reverts with `ContractPaused`
- **AND** `recordPayout` and every read still succeed

### Requirement: RAF-16 — Events
**Kind:** work-item
The contracts publish every step: each cycle's terms on every chain,
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

#### Scenario: Events carry the documented arguments
- **WHEN** a cycle runs through scheduling, an open, a resolution and a payout record
- **THEN** every listed event fires with the documented arguments

### Requirement: RAF-17 — Reads
**Kind:** work-item
The page can read for free: the playable count, whether a bear has opened this cycle, the current cycle and its terms, the longest a cycle may last, the live odds, each
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
`signer()`, `paused()`, `owner()` and `ownershipHandoverExpiresAt(pendingOwner)`. No other public
read exists on any of them. Each read costs a fixed amount, whatever the number of bears.

#### Scenario: Every read answers
- **WHEN** every listed read is called during an open cycle
- **THEN** each returns without reverting and `odds(cycleId)` returns `(prizesLeft, idsLeft)`

### Requirement: RAF-18 — Worker sequence
**Kind:** work-item
A cycle runs in this order:
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

#### Scenario: The sequence runs end to end
- **WHEN** the sequence runs on the testnets through two cycles, from funding and scheduling to the payout records
- **THEN** each step succeeds in the listed order, a relay offered out of turn is refused, each win is claimed from its vault with the worker's ticket and recorded, and a bear opened in cycle 1 opens again in cycle 2

### Requirement: RAF-19 — Acceptance cases
**Kind:** work-item
Each of these has a test:
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

#### Scenario: Every case has a test
- **WHEN** the tranche-2 test suite runs
- **THEN** every listed case has a passing deterministic test

### Requirement: RAF-35 — Prize vault and the cycle's prize list
**Kind:** work-item
Each cycle's prizes are held by a prize vault on the prize's chain: Robinhood Chain, Ethereum
and ApeChain, and Base when a cycle first uses it (MINT, 15 October 2026, CQ-22). The vault has
the same address on every chain and is owned by MINT's admin. It holds every kind of prize:
native coins (ETH, APE), tokens (ERC-20) and NFTs (ERC-721, ERC-1155). During cycle setup, MINT's
admin page sends the cycle's prizes from the prize wallet to the vault on each chain, then MINT's
admin registers the cycle's full prize list on every vault. The vault accepts the list only if
it is the list the cycle's fingerprint names and if it already holds every prize on its own
chain, so a published prize is provably there from the start. The list can be replaced until
the cycle starts. From registration until the claim window closes (RAF-36), the cycle's prizes
on that chain are reserved for their winners.

*Technical note.* `PrizeVault(owner, signer)` in `packages/contracts`, deployed through the
CREATE2 deployer `0x4e59…956C` with the same arguments on every chain, so its address is the
same. A prize is `(chainId, kind, token, id, amount)` with kind native, ERC-20, ERC-721 or
ERC-1155; the list's fingerprint is `keccak256(abi.encode(prizes))` over the full ordered list,
the cycle's `manifestHash` on `MysteryBox` and `PrizeDraw` (RAF-32). Prize n of the list is the
draw's `prizeIndex` n (RAF-27, RAF-30). The owner's `registerCycle(cycleId, start, end, prizes,
manifestHash)` is refused when the list hashes to another value (`ManifestMismatch`), is empty
or longer than `MAX_PRIZES` (`InvalidPrizeCount`), has `end` before `start` (`InvalidWindow`),
or the vault holds less of an entry for its own chain than what is already reserved plus the
entry (`Unfunded`), and once `start` has passed (`CycleStarted`). It reserves each own-chain
entry. The vault receives native coins, ERC-20 transfers and safe ERC-721 and ERC-1155
transfers.

#### Scenario: A cycle is registered only when funded and matching
- **GIVEN** a vault on chain 1 holding prize 2 of a cycle's list, an ERC-721, and not prize 4, an ERC-20 amount on chain 1
- **WHEN** the owner registers the list, then sends prize 4 and registers it again, and once more with an entry changed
- **THEN** the first registration reverts with `Unfunded`, the second succeeds and reserves prizes 2 and 4, and the changed list reverts with `ManifestMismatch`

### Requirement: RAF-36 — Claiming a prize
**Kind:** work-item
A winner claims their prize on the prize's chain, paying gas there, with a ticket the worker
signs once the draw has recorded the win. MINT has stated that a winner needs gas on every
prize chain to claim. The ticket names the cycle, the opening, the prize and the winner: the
address that opened the box. Only that address can claim, the prize goes only to it, and each
prize is released once. The claim is open until one hour after the cycle's end, on the vault's
own chain clock. Every recipient is treated alike: a smart-contract wallet that does not exist
on a prize chain cannot claim there, and that prize carries over (RAF-37).

*Technical note.* The ticket is an EIP-712 message `Claim(cycleId, openIndex, prizeIndex,
winner)` in the domain of the vault's chain and address, signed by the vault's `signer`, which is
the worker's address (CQ-23). `claim(cycleId, openIndex, prizeIndex, signature)` from
`msg.sender` = the winner is refused when paused (`ContractPaused`), for an unregistered cycle
(`UnknownCycle`), after `end + CLAIM_GRACE`, one hour (`ClaimClosed`), for an entry on another
chain (`WrongChain`), for a signature that does not recover to `signer` over the sender
(`InvalidTicket`), and for a prize already claimed (`AlreadyClaimed`). It transfers the prize to
the winner (native by value, ERC-20 by a safe transfer, ERC-721 and ERC-1155 by a safe transfer,
so a contract that cannot receive refuses it), lifts its reservation, and emits
`PrizeClaimed(cycleId, openIndex, prizeIndex, winner)`. It is non-reentrant.

#### Scenario: A winner claims once, within the window
- **GIVEN** cycle 1 registered with prize 1 on this chain, opening 7 won prize 1 for Alice, and the worker's ticket for it
- **WHEN** Bob sends Alice's ticket, then Alice claims, then Alice claims again, and Carol claims with her own winning ticket after `end` plus one hour
- **THEN** Bob's claim reverts with `InvalidTicket`, Alice receives prize 1 and `PrizeClaimed` is emitted, her second claim reverts with `AlreadyClaimed`, and Carol's reverts with `ClaimClosed`

### Requirement: RAF-37 — Carry-over and withdrawal
**Kind:** work-item
A prize not claimed by the time the window closes stays in the vault, no longer reserved, and
MINT can put it in a later cycle's prize list. A prize decided after the window closed carries
over the same way. MINT's admin can withdraw anything the vault holds that is not reserved for
an open claim window, at any time, and never a reserved prize.

*Technical note.* After `end + CLAIM_GRACE`, anyone's `release(cycleId)` lifts the cycle's
remaining reservations and emits `Released(cycleId)`; `registerCycle` and `withdraw` count only
what is still reserved. The owner's `withdraw(kind, token, id, amount, to)` is refused when it
would leave less than the reserved amount of that asset (`Reserved`) and emits `Withdrawn`.

#### Scenario: An unclaimed prize carries over
- **GIVEN** cycle 1's prize 3, an ERC-20 amount on this chain, unclaimed
- **WHEN** the owner withdraws it before the window closes, and after the window closes and `release(1)`
- **THEN** the first withdrawal reverts with `Reserved`, and after the release the amount can be registered in cycle 2's list or withdrawn

## Retired Requirements

- RAF-1 (a single raffle chain) → RAF-32, RAF-33
- RAF-7 (passive ownership snapshot) → RAF-28
- RAF-9 (draw over calldata entries) → RAF-30
- RAF-10 (carry forward between rounds) → RAF-32
- RAF-12 (round cancellation) → RAF-32
- RAF-13 (per-round `minLevel` eligibility) → RAF-27
- RAF-20 (rounds on the hub) → RAF-32
- RAF-21 (entry into a round) → RAF-28
- RAF-22 (one seed per round) → RAF-29
- RAF-23 (the per-round draw) → RAF-30
- RAF-2 (vault addresses) → RAF-33
- RAF-3 (asset approval on the vaults) → RAF-27, RAF-33
- RAF-4 (deposit intake) → RAF-33
- RAF-5 (vault inventory states) → RAF-30, RAF-33
- RAF-6 (committing prizes from the vaults) → RAF-27, RAF-32
- RAF-11 (claims from a vault) → RAF-33
- RAF-15 (pause with vault claims) → RAF-34
- RAF-24 (a prize vault per chain) → RAF-33
- RAF-25 (recipient nomination) → RAF-33
- RAF-26 (one game over the collection) → RAF-32
- RAF-31 (closing the game) → RAF-32, RAF-33
