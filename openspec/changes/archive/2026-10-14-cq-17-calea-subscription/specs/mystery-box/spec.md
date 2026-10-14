## MODIFIED Requirements

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
