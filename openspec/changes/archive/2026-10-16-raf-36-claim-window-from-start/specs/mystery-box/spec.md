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
`signer()`, `paused()`, `eip712Domain()` (ERC-5267: the ticket's domain, from which the worker and
wallets build its typed data), `owner()` and `ownershipHandoverExpiresAt(pendingOwner)`. No other public
read exists on any of them. Each read costs a fixed amount, whatever the number of bears.

#### Scenario: Every read answers
- **WHEN** every listed read is called during an open cycle
- **THEN** each returns without reverting and `odds(cycleId)` returns `(prizesLeft, idsLeft)`

### Requirement: RAF-36 — Claiming a prize
**Kind:** work-item
A winner claims their prize on the prize's chain, paying gas there, with a ticket the worker
signs once the draw has recorded the win. MINT has stated that a winner needs gas on every
prize chain to claim. The ticket names the cycle, the opening, the prize and the winner: the
address that opened the box. Only that address can claim, the prize goes only to it, and each
prize is released once. The claim opens with the cycle and stays open until one hour after the
cycle's end, on the vault's own chain clock. Every recipient is treated alike: a smart-contract wallet that does not exist
on a prize chain cannot claim there, and that prize carries over (RAF-37).

*Technical note.* The ticket is an EIP-712 message `Claim(cycleId, openIndex, prizeIndex,
winner)` in the domain of the vault's chain and address, signed by the vault's `signer`, which is
the worker's address (CQ-23). `claim(cycleId, openIndex, prizeIndex, signature)` from
`msg.sender` = the winner is refused when paused (`ContractPaused`), for an unregistered cycle
(`UnknownCycle`), before the cycle's `start` or after `end + CLAIM_GRACE`, one hour
(`ClaimClosed`), for an entry on another chain or a `prizeIndex` outside the list (`WrongChain`), for a signature that does not recover to `signer` over the sender
(`InvalidTicket`), and for a prize already claimed (`AlreadyClaimed`). It transfers the prize to
the winner (native by value, ERC-20 by a safe transfer, ERC-721 and ERC-1155 by a safe transfer,
so a contract that cannot receive refuses it), lifts its reservation, and emits
`PrizeClaimed(cycleId, openIndex, prizeIndex, winner)`. It is non-reentrant.

#### Scenario: A winner claims once, within the window
- **GIVEN** cycle 1 registered with prize 1 on this chain, opening 7 won prize 1 for Alice, and the worker's ticket for it
- **WHEN** Bob sends Alice's ticket, then Alice claims, then Alice claims again, and Carol claims with her own winning ticket after `end` plus one hour
- **THEN** Bob's claim reverts with `InvalidTicket`, Alice receives prize 1 and `PrizeClaimed` is emitted, her second claim reverts with `AlreadyClaimed`, and Carol's reverts with `ClaimClosed`
