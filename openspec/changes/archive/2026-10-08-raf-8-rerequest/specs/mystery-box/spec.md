# Spec Delta

## MODIFIED Requirements

### Requirement: RAF-8 — Randomness
**Kind:** work-item
Each opening gets its own random number from Chainlink on Arbitrum One (agreed 28 September
2026). One number per opening is what makes an outcome nobody can predict, MINT included.
Robinhood Chain has no Chainlink and no usable randomness of its own, which is why the draw runs
on Arbitrum. The subscription that pays for the numbers is assumed to be MINT's (`→ CQ-17`). It
is funded for a cycle's worth, at most 4,222 numbers, and topped up when its balance runs low. If
Chainlink has not answered an opening within 24 hours, the worker can ask again; whichever answer
arrives first is the one used, so asking again can never be used to pick a better number.

*Technical note.* Chainlink VRF v2.5, one request and one word per open. `PrizeDraw` on Arbitrum
One (42161) uses coordinator `0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e`, and on Arbitrum
Sepolia (421614) `0x5CE8D5A2BC84beb22a398CCA51996F7930313D61`; it is the subscription's consumer.
The subscription is funded for at most `PLAYABLE` requests per cycle and topped up on a balance
alarm, not on a schedule. Robinhood Chain's `prevrandao` is constant. `rerequest(openIndex)`, by
the worker, requests another word for a relayed opening with no word whose last request is at
least `REREQUEST_AFTER` (24 hours) old, emitting `DrawRequested` again; it is refused for an
opening not yet relayed (`NotRelayed`), one already answered (`AlreadyAnswered`) and one asked
more recently (`TooEarly`). Every request made for an opening stays valid, and the first word
delivered is stored and applied; later words are ignored.

#### Scenario: One request, one word, per open
- **WHEN** `resolve` runs
- **THEN** exactly one VRF v2.5 request is made from the subscription with `PrizeDraw` as consumer
- **AND** the outcome uses that request's word alone

### Requirement: RAF-14 — Roles
**Kind:** work-item
**MINT's admin** records the team bears, schedules cycles, sets the worker and pauses either
contract. Ownership can't be given up. **The worker** carries openings to the draw, asks again for
an opening Chainlink has not answered within a day, and records payouts (who runs it `→ CQ-23`).
**Anyone** can open a box with a bear they hold, apply outcomes whose random numbers have arrived,
and read everything. No role can open a box for a holder, change an outcome or move a bear.

*Technical note.* Owner: on `MysteryBox` `excludeRange`, `scheduleCycle`, `setPaused`; on
`PrizeDraw` `scheduleCycle`, `setWorker`, `setPaused`; ownership transfer on both;
`renounceOwnership` reverts on both. Worker: `resolve`, `rerequest` and `recordPayout` on
`PrizeDraw`. Anyone: `open` on `MysteryBox`, `applyOutcomes` on `PrizeDraw`. The VRF coordinator
alone delivers words.

#### Scenario: Roles hold
- **WHEN** a non-owner calls `excludeRange`, `scheduleCycle` or `setWorker`, or a non-worker calls `resolve` or `recordPayout`
- **THEN** each reverts
- **AND** `open` needs no role but the bear's ownership

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
- an opening Chainlink has not answered can be asked again only after 24 hours, and only the
  first answer to arrive is used;
- a cycle in which every playable bear is opened awards exactly its prize count, and the pool
  neither empties early nor is left over;
- a cycle that ends early awards no more than its prize count;
- a win is recorded as paid once, and a loss cannot be;
- a holder who sells a bear after opening it keeps its outcome.

#### Scenario: Every case has a test
- **WHEN** the tranche-2 test suite runs
- **THEN** every listed case has a passing deterministic test
