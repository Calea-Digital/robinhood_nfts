# Proposal

## Why

The review of RAF-33 (9 October) found one gap. A payout recorded with a zero `chainId` or a zero
`txHash` would close the win for good with no evidence, and `AlreadyPaid` would then block the
correct record. The code refuses that case with `InvalidPayout`, but RAF-33's technical note names
only `NotAWin` and `AlreadyPaid`. The spec, the client document and the client's error codes need
to carry the third refusal.

## What Changes

- RAF-33's technical note adds `InvalidPayout`, for a zero `chainId` or `txHash`, and names the
  `payoutOf(openIndex)` read. RAF-17 already lists that read.
- The statement and the Scenario are unchanged.

## Capabilities

### Modified Capabilities

- `mystery-box` (RAF): RAF-33.

## Impact

- **Code:** `PrizeDraw.recordPayout` on `mnt/RAF-33` already implements this. MNT-137 is In
  Review.
- **Board:** MNT-137's body is refreshed.
- **Client document:** the next build carries it. `spec_version` stays 2.6.
