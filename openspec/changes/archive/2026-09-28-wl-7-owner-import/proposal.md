# Proposal

## Why

At the call of 28 September 2026 MINT asked for a whitelist that it fills itself: the eligible
wallets arrive as a CSV and the contract owner writes them in bulk (CQ-18, §10 O8). Calea has put
a counter-offer to MINT and is waiting for the answer. `WhitelistClaim` is wanted on
29 September, and it cannot be upgraded once deployed, so both variants have to be ready
whichever one MINT picks. This change specifies the owner-imported variant beside the voucher
registry (WL-3). WL-3 is not changed.

## What Changes

- ADDED WL-7: `WhitelistImport`, a registry on Robinhood Chain that MINT's admin fills from a CSV
  in batches, within the 1,000-allocation cap and the limit of two per wallet. The admin can
  correct the list until `closeAt`. After `closeAt` the list is frozen for good, and the export
  and the Studio compare read it the way they read `WhitelistClaim`.

## Capabilities

### Modified Capabilities

- `whitelist` (prefix `WL`): WL-7 added.

## Impact

- New `src/WhitelistImport.sol`, `test/WhitelistImport.t.sol` and `test/WhitelistImport.tree.md`.
- `script/Deploy.s.sol` gains a `runWhitelistImport` entry point, and `script/WhitelistExport.s.sol`
  reads either registry.
- DEL-6 client: a `whitelistImport` module with CSV parsing, batching and the owner calls for
  MINT's admin page.
- The CSV variant has no voucher, signer or per-account cap, and no public first-come-first-served
  order: who is eligible is MINT's alone, and the chain records what the owner wrote and when.
