## MODIFIED Requirements

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

The worker is a service Calea builds and MINT runs on its own infrastructure (MINT, 12 October
2026, CQ-23), with Calea's instructions: how to create its wallet, fund it and start it. MINT
creates the worker's key, which Calea never sees, and MINT's admin authorises its address on the
draw. The wallet holds only ETH on Arbitrum One for gas. The worker keeps no state of its own: on
every start it reads from both chains where it stands, so a restart or a redeploy can't skip or
repeat an opening. It raises an alarm when its gas runs low and when an opening waits too long
for its outcome.

*Technical note.* A service in MINT's repository (`apps/box-worker`), packaged like the whitelist
API: a Dockerfile, Railway configuration and a health check. It reads `BoxOpened` on Robinhood
Chain and `nextToResolve`, `nextToApply` and `openCount` on both chains, and calls `resolve`,
`applyOutcomes` and `recordPayout` on `PrizeDraw` through the client library (DEL-6). The key is
a secret in MINT's Railway project; MINT's admin sets the address with `setWorker`. Its gas per
relay is measured on Arbitrum Sepolia in the rehearsal (OPS-4).

#### Scenario: The sequence runs end to end
- **WHEN** the sequence runs on the testnets through two cycles, from scheduling to the payout records
- **THEN** each step succeeds in the listed order, a relay offered out of turn is refused, and a bear opened in cycle 1 opens again in cycle 2

### Requirement: RAF-14 — Roles
**Kind:** work-item
**MINT's admin** schedules cycles, sets the worker and pauses either
contract. Ownership can't be given up. **The worker** carries openings to the draw and records
payouts; MINT runs it (CQ-23). **Anyone** can open a box with a bear they hold, apply outcomes
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
