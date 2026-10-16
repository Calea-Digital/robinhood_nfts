## MODIFIED Requirements

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
`released(cycleId)`, `signer()`, `paused()`, `eip712Domain()` (ERC-5267: the ticket's domain, from which the worker and
wallets build its typed data), `owner()` and `ownershipHandoverExpiresAt(pendingOwner)`. No other public
read exists on any of them. Each read costs a fixed amount, whatever the number of bears.

#### Scenario: Every read answers
- **WHEN** every listed read is called during an open cycle
- **THEN** each returns without reverting and `odds(cycleId)` returns `(prizesLeft, idsLeft)`

### Requirement: RAF-37 — Carry-over and withdrawal
**Kind:** work-item
A prize not claimed by the time the window closes stays in the vault, no longer reserved, and
MINT can put it in a later cycle's prize list. A prize decided after the window closed carries
over the same way. MINT's admin can withdraw anything the vault holds that is not reserved for
an open claim window, at any time, and never a reserved prize.

*Technical note.* Once `end + CLAIM_GRACE` has passed, anyone's `release(cycleId)` lifts the
reservations of the cycle's entries on this chain that are not claimed, and the counts of their
tokens, and emits `Released(cycleId)`. It runs whatever the pause, and is refused for a cycle with
no list (`UnknownCycle`), while the claim window is open, its last second included, since `claim`
accepts that second (`ClaimWindowOpen`), and for a cycle already released (`AlreadyReleased`).
`registerCycle` and `withdraw` count only what is still reserved. The owner's
`withdraw(kind, token, id, amount, to)` pays `to` by the asset's own transfer and emits
`Withdrawn(kind, token, id, amount, to)`. It is refused for an asset named as registration
refuses an entry (`InvalidPrize`), for a kind other than the one its token is reserved under
(`KindMismatch`), when it would leave less than the reserved amount of that asset (`Reserved`),
and for a zero `to` (`ZeroAddress`). It is non-reentrant.

#### Scenario: An unclaimed prize carries over
- **GIVEN** cycle 1's prize 3, an ERC-20 amount on this chain, unclaimed
- **WHEN** the owner withdraws it before the window closes, and after the window closes and `release(1)`
- **THEN** the first withdrawal reverts with `Reserved`, and after the release the amount can be registered in cycle 2's list or withdrawn
