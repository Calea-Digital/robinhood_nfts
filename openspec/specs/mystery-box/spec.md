# Mystery box raffle Specification

## Purpose
A holder opens a mystery box with a bear they own and learns the outcome on the spot. The box runs in cycles MINT schedules: in each cycle every playable bear gets one shot, and the next cycle gives every bear a new one, whoever holds it. `MysteryBox` on Robinhood Chain runs the cycles and records openings. `PrizeDraw` on Arbitrum One decides each opening and records wins and payouts.

## Requirements

### Requirement: RAF-32 — Cycles
**Kind:** work-item
MINT's admin schedules each cycle before it starts: its window, its number of prizes, and a
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

#### Scenario: A cycle opens and ends on its schedule
- **GIVEN** the owner has scheduled cycle 1 from `start` to `end` with 5 prizes
- **WHEN** a holder opens a box before `start`, between `start` and `end`, and after `end`
- **THEN** only the open between `start` and `end` succeeds, and the others revert with `CycleNotOpen`
- **AND** scheduling cycle 2 while cycle 1 is open reverts with `CycleInProgress`

### Requirement: RAF-27 — Playable ids and the prize pool
**Kind:** work-item
A cycle's odds depend on two numbers: how many bears can play and how many prizes it has. MINT's
222 team bears are excluded (which ids `→ CQ-20`). The exclusion is recorded once, before the
first cycle, and never changes. An excluded bear stays out whoever holds it, so a sold team bear
stays out. That leaves 4,222 playable bears. Before each cycle MINT publishes its prize list:
each prize's chain, token and id or amount, in order. The n-th prize won in a cycle is entry n
of the list. Only the count and the list's fingerprint are on-chain. The prizes are in MINT's
prize wallet (RAF-33), so the list is MINT's commitment.

*Technical note.* The owner records exclusions as ranges with `excludeRange(from, to)` (event
`IdsExcluded`), allowed only until the first cycle is scheduled and frozen after it
(`ExclusionFrozen`). `PLAYABLE = MAX_BEARS − excluded`, fixed when the first cycle is scheduled;
it is `PrizeDraw`'s constructor argument, so the excluded ranges are final before `PrizeDraw` is
deployed. The prize list's hash is the cycle's `manifestHash` (RAF-32); the contracts cannot
check it against a balance.

#### Scenario: Opening freezes the odds
- **GIVEN** ranges excluded totalling 222 ids
- **WHEN** the owner schedules the first cycle
- **THEN** `PLAYABLE` reads 4,222 and `excludeRange` reverts with `ExclusionFrozen`

### Requirement: RAF-28 — Opening a box
**Kind:** work-item
A bear's holder opens a box with it while a cycle is open, free apart from gas. The opening is
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

#### Scenario: One bear is one shot
- **GIVEN** an open cycle and a holder of a playable bear not yet opened in it
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
Chain, and the draw refuses a bear relayed twice in one cycle and a relay once a cycle's bears are
all decided. The worker relays an opening once Robinhood Chain's sequencer has confirmed it.

*Technical note.* `resolve(uint64 openIndex, uint64 cycleId, uint256 tokenId, address opener)` on
`PrizeDraw`, relayed from `BoxOpened`. It refuses any `openIndex` but the next unresolved one
(`OutOfOrder`); a cycle it has not been given or one earlier than the last it resolved
(`UnknownCycle`); a `tokenId` outside 1 to `MAX_BEARS` (`InvalidTokenId`); a `tokenId` already
resolved in that cycle (`AlreadyResolved`); and any resolve once the cycle's `idsLeft` is 0
(`CycleExhausted`). It requests one Chainlink word and emits `DrawRequested(openIndex,
requestId)`; outcomes are applied in `openIndex` order as the words arrive, so an open waits only
on the words of the opens before it. A delayed open shows as a `BoxOpened` with no
`OutcomeRecorded`; a relayed open that matches no `BoxOpened` on 4663 is visible the same way.
An open made before its cycle's `end` is resolved even if the word arrives after it.

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
on Arbitrum. The subscription that pays for the numbers is assumed to be MINT's (`→ CQ-17`). It
is funded for a cycle's worth, at most 4,222 numbers, and topped up when its balance runs low.

*Technical note.* Chainlink VRF v2.5, one request and one word per open. `PrizeDraw` on Arbitrum
One (42161) uses coordinator `0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e`, and on Arbitrum
Sepolia (421614) `0x5CE8D5A2BC84beb22a398CCA51996F7930313D61`; it is the subscription's consumer.
The subscription is funded for at most `PLAYABLE` requests per cycle and topped up on a balance
alarm, not on a schedule. Robinhood Chain's `prevrandao` is constant.

#### Scenario: One request, one word, per open
- **WHEN** `resolve` runs
- **THEN** exactly one VRF v2.5 request is made from the subscription with `PrizeDraw` as consumer
- **AND** the outcome uses that request's word alone

### Requirement: RAF-33 — Prize custody and the payout record
**Kind:** work-item
Prizes sit in MINT's prize wallet `0xf6c0…e3e3` on Robinhood Chain, Ethereum and possibly
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

#### Scenario: A win is paid once, and on the record
- **GIVEN** open 7 recorded as a win
- **WHEN** the worker calls `recordPayout(7, 1, txHash)`
- **THEN** `PrizePaid(cycleId, 7, 1, txHash)` is emitted
- **AND** a second `recordPayout` for open 7 reverts with `AlreadyPaid`, and one for an open that did not win reverts with `NotAWin`

### Requirement: RAF-14 — Roles
**Kind:** work-item
**MINT's admin** records the team bears, schedules cycles, sets the worker and pauses either
contract. Ownership can't be given up. **The worker** carries openings to the draw and records
payouts (who runs it `→ CQ-23`). **Anyone** can open a box with a bear they hold, and read
everything. No role can open a box for a holder, change an outcome or move a bear.

*Technical note.* Owner: on `MysteryBox` `excludeRange`, `scheduleCycle`, `setPaused`; on
`PrizeDraw` `scheduleCycle`, `setWorker`, `setPaused`; ownership transfer on both;
`renounceOwnership` reverts on both. Worker: `resolve` and `recordPayout` on `PrizeDraw`.

#### Scenario: Roles hold
- **WHEN** a non-owner calls `excludeRange`, `scheduleCycle` or `setWorker`, or a non-worker calls `resolve` or `recordPayout`
- **THEN** each reverts
- **AND** `open` needs no role but the bear's ownership

### Requirement: RAF-34 — Pause
**Kind:** work-item
Pausing the mystery box stops new openings. Pausing the draw stops new random numbers being
requested, while numbers already requested are still applied. Neither pause stops payout records
or reads. A pause doesn't extend a cycle; it only shortens the time holders have.

*Technical note.* Pausing the hub blocks `open`; pausing `PrizeDraw` blocks `resolve`. Neither
blocks `recordPayout` or any read, and a pause does not move `end`.

#### Scenario: Pause stops new opens and new requests
- **GIVEN** the hub and the draw each paused
- **WHEN** `open` and `resolve` are called
- **THEN** each reverts with `ContractPaused`
- **AND** `recordPayout` and every read still succeed

### Requirement: RAF-16 — Events
**Kind:** work-item
Both contracts publish every step: the team-bear exclusions, each cycle's terms on both chains,
every opening, every request for a random number, every outcome with the bear that opened, every
payout, and every change of worker or pause.

*Technical note.* Hub: `IdsExcluded(from, to)`, `CycleScheduled(cycleId, start, end, prizeCount,
manifestHash)`, `BoxOpened(openIndex, cycleId, tokenId, opener)`, `PausedSet`. `PrizeDraw`:
`CycleScheduled(cycleId, prizeCount, manifestHash)`, `DrawRequested(openIndex, requestId)`,
`OutcomeRecorded(openIndex, cycleId, tokenId, opener, won, prizeIndex)`, `PrizePaid(cycleId,
openIndex, chainId, txHash)`, `WorkerSet`, `PausedSet`.

#### Scenario: Events carry the documented arguments
- **WHEN** a cycle runs through exclusion, scheduling, an open, a resolution and a payout record
- **THEN** every listed event fires with the documented arguments

### Requirement: RAF-17 — Reads
**Kind:** work-item
The page can read for free: the playable count, whether a bear is excluded or already opened this
cycle, the current cycle and its terms, the longest a cycle may last, the live odds, and each
opening's bear, outcome and payout. A wallet's shots left come from these reads, one per bear
(RAF-28).

*Technical note.* Hub: `MAX_BEARS`, `PLAYABLE`, `MAX_CYCLE_LENGTH`, `isExcluded(tokenId)`,
`currentCycle()` and each cycle's `(start, end, prizeCount, manifestHash)`, `isOpen()`,
`opened(cycleId, tokenId)`, `openCount()`. `PrizeDraw`: `PLAYABLE`, each cycle's `(prizeCount,
manifestHash, idsLeft, prizesLeft)`, `nextToResolve()`, `outcomeOf(openIndex)` with its `tokenId`,
`payoutOf(openIndex)`, and `odds(cycleId)` returning `(prizesLeft, idsLeft)`. Each read costs a
fixed amount, whatever the number of bears.

#### Scenario: Every read answers
- **WHEN** every listed read is called during an open cycle
- **THEN** each returns without reverting and `odds(cycleId)` returns `(prizesLeft, idsLeft)`

### Requirement: RAF-18 — Worker sequence
**Kind:** work-item
A cycle runs in this order:
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

#### Scenario: The sequence runs end to end
- **WHEN** the sequence runs on the testnets through two cycles, from exclusion to the payout records
- **THEN** each step succeeds in the listed order, a relay offered out of turn is refused, and a bear opened in cycle 1 opens again in cycle 2

### Requirement: RAF-19 — Acceptance cases
**Kind:** work-item
Each of these has a test:
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
- a cycle in which every playable bear is opened awards exactly its prize count, and the pool
  neither empties early nor is left over;
- a cycle that ends early awards no more than its prize count;
- a win is recorded as paid once, and a loss cannot be;
- a holder who sells a bear after opening it keeps its outcome.

#### Scenario: Every case has a test
- **WHEN** the tranche-2 test suite runs
- **THEN** every listed case has a passing deterministic test

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
