# @mintabear/contracts-client

The typed TypeScript client for the MintABear contracts on Robinhood Chain (DEL-6): every call the
getminted.io play page makes to `MintABear`, `WhitelistClaim`, `Activation` and SeaDrop, the revert
reasons a caller handles, and the reference royalty split. The mystery box is tranche 2 and is not
here yet.

**Location is provisional.** The package lives in `packages/contracts-client` of the contracts
repository until CQ-14 settles which repository holds it; it has no dependency on its location
beyond `scripts/gen-abis.mjs` reading the Forge build at `../../out`.

## Toolchain

- TypeScript (strict, ESM), [viem](https://viem.sh) 2 as the only peer dependency.
- The ABIs in `src/abi/` are generated from the Forge build and checked in: `forge build` at the
  repository root, then `npm run gen:abi`. CI runs `npm run check:abi` and fails on any drift.
- Tests: vitest against anvil, with the contracts deployed from `out/` (`npm test`; needs
  `forge build` and `anvil` on the path).

## Wallets (Privy)

The library takes a viem `PublicClient` for reads and any viem `WalletClient` for writes, so it
works with whatever produces one — Privy included (`createWalletClient({ chain: robinhoodChain,
transport: custom(await wallet.getEthereumProvider()) })`, or `@privy-io/wagmi`). It depends on
neither. `robinhoodChain` and `robinhoodChainTestnet` are the chain objects Privy's
`supportedChains` needs.

**Dev-only dependencies.** `merkletreejs@0.2.32` and `ethers@5` exist only for the allowlist
known-answer test (the versions SeaDrop's reference tests use); `npm audit` flags `crypto-js`
under the old merkletreejs. None of them is a runtime dependency or reaches the built package.

## Calls and reverts

Every write is a builder returning a `Call` — `{ address, abi, functionName, args, value }` —
which `execute(publicClient, walletClient, call)` simulates, sends and waits for, and
`toTransaction(call)` turns into the raw `{ to, data, value }` a smart wallet batches. A revert,
in simulation or on chain, is thrown as `ContractRevertError`; switch on `error.revert.name`.
Reverts bubble through contracts unchanged, so the decoder knows the errors of all four contracts
(and OpenZeppelin v5's ERC-20 errors for $MNTD). `simulate(publicClient, account, call)` checks a
call without sending it.

## Mint (SeaDrop)

- `mintPublicCall(c, { feeRecipient, quantity, mintPrice, minter? })` — `SeaDrop.mintPublic`,
  paying `mintPrice × quantity`; `readPublicDrop(client, c)` gives the stage and its price.
- `mintAllowListCall(c, { feeRecipient, quantity, mintParams, proof, minter? })` —
  `SeaDrop.mintAllowList`. The whitelist stage is Studio's first stage open to non-team wallets
  (WL-4).
- `buildAllowList(rows, stage)` builds the tree exactly as `script/lib/AllowListTree.sol` and
  merkletreejs 0.2.32 (`hashLeaves`, `sortLeaves`, `sortPairs`) do: each row's leaf is
  `keccak256(abi.encode(wallet, MintParams))` with `maxTotalMintableByWallet` set to the row's
  allocations. `entry(wallet)` gives the `mintParams` and `proof`; `allowListMatchesChain` checks
  the root against the one Studio set. The rows are `WhitelistClaim.claimants`, the stage the exact
  values Studio configured — any difference changes every leaf.
- `readRemainingWhitelistMints(client, c, wallet, allocations)` is `allocations − numberMinted`:
  SeaDrop's per-wallet limit counts every mint to the wallet, a public one included.
- `c.seaDrop` defaults to canonical SeaDrop `0x00005EA0…4bf5`. A minter other than the payer
  needs the payer allowed by the collection (`PayerNotAllowed` otherwise).

| Revert | Meaning |
|---|---|
| `NotActive` | the stage has not started or has ended |
| `MintQuantityCannotBeZero` | quantity 0 |
| `MintQuantityExceedsMaxMintedPerWallet` | past the stage's per-wallet limit (for the whitelist, the row's allocations) |
| `MintQuantityExceedsMaxSupply` | past `maxSupply`; fires before `ExceedsMaxBears` while `maxSupply` is 4,444 |
| `MintQuantityExceedsMaxTokenSupplyForStage` | past the stage's supply |
| `IncorrectPayment` | value is not `mintPrice × quantity` |
| `InvalidProof` | the proof, the mint params or the minter do not match the root |
| `FeeRecipientNotAllowed` / `FeeRecipientCannotBeZeroAddress` | fee recipient not one Studio allows |
| `PayerNotAllowed` | minting for another address from a payer the collection has not allowed |
| `ExceedsMaxBears` | the collection's cap of 4,444, binding only if `maxSupply` is raised (COL-2) |

## Whitelist claim (WL-3)

The backend signs a short-lived voucher once the wager API confirms a threshold. The wallet
sends `claimCall(registry, voucher, signature)` itself and pays the gas.

- Reads: `readCampaign` (`spotsLeft` of 1,000, `openAt`, `closeAt`, `signer`), `campaignOpen`,
  `readClaimsOf(wallet)`, `readAccountClaims(account)`, and `readClaimants`, which pages through
  the rows the Studio allowlist is built from.
- The typed data is `claimTypedData(chainId, registry, voucher)`. The type is exactly
  `Claim(address wallet,uint8 allocationIndex,bytes32 account,uint256 deadline)` and the domain is
  `WhitelistClaim` / `1` / chain id / registry. A known-answer test pins the digest and the
  signature against values computed independently with Foundry's `cast`.
- `allocationIndex` is the **account's** allocation number (1 at $50, 2 at $100), whichever
  wallet claims it.
- For a smart wallet, `voucher.wallet` is the smart account's address, because that address
  sends the claim. Holders never sign typed data, so ERC-1271 never applies.

| Revert (check order) | Meaning |
|---|---|
| `NotClaimant` | the sender is not `voucher.wallet` |
| `BadSigner` | not signed by the current signer, or the signer is a contract |
| `Expired` | past `voucher.deadline` |
| `CampaignClosed` | outside `openAt`..`closeAt` |
| `SoldOut` | all 1,000 allocations are claimed |
| `WalletLimit` | the wallet already holds two |
| `AccountLimit` | the account already holds two |
| `WrongAllocation` | `allocationIndex` is not `accountClaims(account) + 1` |

### The backend's rules (`@mintabear/contracts-client/backend`)

The backend is MINT's code. This entry point is a reference implementation of its rules, and the
tests pin them. It is server-only.

1. **`account = accountHash(serverKey, { userId } | { email })`**: HMAC-SHA256, with a key of at
   least 32 bytes that never rotates, over the canonical id. An email is NFKC, trimmed and
   lower-cased; a system-issued user id (an internal id, a Privy user id) is compared exactly, since
   case-folding it could merge two accounts. Prefer an immutable user id where there is one. `account` is an indexed topic
   of `WhitelistClaimed`: an unsalted hash of a low-entropy id would publicly tie wallets to casino
   accounts, and a non-canonical id (email case, whitespace) would split one person into two
   accounts past the cap.
2. **`allocationIndex` comes from the chain**: it is `accountClaims(account) + 1`, not the wager
   tier. Index 2 is issued only once index 1 is claimed. `planVoucher` does this, and answers
   `NotYetEligible`, `WalletLimit`, `AccountLimit`, `CampaignClosed` or `SoldOut` instead of a
   voucher when one can't be claimed.
3. **Check `claimsOf(wallet) < 2`** before signing.
4. **The signer is an EOA key** (`signVoucher` takes a viem `LocalAccount`; a Privy server wallet
   qualifies). The contract recovers with `ecrecover` only. A key rotated out with `setSigner` is
   never rotated back in: a test shows its unexpired vouchers working again when it is.
5. **`deadline` is short.** `planVoucher` defaults to 10 minutes; the contract sets no cap.

`signVoucher` does not read the chain. Compare the signing key's address with
`readCampaign(...).signer` at start-up and after any `setSigner`: a key that is no longer the
signer produces vouchers that revert `BadSigner`.

## Burn (ACT-4, ACT-7, ACT-8)

To burn: approve **`Activation`** on $MNTD, then call `burn(tokenId, amount)` from the bear's
owner, with the amount from `costToReach(tokenId, targetLevel)`.

- `planBurn(client, { activation, bears, mntd }, { tokenId, owner, targetLevel, countOpenListings? })`
  sizes the burn and checks it the way `burn` will. It returns `{ ok: false, reason }` for
  `NonexistentToken`, `ContractPaused`, `NotBearOwner`, `AlreadyAtMaxLevel`, `TargetReached` or
  `InsufficientBalance`. Otherwise it returns the calls, `[approve?, burn]`: approve is included
  only when the allowance is short, and it approves exactly the amount.
- Its warnings:
  - `OPEN_LISTINGS`: the bear has open listings. A listing filled after the burn costs the seller
    the $MNTD and gives the buyer level 0, so offer to cancel them first. The library has no
    marketplace client; pass `countOpenListings`, backed by OpenSea's API.
  - `NOT_LINKED`: the burner's wallet doesn't link this bear, so its Status gains nothing until it
    does, level 5 included.
- Anything above the level-5 remainder is refused (`Overshoot`), so nothing is destroyed for
  nothing. `planBurn`'s amount is exactly `costToReach`, so it can never overshoot.
- A burn is always the caller's own $MNTD, for a bear the caller owns. For a smart wallet, that
  caller is the smart account.

| Revert (check order) | Meaning |
|---|---|
| `ContractPaused` | burning has not opened yet, or is suspended |
| `ZeroAmount` | amount 0 |
| `NotBearOwner` | the sender does not own the bear |
| `AlreadyAtMaxLevel` | the bear is at level 5 |
| `Overshoot` | amount above `costToReach(tokenId, 5)` |
| `OwnerQueryForNonexistentToken` | the id was never minted (from the collection, before `NotBearOwner`); `linkBear` too |
| the token's own | allowance or balance short, from `burnFrom` (OpenZeppelin v5 `ERC20InsufficientAllowance` / `ERC20InsufficientBalance`, or a v4 string); the record is undone with it |
| `Reentrancy` | never in normal use |

## Status link (ACT-9)

- `linkCall(a, tokenId)` and `unlinkCall(a)`. `unlinkBear` is a silent no-op when there is no
  link, and works while paused.
- A new `linkBear` replaces the wallet's earlier link without a `BearUnlinked` for the old bear.
- `readLink(client, a, wallet)` returns the bear carrying the wallet's boost and its level, or
  `tokenId` 0 once that bear has moved.
- `readLinkStatus(client, a, wallet, fromBlock)` separates `none` from `voided`, where the last
  link's bear was sold. Show a voided link to the seller. It reads the wallet's link events in one
  `eth_getLogs` from `fromBlock`; on an RPC that caps log ranges, serve it from an indexer instead.
- `linkPrompt(client, a, wallet, tokenId)`: prompt after a purchase and after a holder's first
  burn. A wallet has no Status boost until it links, level 5 included.
- **One link per wallet.** How several wallets' links combine for one getminted.io account is
  MINT's Status service's rule (CQ-21, open). The library reads each wallet on its own and
  encodes no answer.

## Transfers

Every transfer resets the bear's level and voids any link to it. That includes a self-transfer
and an approved operator's transfer (COL-3, ACT-5).

- `planTransfer(client, a, { from, to, tokenId, safe? })` throws `ClientRefusal` for
  `SELF_TRANSFER` (`from == to`: nothing moves, but the bear resets) and for `ZERO_ADDRESS`.
  Otherwise it returns the call, with `RESETS_LEVEL` (the level and $MNTD lost) and `VOIDS_LINK`
  warnings to confirm.
- Sent anyway, a transfer to the zero address reverts `BurnDisabled` from `transferFrom` and
  `safeTransferFrom` alike.
- An operator's transfer passes only if the transfer validator allows that operator. The
  validator's own error comes through.

## Reads (COL-12, ACT-14)

`readLevel`, `readCumulative`, `readLifetimeBurned`, `readWeight`, `readWeightFor`,
`readThreshold`, `readCostToReach`, `readLink`, `readSnapshot`, `readPaused`,
`readTransferNonce`, `readExists`, `readOwner`, and `readBear`, which reads them all for one bear.
Reads are free, so poll them.

An id that was never minted answers `weightOf` 100 and `snapshot` zeroes, and `ownerOf`
reverts. Check `exists` first.

## Events and indexing

- `decodeSystemLogs(logs, { bears, activation, registry?, mntd? })` and `readSystemEvents(client,
  addresses, fromBlock)` decode **by emitter**. The collection's ERC-721 `Transfer` and $MNTD's
  ERC-20 `Transfer` share one topic, and a burn transaction carries $MNTD's `Transfer(holder, 0x0,
  amount)` (and its `Approval`) beside `BearActivated`. Decoded by topic alone, that would read as
  a bear sent to the zero address.
- `TransferNonceAdvanced(tokenId, nonce)` is the reset. It fires on every transfer, never on mint,
  and precedes the collection's `Transfer` in the same transaction's logs. The indexer voids the
  bear's level and every wallet's link to it there.
- A new `BearLinked(wallet, tokenId)` replaces the wallet's earlier link without a `BearUnlinked`
  for the old bear. A later `BearUnlinked` for a link voided by a reset changes nothing.
- `BearActivated(tokenId, burner, previousLevel, newLevel, amount, cumulative)` carries no `ref`.
- `ReferenceIndexer` is the reference reducer. A test replays every event of a sequence of burns,
  sales, a self-transfer, a voided unlink, relinks and a buy-back, and checks that its `levelOf`
  and `linkOf` equal the contracts' for every bear and wallet.

## Royalty split (reference)

`computeSplit(rows, funding, { carriedIn? })` computes the split, and `bin/split.ts` runs it
against a node.

- **Weights:** a wallet's weight is the sum of its bears' weights (basis 100). The eligible total
  excludes bears held by `0x000000000000000000000000000000000000dEaD`. Contract-held bears keep
  their weight; whether to pay a contract is MINT's policy.
- **Amounts:** each wallet gets `floor(distributable × weight / eligibleWeight)`, where
  `distributable = funding + carriedIn`. `carried = distributable − Σ allocations` is always fewer
  base units than there are wallets. Allocations plus carried equal the funding exactly, and a
  fixture test pins the numbers.
- **Rows:** ids exactly 1..4,444, each once, each with an owner. `computeSplit` throws on a
  duplicate, an out-of-range id or an ownerless row.

The inputs come from an **archive node** at the closing block. On Robinhood Chain that is the L2
block number; `block.number` inside a contract reads L1. There are two modes, and a test on anvil
shows they agree:

- **`rowsFromEvents`** (default): owners from the collection's indexed `Transfer` events up to the
  closing block, and weights from `weightOf` at that block. There is no owner walk, so the cost is
  flat. It reads `weightOf` only for ids that have an owner. `weightOf` answers 100 for an id never
  minted, so before sell-out a sum over the whole range would count phantom bears.
- **`rowsFromSnapshot`**: `Activation.snapshot` over 1..4,444, paged by a **gas budget** (default
  30M). Each page is estimated first and halved until it fits. `snapshot` walks `ownerOf` back to
  the start of an untransferred mint batch, so its cost is quadratic in such a batch: 56.2M gas for
  the full range at two bears per wallet, and more for long batches. A single full-range call is
  not dependable. Ids with no owner are dropped.

```shell
npx tsx bin/split.ts --rpc $ARCHIVE_RPC --bears $BEARS --activation $ACTIVATION \
  --from-block $COLLECTION_DEPLOY_BLOCK --block $CLOSING_BLOCK --funding $AMOUNT \
  [--carried-in $LAST_CARRIED] [--mode events|snapshot] [--gas-budget 30000000] [--block-range 10000]
```

It prints JSON with amounts as decimal strings, and sends nothing.

## Not here yet

The mystery box (`MysteryBox`, `PrizeDraw`, `PrizeVault`: opens and prize claims on each chain)
is tranche 2. Its calls will join this package as `src/mysteryBox.ts` with their own tests. Nothing
in the tranche-1 modules depends on it.
