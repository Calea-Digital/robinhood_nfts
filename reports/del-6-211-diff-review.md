# Differential review — DEL-6 (Defect MNT-211): BearDrop in the client

- **Repository:** `~/trees/NFT` (mintdotio/NFT), branch `mnt/DEL-6-211` off `feat/contracts` `f0ba784`
- **Reviewed:** `bffc3fa`, then the fixes below
- **Date:** 2026-10-30
- **Reviewer:** Claude Code (self-review; the code is the reviewer's own, so read it with that bias)
- **Scope:** `packages/contracts-client` only: 17 files, no contract change. Strategy DEEP (small diff).

## Risk classification

| File | Risk | Why |
|---|---|---|
| `src/bearDrop.ts` (new) | HIGH | plans that gate sends of value: claim, withdraw, load, open |
| `src/errors.ts` | HIGH | error decoding: a wrong code shows a holder the wrong reason |
| `src/calls.ts` | MEDIUM | every send now decodes under `errorKey(call)` (blast radius: every write of the library) |
| `src/client.ts` | MEDIUM | the facade's `drop` and `dropAdmin` groups |
| `src/addresses.ts`, `index.ts`, `abi/*`, `scripts/*` | LOW | an optional address, exports, generated ABI, the README table |
| tests, examples, README, tree | LOW | evidence and docs |

## Parity with `src/BearDrop.sol`

| Function | Contract refuses, in order | Client plan | Verdict |
|---|---|---|---|
| `claim` | `UnknownRound`, `ContractPaused`, `OutsideWindow` (`< start` or `> end`), empty → `NothingToClaim`; per id `ownerOf` (reverts unminted), `NotBearOwner`, `NothingToClaim`, `AlreadyClaimed` | same order and bounds; a duplicate id is `INVALID_ARGUMENT` before any read (the contract says `AlreadyClaimed`) | match; the duplicate differs in code only, refused either way |
| `setAmounts` | `onlyOwner`, `NotNextRound`, `LengthMismatch`, `InvalidTokenId` | `planLoad`: `DROP_NOT_NEXT_ROUND`; the list builder refuses ids outside 1–4,444; lengths equal by construction; the owner is left to the chain (`NOT_CONTRACT_OWNER`) | match |
| `openRound` | `onlyOwner`, `NotNextRound`, `EmptyRound`, `InvalidWindow`, `Unfunded` | same, plus every bear on chain must read the list (`DROP_LIST_MISMATCH`) | stricter by design: the contract cannot recompute `listHash` (I-2); the client closes that gap for its users |
| `closeRound` | `UnknownRound`, `RoundRunning` (`<= end`), `AlreadyClosed` | same | match; boundaries tested at `end` and `end + 1` |
| `withdraw` | `onlyOwner`, `ZeroAddress`, `Reserved` (`amount > balance` or `balance − amount < owed`) | `available = balance − owed`, `amount > available` | equivalent |

- **`listHash`:** `encodeAbiParameters([uint256[], uint256[]])` is `abi.encode(ids, amounts)`. The tests pin `OK_HASH` `0xc0cf…ed65` (the script's `01_ok.csv`) and round 1's `0x54e0…adba` (4,444 × 500), both from `BearDropList.s.sol`.
- **`planLoad`'s zeroing** matches `BearDropList._writes`: id order, a zero only where the round holds an amount and the list has none. It reads the 4,444 current amounts in five Multicall3 calls at one block.

## Error decoding

`BearDrop` shares `claim`, `withdraw` and `setPaused` with `PrizeVault`, along with seven error names (`ContractPaused`, `AlreadyClaimed`, `Reserved`, `Unfunded`, `ZeroAddress`, `InvalidWindow`, `InvalidTokenId`). The function-keyed map alone would show the vault's messages, for example "This prize has already been claimed." The fix:
- `REVERT_CODES_BY_CONTRACT.BearDrop`, looked up first under the key `BearDrop.<fn>` that `errorKey(call)` builds from the generated ABI's identity;
- `calls.ts` routes `simulate`, `execute` and `executePlan` through it.

Checked:
- every other contract's call still keys by function name: the CONTRACT_OF_ABI map holds `bearDropAbi` only;
- the test pins `"claim"` alone still reading `VAULT_PAUSED`;
- `allErrorsAbi` deduplicates by signature, so the new errors add selectors without shadowing.

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| F1 | Low | `planDropClaim` read the round, pause and time at one block, then the bears at a fresh block: a transfer or claim in between gave a plan built from two states | **fixed**: `lookupBears(…, at)` takes the plan's block |
| F2 | Low | `readDropState` with no block read the multicall and the $MNTD balance in two calls that could land on different blocks: `planDropWithdraw`'s `available` could mix them | **fixed**: one block, fetched first |
| F3 | Low | no cap on a claim's size. Measured on anvil: 600 bears cost 11.6M gas (about 19,400 a bear, 367k for one bear at the end of a 100-bear mint run because of ERC721A's ownership walk), so above about 1,600 bears the all-or-nothing claim exceeds the 32M limit and fails only at the wallet | **fixed**: `MAX_CLAIM_BATCH` = 1,000, `INVALID_ARGUMENT` above it, README; tested and planted |
| I1 | Info | `errorKey` recognises `BearDrop` by the generated ABI object. A caller who builds a `Call` with their own copy of the ABI gets function-keyed decoding (the vault's codes). Documented in `explainError`: pass `"BearDrop.claim"` | accepted |
| I2 | Info | `listHash()` sorts but does not validate; a list with a duplicate hashes to something the script would refuse. Its doc points to `buildDropList`, which validates | accepted |
| I3 | Info | Like DST-6's `check`, plans read at `latest` and the transaction lands later; the chain's own refusal is decoded under the same codes | inherent |

No Critical, High or Medium.

## Test coverage

- `test/bearDrop.test.ts`: 11 tests against anvil, with `BearDrop` and the OpenZeppelin $MNTD stand-in deployed from `../contracts/out`.
- `examples/11-bear-drop.test.ts`: one round end to end through the package name.
- The surface test places every `BearDrop` function.

**Planted breakages, each caught (17):**
- `listHash` unsorted;
- the load clearing nothing;
- the open skipping the per-bear check, the funding, or the 365-day cap;
- the claim skipping the owner or the claimed check;
- the claim window's end exclusive;
- the close allowed at `end`;
- the withdrawal ignoring `owed`;
- `live` ignoring the window;
- the list accepting 2^128;
- no BearDrop error scope;
- one load batch of 5,000;
- the claim cap removed.

**One survivor, removed rather than kept:** `planOpenRound`'s total check could not be reached against a real `BearDrop`. With all 4,444 bears read, the contract's own running total equals the list's.

## Blast radius

`errorKey` sits on every send in the library: 3 call sites in `calls.ts`. Its output differs from the old `call.functionName` only for a call whose ABI is `bearDropAbi`. The full suite, 155/155, passes unchanged for the other contracts.

## Confidence

High on parity and decoding: each refusal is exercised against the real contract on anvil. Not covered:
- Robinhood Chain's own RPC (the Multicall3 sizes, 3,000 sub-calls per `eth_call` in `lookup`, are proven on anvil only; the testnet run, 4.1, measures them);
- MINT's webapp, which is MINT's code.
