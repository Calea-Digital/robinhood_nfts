# Differential review: MNT-158 (DEL-6), the client's mystery-box calls

- **Target:** `git -C ../NFT diff feat/contracts...mnt/DEL-6-158`, at `17b68b8` and the fix commit after it.
- **Scope:** `packages/contracts-client` only: 24 files, about 3,900 lines, 2,000 of them generated ABIs. No contract changes.
- **Date:** 2026-10-09.
- **Strategy:** DEEP. The package is small: every changed source file was read, and every
  behaviour-carrying function was traced.

## Risk classification

| File | Risk | Why |
|---|---|---|
| `src/client.ts` (`worker`, `mysteryBoxAdmin`) | HIGH | It builds the worker's relay and payout records and the admin's terms on two chains: what decides who a prize is recorded for and which terms a cycle runs under. |
| `src/prizeDraw.ts` | HIGH | The relay and payout plans, and the outcome and odds reads a holder sees. |
| `src/mysteryBox.ts` | MEDIUM | The opening plan, the shots-left count, and the schedule plan. |
| `src/errors.ts` | MEDIUM | Error names two contracts share are now mapped by function. |
| `src/events.ts` | MEDIUM | `SystemAddresses` is loosened, and two emitters are added. |
| ABIs, chains, constants, README, tests | LOW | Generated or descriptive. |

## Removed or loosened code

- **`codeForRevert(revert)` became `codeForRevert(revert, functionName)`.** The mapping by name is
  unchanged, and an override applies only for `open`, `resolve` and `scheduleCycle`. `burn`'s
  `ContractPaused` still decodes to `ACTIVATION_PAUSED`; a test pins that.
- **`SystemAddresses`: `bears` and `activation` became optional.** Blast radius: 5 call sites, all
  in `client.ts`, and all but the new `prizeDraw.events` pass the full deployment. The one risk was
  an empty address list, which reads every contract's logs; `readSystemEvents` now returns `[]`
  for it.

## Findings

### F-1 (Medium; fixed): `worker.relay` relayed whatever opening it was handed

- **Root cause:** `planRelay` checks the pause, the worker, the order, the cycle's terms, the id
  range and a non-zero opener. It never checked that the opening is the one the box recorded. The
  draw can't check it either: it trusts the worker by design (RAF-29).
- **Scenario:** a worker integration builds the opening from the wrong source, for example the
  transaction's `from` (a smart wallet's bundler) instead of `BoxOpened.opener`, or a cycle off by
  one. The relay is accepted:
  - a wrong opener makes the draw record the win, and the payout, for another wallet;
  - a later `cycleId` closes the current cycle on the draw for good, through `lastCycleResolved`.
- **Fix:**
  - `worker.relay` now reads the box's `BoxOpened` for that `openIndex` on Robinhood Chain first.
  - It refuses `OPENING_NOT_FOUND` when there is none.
  - It refuses `OPENING_MISMATCH`, naming the field, when `cycleId`, `tokenId` or `opener` differ.
  - `planRelay` stays a pure check of the draw's rules.
- **Tests:** `relays only what the box recorded…` covers a wrong opener, cycle and bear, and an
  opening never made. Three breakages fail it: no check, the opener unchecked, and a missing
  opening relayed anyway.

### F-2 (Medium; fixed): `mysteryBoxAdmin.scheduleOnDraw` could give the draw terms the box doesn't have

- **Root cause:** it is the escape hatch for finishing a `scheduleCycle` whose draw half failed,
  but it sent any terms.
- **Scenario:** the admin types a different prize count or list hash. The draw runs a different
  pool from the one the box and the published prize list promise (RAF-32: the same count and hash
  on both chains).
- **Fix:** it reads the box's `cycle(cycleId)` and refuses `CYCLE_TERMS_MISMATCH`, naming the
  field, unless the start, prize count and hash all match.
- **Tests:** the partial-schedule test covers another count, hash and start. Two breakages fail it:
  the hash unchecked, and the start unchecked.

### F-3 (Informational): `nextOpening` reads to the latest block

RAF-29 relays an opening once Robinhood Chain's sequencer has confirmed it, which the latest block
is. A `toBlock` parameter now lets an operator wait for more; the default is unchanged. This is
recorded for the worker's runbook (CQ-23).

## Checked and sound

- **Different terms on the two chains:** `scheduleCycle` sends the draw the box's emitted
  `cycleId` with the same input terms. When the draw fails, the error's `completed` carries the
  box's result. A replacement keeps its id on both chains.
- **Payouts:** `planRecordPayout` requires a decided win (`status === "won"`, so not a stored word
  still waiting), not yet paid, a non-zero chain and a 32-byte non-zero hash, and the current
  worker.
- **Outcome shown:** an opening is `unrelayed` while its opener is zero (the draw refuses a zero
  opener), `waiting` until applied, then `won` or `lost`. `odds` keeps the contract's order,
  `(prizesLeft, idsLeft)`, pinned with unequal values.
- **Shots shown:** the cycle's state and every bear are read at one block. `opened` is read for the
  `currentCycle` of that block. An unminted id's `ownerOf` failure counts as not owned. The count is
  zero unless the cycle is open and the box is not paused. Ids outside 1–4,444, or duplicated, are
  refused.
- **Error codes:** `ContractPaused` and `InvalidWindow` are decoded by function. Every other name
  of the box and the draw is distinct from existing names, or (`NotBearOwner`) carries the same
  meaning.

## Coverage

- Client: 170 tests, including 15 for the box, 12 for the draw and 2 in the example.
- 25 planted breakages, each failing its test: 20 before this review, 5 for its fixes.
- **Not covered locally:** a real Chainlink delivery, and the two chains being different chains.
  One anvil chain stands in for both, and the facade's two clients are independent, so this needs
  a fork run on 46630 plus Arbitrum Sepolia at `/mnt:review`.

**Confidence:** high for the client's logic. Its correctness depends on the contracts, which are
covered by their own suites.
