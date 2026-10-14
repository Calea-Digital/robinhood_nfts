## RENAMED Requirements

- FROM: `### Requirement: RAF-27 — Playable ids and the prize pool`
- TO: `### Requirement: RAF-27 — Every bear plays, and the prize pool`

## MODIFIED Requirements

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

### Requirement: RAF-8 — Randomness
**Kind:** work-item
Each opening gets its own random number from Chainlink on Arbitrum One (agreed 28 September
2026). One number per opening is what makes an outcome nobody can predict, MINT included.
Robinhood Chain has no Chainlink and no usable randomness of its own, which is why the draw runs
on Arbitrum. The subscription that pays for the numbers is assumed to be MINT's (`→ CQ-17`). It
is funded for a cycle's worth, at most 4,444 numbers, and topped up when its balance runs low.
Each opening is asked for once and never again: asking again would let whoever delivers the
numbers keep a losing one back and deliver a winning one instead. A request left unanswered
because the subscription ran low is answered once it is topped up. If the draw ever has to move
to another coordinator or subscription, a new draw takes over at the next opening.

*Technical note.* Chainlink VRF v2.5, one request and one word per open, never re-requested.
`PrizeDraw` on Arbitrum One (42161) uses coordinator `0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e`,
and on Arbitrum Sepolia (421614) `0x5CE8D5A2BC84beb22a398CCA51996F7930313D61`; it is the
subscription's consumer. The subscription is funded for at most `PLAYABLE` requests per cycle and
topped up on a balance alarm, not on a schedule. Robinhood Chain's `prevrandao` is constant. The
constructor takes `firstOpenIndex`, the first opening the draw relays (1 for the first draw; for a
replacement, the next unresolved opening), and both `nextToResolve` and `nextToApply` start there.

#### Scenario: One request, one word, per open
- **WHEN** `resolve` runs
- **THEN** exactly one VRF v2.5 request is made from the subscription with `PrizeDraw` as consumer
- **AND** the outcome uses that request's word alone

### Requirement: RAF-14 — Roles
**Kind:** work-item
**MINT's admin** schedules cycles, sets the worker and pauses either
contract. Ownership can't be given up. **The worker** carries openings to the draw and records
payouts (who runs it `→ CQ-23`). **Anyone** can open a box with a bear they hold, apply outcomes
whose random numbers have arrived, and read everything. No role can open a box for a holder,
change an outcome or move a bear.

*Technical note.* Owner: on `MysteryBox` `scheduleCycle`, `setPaused`; on
`PrizeDraw` `scheduleCycle`, `setWorker`, `setPaused`. Ownership moves on both only by Solady's
two-step handover: the new owner's `requestOwnershipHandover`, then the owner's
`completeOwnershipHandover` within 48 hours; `transferOwnership` reverts with
`TwoStepHandoverOnly` and `renounceOwnership` with `RenounceDisabled` on both. Worker: `resolve` and `recordPayout` on `PrizeDraw`.
Anyone: `open` on `MysteryBox`, `applyOutcomes` on `PrizeDraw`. The VRF coordinator alone
delivers words.

#### Scenario: Roles hold
- **WHEN** a non-owner calls `scheduleCycle` or `setWorker`, or a non-worker calls `resolve` or `recordPayout`
- **THEN** each reverts
- **AND** `open` needs no role but the bear's ownership

### Requirement: RAF-16 — Events
**Kind:** work-item
Both contracts publish every step: each cycle's terms on both chains,
every opening, every request for a random number, every outcome with the bear that opened, every
payout, and every change of worker or pause.

*Technical note.* Hub: `CycleScheduled(cycleId, start, end, prizeCount,
manifestHash)`, `BoxOpened(openIndex, cycleId, tokenId, opener)`, `PausedSet`. `PrizeDraw`:
`CycleScheduled(cycleId, start, prizeCount, manifestHash)`, `DrawRequested(openIndex, requestId)`,
`OutcomeRecorded(openIndex, cycleId, tokenId, opener, won, prizeIndex)`, `PrizePaid(cycleId,
openIndex, chainId, txHash)`, `WorkerSet`, `PausedSet`.

#### Scenario: Events carry the documented arguments
- **WHEN** a cycle runs through scheduling, an open, a resolution and a payout record
- **THEN** every listed event fires with the documented arguments

### Requirement: RAF-17 — Reads
**Kind:** work-item
The page can read for free: the playable count, whether a bear has opened this cycle, the current cycle and its terms, the longest a cycle may last, the live odds, and each
opening's bear, outcome and payout. A wallet's shots left come from these reads, one per bear
(RAF-28).

*Technical note.* Hub: `MAX_BEARS`, `PLAYABLE`, `MAX_CYCLE_LENGTH`, `currentCycle()` and each cycle's
`(start, end, prizeCount, manifestHash)`, `isOpen()`, `opened(cycleId, tokenId)`, `openCount()`,
`paused()`, `BEARS`, `owner()` and `ownershipHandoverExpiresAt(pendingOwner)`. `PrizeDraw`:
`MAX_BEARS`, `PLAYABLE`, each cycle's `(prizeCount, manifestHash, idsLeft, prizesLeft)`,
`nextToResolve()`, `nextToApply()`, `lastCycleResolved()`, `outcomeOf(openIndex)` with its
`tokenId`, `payoutOf(openIndex)`, `odds(cycleId)` returning `(prizesLeft, idsLeft)`,
`openingOfRequest(requestId)` (0 for a request the draw never made), `RESOLVE_APPLY_LIMIT`,
`worker()`, `paused()`, the Chainlink configuration `COORDINATOR`, `KEY_HASH`, `SUBSCRIPTION_ID`,
`CALLBACK_GAS_LIMIT`, `REQUEST_CONFIRMATIONS` and `NATIVE_PAYMENT`, `owner()` and
`ownershipHandoverExpiresAt(pendingOwner)`. No other public read exists on either contract. Each
read costs a fixed amount, whatever the number of bears.

#### Scenario: Every read answers
- **WHEN** every listed read is called during an open cycle
- **THEN** each returns without reverting and `odds(cycleId)` returns `(prizesLeft, idsLeft)`

### Requirement: RAF-18 — Worker sequence
**Kind:** work-item
A cycle runs in this order:
1. For each cycle, MINT publishes the prize list, schedules the cycle on both chains with the same
   prize count and fingerprint, and holds the prizes in its prize wallet.
2. Holders open boxes inside the window.
3. The worker carries each opening to the draw, in order.
4. Random numbers arrive and outcomes are recorded.
5. Each win is paid from the prize wallet on its chain, as MINT decides (`→ CQ-22`), and recorded.
6. After the window, MINT schedules the next cycle whenever it is ready.

MINT's page shows the cycle's window, its prize list, the live odds, a wallet's shots left, its
outcomes and its payouts, and warns contract-wallet holders before they open.

#### Scenario: The sequence runs end to end
- **WHEN** the sequence runs on the testnets through two cycles, from scheduling to the payout records
- **THEN** each step succeeds in the listed order, a relay offered out of turn is refused, and a bear opened in cycle 1 opens again in cycle 2

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
