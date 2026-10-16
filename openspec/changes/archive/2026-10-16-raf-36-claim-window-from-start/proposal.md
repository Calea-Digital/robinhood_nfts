# Proposal

## Why

RAF-36 opens the claim window at registration and closes it at `end + CLAIM_GRACE`. A real win
cannot exist before the cycle's `start`, because the box opens no box before it. A ticket signed
with a leaked worker key could, though, be claimed before `start`. That claim would lower a
reservation which a later replacement of the list then lifts in full, so the reservations would
no longer match the vault's holdings. MNT-166's review made "claim refuses before `start`" an
obligation for RAF-36, and the person chose to refuse it with `ClaimClosed` (16 October 2026).

The vault also exposes Solady's `eip712Domain()` (ERC-5267), which RAF-17's closed list of reads
does not name.

## What Changes

- **RAF-36:** the claim opens with the cycle. `claim` is refused with `ClaimClosed` before `start`
  as well as after `end + CLAIM_GRACE`. A `prizeIndex` outside the list is refused with
  `WrongChain`, since its entry names no chain. The Scenario is unchanged.
- **RAF-17:** `PrizeVault`'s reads include `eip712Domain()`. The worker and wallets build the
  ticket's typed data from it. The Scenario is unchanged.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mystery-box` (RAF): RAF-36's statement and note; RAF-17's note.

## Impact

`PrizeVault.claim` on `mnt/RAF-36` (MNT-167, In Progress) and its interface pin. No other
contract changes.
