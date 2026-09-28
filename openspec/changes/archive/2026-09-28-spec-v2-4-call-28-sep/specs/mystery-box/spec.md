# Spec Delta

## ADDED Requirements

### Requirement: RAF-32 — Cycles
**Kind:** work-item
The mystery box runs in **cycles**, and the owner (MINT's admin) sets each one before it starts
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

#### Scenario: A cycle opens and ends on its schedule
- **GIVEN** the owner has scheduled cycle 1 from `start` to `end` with 5 prizes
- **WHEN** a holder opens a box before `start`, between `start` and `end`, and after `end`
- **THEN** only the open between `start` and `end` succeeds, and the others revert with `CycleNotOpen`
- **AND** scheduling cycle 2 while cycle 1 is open reverts with `CycleInProgress`

### Requirement: RAF-33 — Prize custody and the payout record
**Kind:** work-item
Prizes are held in MINT's prize wallet `0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3`, an
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

#### Scenario: A win is paid once, and on the record
- **GIVEN** open 7 recorded as a win
- **WHEN** the worker calls `recordPayout(7, 1, txHash)`
- **THEN** `PrizePaid(cycleId, 7, 1, txHash)` is emitted
- **AND** a second `recordPayout` for open 7 reverts with `AlreadyPaid`, and one for an open that did not win reverts with `NotAWin`

### Requirement: RAF-34 — Pause
**Kind:** work-item
Pausing the hub blocks `open`. Pausing `PrizeDraw` blocks `resolve`, so no new word is requested,
while words already requested are still applied when they arrive. Neither pause blocks
`recordPayout` or any read. A cycle's window runs on while the hub is paused: a pause shortens
the time holders have, and it does not move `end`.

#### Scenario: Pause stops new opens and new requests
- **GIVEN** the hub and the draw each paused
- **WHEN** `open` and `resolve` are called
- **THEN** each reverts with `ContractPaused`
- **AND** `recordPayout` and every read still succeed

## MODIFIED Requirements

### Requirement: RAF-27 — Playable ids and the prize pool
**Kind:** work-item
Two numbers fix the odds of a cycle: the playable ids and the cycle's prize count.

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

#### Scenario: Opening freezes the odds
- **GIVEN** ranges excluded totalling 222 ids
- **WHEN** the owner schedules the first cycle
- **THEN** `PLAYABLE` reads 4,222 and `excludeRange` reverts with `ExclusionFrozen`

### Requirement: RAF-28 — Opening a box
**Kind:** work-item
`open(uint256 tokenId)` on `MysteryBox`, by the wallet that is `ownerOf(tokenId)` at that
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

#### Scenario: One bear is one shot
- **GIVEN** an open cycle and a holder of a playable bear not yet opened in it
- **WHEN** the holder calls `open(tokenId)`
- **THEN** `BoxOpened(openIndex, cycleId, tokenId, opener)` is emitted and `shotsLeft(holder)` falls by one
- **AND** the buyer of that bear cannot open it again in the same cycle, reverting with `AlreadyOpened`, and may open it in the next

### Requirement: RAF-29 — Resolution, in order
**Kind:** work-item
Each open is resolved on `PrizeDraw` by `resolve(uint64 openIndex, uint64 cycleId,
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

#### Scenario: Relays are accepted only in order
- **GIVEN** opens 1 and 2 recorded and neither resolved
- **WHEN** the worker calls `resolve(2, cycleId, opener)`
- **THEN** it reverts with `OutOfOrder`
- **AND** `resolve(1, cycleId, opener)` requests one Chainlink word and emits `DrawRequested`

### Requirement: RAF-30 — The win rule (normative)
**Kind:** work-item
Within a cycle, let `idsLeft` be the playable ids not yet resolved and `prizesLeft` the prizes
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

#### Scenario: The win rule applies the word
- **GIVEN** a cycle with `idsLeft` at 10, `prizesLeft` at 2 and a word w with `w mod 10 == 1`
- **WHEN** the open is resolved
- **THEN** `won` is true, the next entry of the cycle's prize list is assigned, `prizesLeft` reads 1 and `idsLeft` reads 9

### Requirement: RAF-8 — Randomness
**Kind:** work-item
Chainlink VRF v2.5, with one request and one word per open. `PrizeDraw` runs on **Arbitrum One**
(chain id 42161), agreed with MINT on 28 September 2026: coordinator
`0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e`, and on Arbitrum Sepolia (421614)
`0x5CE8D5A2BC84beb22a398CCA51996F7930313D61`. `PrizeDraw` is the subscription's consumer. The
subscription is assumed to be owned and funded by MINT (`→ CQ-17`). One request per open is what
buys an outcome nobody can predict, MINT included. The subscription is funded for a cycle's
worth of requests, at most `PLAYABLE`, and topped up on a balance alarm, not on a schedule.
Robinhood Chain has no Chainlink VRF and no usable `prevrandao`, which is why the draw is not on
the chain the bears live on.

#### Scenario: One request, one word, per open
- **WHEN** `resolve` runs
- **THEN** exactly one VRF v2.5 request is made from the subscription with `PrizeDraw` as consumer
- **AND** the outcome uses that request's word alone

### Requirement: RAF-14 — Roles
**Kind:** work-item
Owner (MINT's admin):
- on `MysteryBox`: `excludeRange`, `scheduleCycle`, `setPaused`;
- on `PrizeDraw`: `scheduleCycle`, `setWorker`, `setPaused`;
- ownership transfer on both.

`renounceOwnership` reverts on both.

Worker: `resolve` and `recordPayout` on `PrizeDraw`. Its operator is `→ CQ-23`.

Anyone: `open` as a bear's owner, and all reads.

No role can open a box for a holder, change an outcome, or move a bear.

#### Scenario: Roles hold
- **WHEN** a non-owner calls `excludeRange`, `scheduleCycle` or `setWorker`, or a non-worker calls `resolve` or `recordPayout`
- **THEN** each reverts
- **AND** `open` needs no role but the bear's ownership

### Requirement: RAF-16 — Events
**Kind:** work-item
The events each contract emits:
- **Hub:** `IdsExcluded(from, to)`, `CycleScheduled(cycleId, start, end, prizeCount,
  manifestHash)`, `BoxOpened(openIndex, cycleId, tokenId, opener)`, `PausedSet`.
- **`PrizeDraw`:** `CycleScheduled(cycleId, prizeCount, manifestHash)`,
  `DrawRequested(openIndex, requestId)`, `OutcomeRecorded(openIndex, cycleId, opener, won,
  prizeIndex)`, `PrizePaid(cycleId, openIndex, chainId, txHash)`, `WorkerSet`, `PausedSet`.

#### Scenario: Events carry the documented arguments
- **WHEN** a cycle runs through exclusion, scheduling, an open, a resolution and a payout record
- **THEN** every listed event fires with the documented arguments

### Requirement: RAF-17 — Reads
**Kind:** work-item
The reads each contract answers:
- **Hub:** `MAX_BEARS`, `PLAYABLE`, `isExcluded(tokenId)`, `currentCycle()` and each cycle's
  `(start, end, prizeCount, manifestHash)`, `isOpen()`, `opened(cycleId, tokenId)`,
  `openCount()`, `shotsLeft(wallet)`.
- **`PrizeDraw`:** `PLAYABLE`, each cycle's `(prizeCount, manifestHash, idsLeft, prizesLeft)`,
  `nextToResolve()`, `outcomeOf(openIndex)`, `payoutOf(openIndex)`, and `odds(cycleId)`
  returning `(prizesLeft, idsLeft)`.

#### Scenario: Every read answers
- **WHEN** every listed read is called during an open cycle
- **THEN** each returns without reverting and `odds(cycleId)` returns `(prizesLeft, idsLeft)`

### Requirement: RAF-18 — Worker sequence
**Kind:** work-item
The sequence, in order:
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
- a cycle in which every playable bear is opened awards exactly its prize count, and the pool
  neither empties early nor is left over;
- a cycle that ends early awards no more than its prize count;
- a win is recorded as paid once, and a loss cannot be;
- a holder who sells a bear after opening it keeps its outcome.

#### Scenario: Every case has a test
- **WHEN** the tranche-2 test suite runs
- **THEN** every listed case has a passing deterministic test

## REMOVED Requirements

### Requirement: RAF-26 — The game
**Reason:** The mystery box runs in cycles the owner schedules, not as one game (MINT, 28 September 2026).
**Migration:** See RAF-32.

### Requirement: RAF-31 — Closing the game
**Reason:** A cycle ends at its scheduled `end`, and unawarded prizes stay in MINT's prize wallet.
**Migration:** See RAF-32 and RAF-33.

### Requirement: RAF-2 — Addresses
**Reason:** No vault contracts; prizes are held in MINT's prize wallet (MINT, 28 September 2026).
**Migration:** See RAF-33.

### Requirement: RAF-3 — Asset approval
**Reason:** No vault contracts, so no asset approval on-chain; each cycle's prize list names its assets.
**Migration:** See RAF-27 and RAF-33.

### Requirement: RAF-4 — Intake
**Reason:** No vault contracts, so no deposit registration.
**Migration:** See RAF-33.

### Requirement: RAF-5 — Inventory states
**Reason:** Custody is MINT's wallet; the contracts track outcomes and payout records, not inventory.
**Migration:** See RAF-30 and RAF-33.

### Requirement: RAF-6 — Committing prizes
**Reason:** The prize list is published by MINT with its hash on-chain, not committed by vaults.
**Migration:** See RAF-27 and RAF-32.

### Requirement: RAF-24 — Prize vaults
**Reason:** No contract on any prize chain (MINT, 28 September 2026).
**Migration:** See RAF-33.

### Requirement: RAF-25 — Recipient nomination
**Reason:** Dropped at the call of 28 September 2026: the opener is the recipient, and exceptions are MINT's by hand.
**Migration:** See RAF-33.

### Requirement: RAF-11 — Claims
**Reason:** No vault to claim from; the payout is a transfer from MINT's prize wallet, pushed or requested per CQ-22.
**Migration:** See RAF-33.

### Requirement: RAF-15 — Pause
**Reason:** Its guarantees concerned vault claims, expiry and nomination, which are gone.
**Migration:** See RAF-34.
