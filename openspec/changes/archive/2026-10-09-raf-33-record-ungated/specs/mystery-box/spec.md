# Spec Delta

## MODIFIED Requirements

### Requirement: RAF-33 — Prize custody and the payout record
**Kind:** work-item
Prizes sit in MINT's prize wallet `0xf6c0…e3e3` on Robinhood Chain, Ethereum and possibly
ApeChain (MINT, CQ-8, CQ-20). No contract holds a prize or runs on a prize chain. A prize is paid
by an ordinary transfer to the winner's address on the prize's chain. Who sends it, and whether
MINT pushes every win or the winner requests it, is MINT's decision (CQ-22); the record below is
the same either way. Nothing on-chain forces a payout, and MINT can move any prize at any time.
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

### Requirement: RAF-18 — Worker sequence
**Kind:** work-item
A cycle runs in this order:
1. Once, before the first cycle, MINT records the team bears.
2. For each cycle, MINT publishes the prize list, schedules the cycle on both chains with the same
   prize count and fingerprint, and holds the prizes in its prize wallet.
3. Holders open boxes inside the window.
4. The worker carries each opening to the draw, in order.
5. Random numbers arrive and outcomes are recorded.
6. Each win is paid from the prize wallet on its chain, as MINT decides (`→ CQ-22`), and recorded.
7. After the window, MINT schedules the next cycle whenever it is ready.

MINT's page shows the cycle's window, its prize list, the live odds, a wallet's shots left, its
outcomes and its payouts, and warns contract-wallet holders before they open.

#### Scenario: The sequence runs end to end
- **WHEN** the sequence runs on the testnets through two cycles, from exclusion to the payout records
- **THEN** each step succeeds in the listed order, a relay offered out of turn is refused, and a bear opened in cycle 1 opens again in cycle 2
