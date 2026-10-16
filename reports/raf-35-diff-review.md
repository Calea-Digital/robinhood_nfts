# Differential review — RAF-35, `PrizeVault` (`feat/contracts...mnt/RAF-35`, `7eadd3d` plus fixes)

**Scope:** 12 files, +1,099 / −23. New: `src/PrizeVault.sol`, its suite, its tree and the token
mocks. Changed: the README, DESIGN, the INV numbering line in five trees, and
`BaseTest._assertInterface`, which gains a `receives` option; its two-argument form behaves as
before for its 6 call sites. No security code is removed, so there is no `git blame` regression to
trace.
**Strategy:** DEEP (a small diff, one HIGH-risk file). Phase 5 was run by the
`differential-review:adversarial-modeler` agent, which confirmed findings 1–3 with a throwaway PoC.
**Coverage:** `PrizeVault` 100% of lines, statements, branches and functions; 26 tests; 22
planted breakages, all caught.

## Risk

`PrizeVault` is HIGH: it holds value, makes external calls (balance reads) and gates by role.
Blast radius today: no caller in the code. Later callers: `claim`, `release` and `withdraw`
(RAF-36, RAF-37), the client (5.6) and the worker (4.2). They all rely on `reserved` being exact.

## Findings

No outsider can exploit anything. Every state-changing function is `onlyOwner`. `receive` and the
receiving hooks can only add to holdings.

| # | Severity | Finding | Status |
|---|---|---|---|
| 1 | Medium | One asset can back two reservations under different kinds: an ERC-721's `balanceOf(address)` answers the ERC-20 read, and a hybrid 721/1155 or ERC-404 token answers both. `[{ERC721, X, 7}, {ERC20, X, 0, 1}]` reserves 2 against one NFT, and one winner's claim fails later | **fixed** (the person: one kind per token while reserved; spec change `raf-35-review-hardening`): `KindMismatch`, tests `test_kind_oneKindPerTokenWhileReserved`, `test_kind_otherChainsEntriesNeverLockAKind` |
| 2 | Medium | The vault's `start` and `end` are the owner's inputs, unchecked against the box. A `start` typed later than the box's leaves the list replaceable while the cycle runs, after wins are known. An `end` of `uint40.max` keeps unclaimed prizes reserved for good, because `release` never comes due and `withdraw` refuses reserved assets | **fixed**: `InvalidWindow` above 90 days, test `test_registerCycle_refusesAWindowOverNinetyDays`; the runbook comparison with the box is DESIGN's and goes in the RUNBOOK with 5.4 |
| 3 | Low | Entries that reserve nothing or can't be paid are accepted: an `amount` of 0 (even for a token with no code); a `chainId` with no vault; unused fields that differ from what the vault reserves (an ERC-721 `amount` of 5) yet go into `manifestHash` | **fixed**: `InvalidPrize` on every entry, test `test_registerCycle_refusesANonCanonicalEntry`; unknown chains stay the list builder's (5.6) |
| 4 | Low | `_held` copied a token's whole answer into memory: a hostile listed token's answer bomb doubled the cost of the owner's own registration | **fixed**: `_readWord` copies 32 bytes; test `test_funding_readsOnlyTheFirstWordOfALongAnswer` (the old code fails it at 4.66M gas) |
| 5 | Info | DESIGN said "a vault cannot be given a list other than the one MINT published". The list and the hash are both the owner's arguments, so the check proves only that they agree with each other | **fixed**: DESIGN now says the binding is an off-chain comparison of `CycleRegistered` against `CycleScheduled`, made in the runbook |
| 6 | High in effect, by trust | "The owner withdraws only what is not reserved" holds for `withdraw` alone. A compromised owner's `setSigner(ownKey)` takes effect at once, so it can sign tickets for itself and claim every reserved prize in an open window. A leaked worker key can do the same without the owner, until a pause or rotation | **accepted** (the person): CQ-11's record, HANDOVER's accepted risks and DESIGN say so |

## Obligations for RAF-36 and RAF-37 (from the adversarial pass)

1. `claim` refuses before `start`, after `end + CLAIM_GRACE` and while paused. Otherwise a claim
   before `start` lowers `reserved`, and a later replacement subtracts the full old list.
2. `claim` requires `1 ≤ prizeIndex ≤ prizeCount`, because a shorter replacement leaves stale
   entries in storage, and `prize.chainId == block.chainid`.
3. The EIP-712 domain uses the live `block.chainid` and `address(this)`. The ticket binds
   `cycleId, openIndex, prizeIndex, winner`, with `msg.sender == winner`. Use Solady's ECDSA,
   which refuses a high `s`.
4. One claim per `(cycleId, prizeIndex)` as a bitmap, never per signature.
5. Pay and subtract with `_assetKey` and `_units`. An ERC-721 claim moves `id` and subtracts 1;
   checked subtraction; the flag is set before the transfer; `nonReentrant`.
6. `release` runs after the window and once per cycle, and lifts only this chain's unclaimed
   entries of that cycle. Registering a carried-over prize depends on `release` running first,
   which the runbook must state.
7. `withdraw` normalises through `_assetKey`, reads holdings as `_held` does, and requires
   `held − amount ≥ reserved`. Under finding 1, a withdrawal of the same token under another kind
   could still drain a reserved NFT.
8. Nothing else lowers `reserved` or moves a reserved asset: no approvals and no generic call.

## Verdict

No exploitable issue for an account without a role. Fixed: 1, 2, 3 (spec change
`raf-35-review-hardening`), 4 and 5. Accepted: 6. Re-check of the hardening: the per-token count
rises only beside the reservations a replacement lifts, so it cannot underflow; 13 planted
breakages of the new refusals are all caught. Confidence: high for this diff; claim, release and
withdraw are not built yet, and their obligations are in `PrizeVault.tree.md`.
