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
(`AlreadyPaid`), and refused for a zero `chainId` or `txHash` (`InvalidPayout`), which would
close the win with no evidence; it emits `PrizePaid(cycleId, openIndex, chainId, txHash)`, and
`payoutOf(openIndex)` reads the record. There is no on-chain
nomination of another recipient.

#### Scenario: A win is paid once, and on the record
- **GIVEN** open 7 recorded as a win
- **WHEN** the worker calls `recordPayout(7, 1, txHash)`
- **THEN** `PrizePaid(cycleId, 7, 1, txHash)` is emitted
- **AND** a second `recordPayout` for open 7 reverts with `AlreadyPaid`, and one for an open that did not win reverts with `NotAWin`
