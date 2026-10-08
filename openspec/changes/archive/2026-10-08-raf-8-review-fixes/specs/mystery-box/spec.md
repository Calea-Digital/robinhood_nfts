# Spec Delta

## MODIFIED Requirements

### Requirement: RAF-8 — Randomness
**Kind:** work-item
Each opening gets its own random number from Chainlink on Arbitrum One (agreed 28 September
2026). One number per opening is what makes an outcome nobody can predict, MINT included.
Robinhood Chain has no Chainlink and no usable randomness of its own, which is why the draw runs
on Arbitrum. The subscription that pays for the numbers is assumed to be MINT's (`→ CQ-17`). It
is funded for a cycle's worth, at most 4,222 numbers, and topped up when its balance runs low.
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
**MINT's admin** records the team bears, schedules cycles, sets the worker and pauses either
contract. Ownership can't be given up. **The worker** carries openings to the draw and records
payouts (who runs it `→ CQ-23`). **Anyone** can open a box with a bear they hold, apply outcomes
whose random numbers have arrived, and read everything. No role can open a box for a holder,
change an outcome or move a bear.

*Technical note.* Owner: on `MysteryBox` `excludeRange`, `scheduleCycle`, `setPaused`; on
`PrizeDraw` `scheduleCycle`, `setWorker`, `setPaused`; ownership transfer on both;
`renounceOwnership` reverts on both. Worker: `resolve` and `recordPayout` on `PrizeDraw`.
Anyone: `open` on `MysteryBox`, `applyOutcomes` on `PrizeDraw`. The VRF coordinator alone
delivers words.

#### Scenario: Roles hold
- **WHEN** a non-owner calls `excludeRange`, `scheduleCycle` or `setWorker`, or a non-worker calls `resolve` or `recordPayout`
- **THEN** each reverts
- **AND** `open` needs no role but the bear's ownership

### Requirement: RAF-16 — Events
**Kind:** work-item
Both contracts publish every step: the team-bear exclusions, each cycle's terms on both chains,
every opening, every request for a random number, every outcome with the bear that opened, every
payout, and every change of worker or pause.

*Technical note.* Hub: `IdsExcluded(from, to)`, `CycleScheduled(cycleId, start, end, prizeCount,
manifestHash)`, `BoxOpened(openIndex, cycleId, tokenId, opener)`, `PausedSet`. `PrizeDraw`:
`CycleScheduled(cycleId, start, prizeCount, manifestHash)`, `DrawRequested(openIndex, requestId)`,
`OutcomeRecorded(openIndex, cycleId, tokenId, opener, won, prizeIndex)`, `PrizePaid(cycleId,
openIndex, chainId, txHash)`, `WorkerSet`, `PausedSet`.

#### Scenario: Events carry the documented arguments
- **WHEN** a cycle runs through exclusion, scheduling, an open, a resolution and a payout record
- **THEN** every listed event fires with the documented arguments

### Requirement: RAF-19 — Acceptance cases
**Kind:** work-item
Each of these has a test:
- an excluded id cannot be opened, before or after it is sold;
- exclusions cannot change once the first cycle is scheduled;
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
an outcome, only when it is recorded. A delayed open shows as a `BoxOpened` with no
`OutcomeRecorded`; a relayed open that matches no `BoxOpened` on 4663 is visible the same way. An
open made before its cycle's `end` is resolved even if the word arrives after it.

#### Scenario: Relays are accepted only in order
- **GIVEN** opens 1 and 2 recorded and neither resolved
- **WHEN** the worker calls `resolve(2, cycleId, tokenId, opener)`
- **THEN** it reverts with `OutOfOrder`
- **AND** `resolve(1, cycleId, tokenId, opener)` requests one Chainlink word and emits `DrawRequested`

### Requirement: RAF-32 — Cycles
**Kind:** work-item
MINT's admin schedules each cycle before it starts: its window, its number of prizes, and a
fingerprint of the prize list MINT publishes (RAF-27) (MINT, CQ-9, CQ-20). A cycle can't be
scheduled while one is open, start in the past, or start before the previous one ends. A cycle
lasts at most 90 days, so a mistyped end date can't hold the game in one cycle for longer. A
scheduled cycle can be replaced until it starts; from then on its terms are fixed, on both
chains. Boxes open only inside the window, and an opening made inside it is decided even if the
answer arrives after the window ends (RAF-29). Prizes a cycle doesn't award stay in MINT's prize
wallet (RAF-33) for a later cycle. MINT decides when the next cycle starts, so the game can rest
between cycles for as long as MINT needs. The draw is given the same start, prize count and
fingerprint, and both chains publish them, so anyone can check they match.

*Technical note.* `scheduleCycle(start, end, prizeCount, manifestHash)` on `MysteryBox` records
the next cycle. It is refused while a cycle is open (`CycleInProgress`); for a window that starts
in the past, starts before the previous cycle ends, ends before it starts, or has `end - start`
above `MAX_CYCLE_LENGTH`, 90 days (`InvalidWindow`); and for a prize count of zero or above
`PLAYABLE` (`InvalidPrizeCount`). A cycle is open from `start` to `end` inclusive. `PrizeDraw`
carries each cycle's `start`, `prizeCount` and `manifestHash`, set by the owner with
`scheduleCycle(cycleId, start, prizeCount, manifestHash)`, and refuses to replace them once
`start` has passed or the cycle has accepted a relay (`CycleStarted`). Both chains emit
`CycleScheduled`.

#### Scenario: A cycle opens and ends on its schedule
- **GIVEN** the owner has scheduled cycle 1 from `start` to `end` with 5 prizes
- **WHEN** a holder opens a box before `start`, between `start` and `end`, and after `end`
- **THEN** only the open between `start` and `end` succeeds, and the others revert with `CycleNotOpen`
- **AND** scheduling cycle 2 while cycle 1 is open reverts with `CycleInProgress`
