# Spec Delta

## ADDED Requirements

### Requirement: WL-7 — Owner-imported registry
**Kind:** work-item
`WhitelistImport` on Robinhood Chain is the variant of the registry for a whitelist MINT fills
itself from a CSV (`→ CQ-18`). WL-3 is the alternative, and MINT deploys one of the two.
Constructor: `WhitelistImport(owner, closeAt)`; the owner is MINT's admin and is not the zero
address. Until `closeAt` the owner can write the list:
- `addAllocations(address[] wallets, uint8[] counts)` gives each wallet `counts[i]` more
  allocations. The call is refused whole, with no partial state, on any of these:
  - after `closeAt` (`ListFrozen`);
  - arrays of different lengths (`LengthMismatch`);
  - a zero wallet (`ZeroWallet`);
  - a zero count (`ZeroCount`);
  - a wallet above `MAX_PER_WALLET` = 2 (`WalletLimit`);
  - a total above `TOTAL_SPOTS` = 1,000 (`SoldOut`).
- `removeAllocations(address[] wallets)` sets each wallet's allocations to zero and drops it from
  the list. After `closeAt` it is refused (`ListFrozen`); for a wallet with no allocations it is
  refused (`NotListed`).
- `setCloseAt(closeAt)` moves the freeze, so the owner can extend the import or freeze early.
  After `closeAt` it is refused (`ListFrozen`); a close in the past is refused (`InvalidWindow`).

Once `block.timestamp > closeAt` the list is frozen for good. Nothing can then add, remove or
reassign an allocation, and `claimsOf(wallet)` is the wallet's eligibility for the whitelist
stage.

Events:
- `AllocationsAdded(wallet, count, total)` for each wallet;
- `AllocationsRemoved(wallet, count)`;
- `CloseSet(closeAt)`.

Reads, with the names `WhitelistClaim` uses so the export and the Studio compare (WL-4) read
either registry:
- `TOTAL_SPOTS`, `MAX_PER_WALLET`;
- `spotsLeft()`, `claimsOf(wallet)`;
- `claimants(offset, limit) → (wallet, allocations)[]`, each listed wallet once;
- `closeAt`, `frozen()`.

`renounceOwnership` reverts for every caller. There is no voucher, no signer and no per-account
cap: who is eligible is MINT's alone to decide, and the chain records what the owner wrote and
when.

#### Scenario: The owner's import freezes at the close
- **GIVEN** a `WhitelistImport` whose `closeAt` has not passed
- **WHEN** the owner adds allocations for wallets A (2) and B (1), and `closeAt` then passes
- **THEN** `claimsOf(A)` reads 2, `claimsOf(B)` reads 1 and `spotsLeft` reads 997
- **AND** any later `addAllocations`, `removeAllocations` or `setCloseAt` reverts with `ListFrozen`
