# Spec Delta

## MODIFIED Requirements

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
cycle, the current cycle and its terms, the live odds, and each opening's bear, outcome and
payout. A wallet's shots left come from these reads, one per bear (RAF-28).

*Technical note.* Hub: `MAX_BEARS`, `PLAYABLE`, `isExcluded(tokenId)`, `currentCycle()` and each
cycle's `(start, end, prizeCount, manifestHash)`, `isOpen()`, `opened(cycleId, tokenId)`,
`openCount()`. `PrizeDraw`: `PLAYABLE`, each cycle's `(prizeCount, manifestHash, idsLeft,
prizesLeft)`, `nextToResolve()`, `outcomeOf(openIndex)` with its `tokenId`, `payoutOf(openIndex)`,
and `odds(cycleId)` returning `(prizesLeft, idsLeft)`. Each read costs a fixed amount, whatever
the number of bears.

#### Scenario: Every read answers
- **WHEN** every listed read is called during an open cycle
- **THEN** each returns without reverting and `odds(cycleId)` returns `(prizesLeft, idsLeft)`

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
