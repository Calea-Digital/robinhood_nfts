# @mintabear/contracts-client

The TypeScript client for the MintABear contracts on Robinhood Chain. It covers every call the
getminted.io play page makes (mint, whitelist claim, burn for a level, transfers, reads), the voucher backend's rules, event indexing, and the reference royalty split. Every write
returns what it did; every error has a code and a message you can show a holder.

The mystery box is tranche 2 and is not here yet.

**Spec v2.6.** The whitelist is off-chain, in MINT's backend (WL-8), and neither whitelist
registry is deployed. The `whitelist` claim calls, the voucher backend and `whitelistImport` below
describe those undeployed registries and are not delivered. The mint's allowlist proofs come from
MINT's final CSV (`buildAllowList(parseAllocationCsv(csv), stage)`). `mint.remainingWhitelistMints`
and `whitelist.allowList` still read a registry until `tasks.md` 6.2 gives them a CSV path.

## Quick start

```ts
import { createPublicClient, createWalletClient, custom, http, type Address } from "viem";
import { createMintABearClient, explainError, formatMntd, getDeployment, robinhoodChain } from "@mintabear/contracts-client";

// Two viem clients: one to read, one from the holder's wallet (here, Privy's embedded wallet).
const provider = await privyWallet.getEthereumProvider();
const mintabear = createMintABearClient({
  publicClient: createPublicClient({ chain: robinhoodChain, transport: http() }),
  walletClient: createWalletClient({ chain: robinhoodChain, transport: custom(provider), account: privyWallet.address as Address }),
  addresses: getDeployment(robinhoodChain.id),
  feeRecipient: OPENSEA_FEE_RECIPIENT,   // the fee recipient Studio allows for the drop
});

// Read: free, no wallet needed.
const bear = await mintabear.bears.get(7n);
if (bear.exists) console.log(`Level ${bear.level}; ${formatMntd(bear.costToMax)} $MNTD to level 5`);

// Write: plan, show, send.
const plan = await mintabear.bears.planBurn({ tokenId: 7n, targetLevel: 3 });
if (!plan.ok) {
  showError(plan.userMessage);                                // "This bear is already at level 5."
} else if (await confirm(`Burn ${formatMntd(plan.amount)} $MNTD?`, plan.warnings.map((w) => w.message))) {
  try {
    const { activated } = await mintabear.bears.executeBurn(plan);
    showSuccess(`Bear #7 is now level ${activated.newLevel}`);
  } catch (error) {
    const { code, userMessage } = explainError(error);
    if (code !== "USER_REJECTED") showError(userMessage);
  }
}
```

**The examples are the manual.** Each file in [`examples/`](examples) is one flow, written the way
the page would use it, with every step commented. They run in CI, so they stay correct:

| Example | Shows |
|---|---|
| [`01-getting-started`](examples/01-getting-started.test.ts) | creating the client before and after login; reads; units |
| [`02-public-mint`](examples/02-public-mint.test.ts) | minting in the public stage; the ids minted; a refusal's message |
| [`03-whitelist`](examples/03-whitelist.test.ts) | the backend's voucher endpoint; `claim`; the account's allocation number; an expired voucher; the whitelist-stage mint |
| [`04-burn`](examples/04-burn.test.ts) | plan → warnings → send; refusals; a script's one-call burn; batching for a smart wallet |
| [`05-transfer`](examples/05-transfer.test.ts) | the transfer warning; the reset; the self-transfer refusal |
| [`06-errors`](examples/06-errors.test.ts) | the `catch` pattern; a declined wallet prompt; no ETH for gas; the contract's own error; a plan interrupted halfway |
| [`07-indexing-and-split`](examples/07-indexing-and-split.test.ts) | typed events; the reference indexer; the royalty split |
| [`08-whitelist-import`](examples/08-whitelist-import.test.ts) | MINT's admin page with the owner-imported registry: CSV → plan → send; a correction; the freeze |

## The client

`createMintABearClient({ publicClient, walletClient?, addresses, feeRecipient?, countOpenListings?, deployBlock?, extraErrors? })`

Methods that take a `wallet` default to the connected one. Writes need `walletClient`; without it
they throw `NO_WALLET`.

| Group | Method | Returns |
|---|---|---|
| `mint` | `publicStage()` | price (wei per bear), window, per-wallet limit |
| | `public({ quantity, minter?, feeRecipient? })` | `{ tokenIds, hash, receipt, events }`; pays the current price |
| | `allowList({ quantity, mintParams, proof, … })` | `{ tokenIds, … }`; pass `allowList.entry(wallet)` |
| | `allowListMatchesChain(allowList)` | whether Studio set this list |
| | `stats(wallet?)` | `{ numberMinted, totalSupply, maxSupply }` |
| | `remainingWhitelistMints(wallet?)` | allocations minus every bear already minted to the wallet |
| `whitelist` | `campaign()` | `{ spotsLeft, openAt, closeAt, signer }` |
| | `isOpen()` | whether claims are accepted now |
| | `claimsOf(wallet?)`, `accountClaims(account)` | 0–2 |
| | `claimants()` | every claimant with its allocations |
| | `allowList(stage)` | the whitelist stage's allowlist: `root`, `entry(wallet)` |
| | `claim({ voucher, signature })` | `{ spotNumber, allocationIndex, … }` |
| `whitelistImport` | `state()` | `{ spotsLeft, closeAt, frozen, owner }` — owner-imported registry only (below) |
| | `parseCsv(text)` | the checked rows, or throws `IMPORT_INVALID_ROW` / `IMPORT_DUPLICATE_WALLET` / `IMPORT_OVER_TOTAL` |
| | `plan(rowsOrCsv, { batchSize?, removeUnlisted? })` | `{ ok: true, calls, add, remove, unlisted, unchanged, total }` or `{ ok: false, code, userMessage }` |
| | `execute(plan)` | one result per batch sent |
| | `add(rows)`, `remove(wallets)`, `setCloseAt(closeAt)` | the write's result (owner only) |
| | `matches(rows)` | whether the list on chain is exactly `rows` |
| `bears` | `get(tokenId)` | `{ exists: false }`, or owner, level, burns, weight, `costToMax` |
| | `level`, `costToReach`, `thresholds`, `weights`, `paused`, `snapshot` | the reads |
| | `planBurn({ tokenId, targetLevel })` | `{ ok: true, amount, calls, warnings }` or `{ ok: false, code, userMessage }` |
| | `executeBurn(plan)` | `{ results, activated: { previousLevel, newLevel, amount, cumulative } }` |
| | `burnTo({ tokenId, targetLevel })` | plan and send in one call (scripts; no warnings shown) |
| | `planTransfer({ to, tokenId })`, `executeTransfer(plan)` | `{ call, warnings }`; the write's result |
| `events` | `read(fromBlock?, toBlock?)`, `decode(logs)`, `index(toBlock?)` | typed events; a `ReferenceIndexer` |
| `split` | `rows({ closingBlock, mode? })`, `compute(rows, funding)`, `run({ closingBlock, funding, carriedIn?, mode? })` | the royalty split |
| `units` | `decimals()`, `formatMntd(amount)`, `parseMntd(text)` | $MNTD at the chain's decimals |

Every function the facade uses is exported as well (`planBurn`, `execute`, `readBear`,
`mintPublicCall`, …), each with TSDoc, for flows the facade does not cover.

### Types and units

- **`bigint`** for token ids, amounts and timestamps. $MNTD and ETH amounts are always in
  **base units** (wei; $MNTD's smallest unit), and timestamps are Unix seconds.
- **`number`** for small counts: levels (0–5), allocations (0–2), weights (basis 100: 100 … 200).
- Show $MNTD with `formatMntd(amount)`, and read what a holder types with `parseMntd(text)`.
  `3333n * 10n ** 18n` formats as `"3333"`.

### Wallets (Privy)

- **Any wallet works.** The library takes any viem `WalletClient`: Privy's provider through
  `custom(...)`, `@privy-io/wagmi`, or anything else. It depends on neither Privy nor wagmi.
  `robinhoodChain` and `robinhoodChainTestnet` are the chain objects Privy's `supportedChains`
  needs.
- **Smart wallets batch.** A Privy smart wallet can send a plan's calls as one user operation:
  `sendTransaction({ calls: plan.calls.map(toTransaction) })`.
- **The smart account is the wallet.** With a smart wallet, the smart account's address is the
  whitelist wallet, the allowlist minter and the bear owner. Holders never sign typed data, so
  ERC-1271 never comes up.

## Errors

Everything the library throws is a `MintABearError`:

| Field | What |
|---|---|
| `code` | stable, to branch on (the `ErrorCode` type) |
| `userMessage` | plain English for the holder; safe to show as is |
| `details` | the facts, by name: a revert's arguments (`{ total, allowed }`), a refusal's numbers |
| `cause` | the underlying error (viem's, the wallet's) |
| `message` | a technical line for logs: `burn reverted with NotBearOwner: [NOT_BEAR_OWNER] …` |

- `ContractRevertError` means a contract refused. It adds `functionName` and `revert.errorName`,
  the contract's own error name.
- `ClientRefusal` means the library refused before anything was sent.
- A plan's expected "no" is **returned**, not thrown, as `{ ok: false, code, userMessage }`, with
  the same codes.
- `executePlan` and `executeBurn` attach `completed` (the calls already mined) when a later step
  fails.

In a `catch`, `explainError(error)` gives `{ code, userMessage, details }` for anything thrown.
`isMintABearError(error, "OVERSHOOT")` narrows the type.

<!-- error-codes:begin (generated by scripts/error-table.ts) -->
| Code | Contract errors | Default `userMessage` |
|---|---|---|
| `MINT_NOT_ACTIVE` | `NotActive` | This mint stage is not open right now. |
| `MINT_ZERO_QUANTITY` | `MintQuantityCannotBeZero`, `MintZeroQuantity` | Choose at least one bear to mint. |
| `MINT_WALLET_LIMIT` | `MintQuantityExceedsMaxMintedPerWallet` | This wallet has reached its mint limit for this stage. |
| `MINT_EXCEEDS_SUPPLY` | `MintQuantityExceedsMaxSupply`, `ExceedsMaxBears` | There are not enough bears left to mint that many. |
| `MINT_EXCEEDS_STAGE_SUPPLY` | `MintQuantityExceedsMaxTokenSupplyForStage` | This stage does not have that many bears left. |
| `MINT_WRONG_PAYMENT` | `IncorrectPayment` | The payment did not match the mint price. Refresh the price and try again. |
| `NOT_ON_ALLOWLIST` | `InvalidProof` | This wallet is not on the whitelist for this stage, or the whitelist has changed. |
| `FEE_RECIPIENT_NOT_ALLOWED` | `FeeRecipientNotAllowed`, `FeeRecipientCannotBeZeroAddress` | The mint was sent with a fee recipient this drop does not accept. |
| `PAYER_NOT_ALLOWED` | `PayerNotAllowed` | This wallet is not allowed to mint on behalf of another wallet. |
| `TOKEN_DOES_NOT_EXIST` | `OwnerQueryForNonexistentToken`, `URIQueryForNonexistentToken`, `ApprovalQueryForNonexistentToken` | That bear has not been minted. |
| `NOT_TOKEN_OWNER_OR_APPROVED` | `TransferCallerNotOwnerNorApproved`, `TransferFromIncorrectOwner`, `ApprovalCallerNotOwnerNorApproved` | This wallet does not own that bear and is not approved to move it. |
| `BURN_DISABLED` | `BurnDisabled`, `TransferToZeroAddress` | Bears cannot be burned or sent to the zero address. |
| `RECEIVER_NOT_ERC721` | `TransferToNonERC721ReceiverImplementer` | The receiving contract cannot accept NFTs. |
| `SELF_TRANSFER` | — | Sending a bear to the wallet that already holds it moves nothing, but it resets the bear's level. |
| `CLAIM_WRONG_WALLET` | `NotClaimant` | This whitelist pass was issued for a different wallet. Connect the wallet you chose when claiming. |
| `VOUCHER_INVALID` | `BadSigner` | This whitelist pass is not valid. Request a new one. |
| `VOUCHER_EXPIRED` | `Expired` | This whitelist pass has expired. Request a new one. |
| `CAMPAIGN_CLOSED` | `CampaignClosed` | The whitelist campaign is not open. |
| `WHITELIST_SOLD_OUT` | `SoldOut` | All 1,000 whitelist spots have been claimed. |
| `WALLET_LIMIT` | `WalletLimit` | This wallet already holds two whitelist spots, the most one wallet can hold. |
| `ACCOUNT_LIMIT` | `AccountLimit` | This account has already claimed both of its whitelist spots. |
| `WRONG_ALLOCATION` | `WrongAllocation` | This whitelist pass is out of date: the account's spots changed since it was issued. Request a new one. |
| `NOT_YET_ELIGIBLE` | — | This account has not wagered enough yet for another whitelist spot. |
| `LIST_FROZEN` | `ListFrozen` | The whitelist is final: its close has passed, and nothing can be added, removed or moved. |
| `IMPORT_INVALID_ROW` | `ZeroWallet`, `ZeroCount` | A row of the whitelist import names the zero address or gives a count of zero. |
| `IMPORT_DUPLICATE_WALLET` | — | The whitelist file names undefined twice (lines undefined and undefined). Give each wallet one line with its total. |
| `IMPORT_OVER_TOTAL` | — | The whitelist would hold undefined allocations; at most 1000 are allowed. |
| `IMPORT_LENGTH_MISMATCH` | `LengthMismatch` | The import's wallets and counts differ in number. |
| `NOT_LISTED` | `NotListed` | A wallet to remove holds no whitelist allocations. |
| `INVALID_WINDOW` | `InvalidWindow` | That date is not allowed: a close cannot be in the past, and a window must open before it closes. |
| `ACTIVATION_PAUSED` | `ContractPaused` | Burning is not open yet. |
| `ZERO_AMOUNT` | `ZeroAmount` | Choose an amount of $MNTD above zero. |
| `NOT_BEAR_OWNER` | `NotBearOwner` | Only the bear's owner can do this, and this wallet does not own it. |
| `ALREADY_MAX_LEVEL` | `AlreadyAtMaxLevel` | This bear is already at level 5. |
| `TARGET_REACHED` | — | This bear has already reached that level. |
| `OVERSHOOT` | `Overshoot` | That is more $MNTD than this bear needs to reach level 5. Burn only what the next level costs. |
| `INVALID_LEVEL` | `InvalidLevel` | Levels run from 0 to 5. |
| `REENTRANCY` | `Reentrancy` | The burn was interrupted. Try again. |
| `INSUFFICIENT_MNTD_BALANCE` | `ERC20InsufficientBalance`, `InsufficientBalance` | This wallet does not hold enough $MNTD for this burn. |
| `INSUFFICIENT_MNTD_ALLOWANCE` | `ERC20InsufficientAllowance`, `InsufficientAllowance` | $MNTD has not been approved for this burn. Approve it, then burn. |
| `NOT_CONTRACT_OWNER` | `OnlyOwner`, `Unauthorized` | Only the contract's owner can do this. |
| `USER_REJECTED` | — | The request was cancelled in the wallet. |
| `INSUFFICIENT_GAS_FUNDS` | — | This wallet does not have enough ETH to pay the network fee. |
| `NO_WALLET` | — | Connect a wallet first. |
| `TRANSACTION_REVERTED` | — | The transaction failed on chain. |
| `INVALID_ARGUMENT` | — | An argument was out of range. |
| `EMPTY_ALLOWLIST` | — | The whitelist has no rows. |
| `WEAK_SERVER_KEY` | — | The server key must be at least 32 bytes. |
| `SPLIT_INVALID_INPUT` | — | The split's input rows are invalid. |
| `SPLIT_MISSING_BEARS` | — | The Transfer logs account for undefined bears but undefined exist at block undefined. Check fromBlock and the RPC's log range. |
| `SPLIT_GAS_BUDGET` | — | Reading bear #undefined alone does not fit the gas budget of undefined. |
| `UNKNOWN_DEPLOYMENT` | — | No MintABear deployment is recorded for chain undefined. |
| `UNKNOWN_REVERT` | — | The contract refused the transaction. |
| `UNKNOWN_ERROR` | — | Something went wrong. |
<!-- error-codes:end -->

Messages with numbers fill them in from `details`, as in "This wallet can mint at most 2 in this
stage…". Mint reverts: while `maxSupply` is 4,444, SeaDrop's `MintQuantityExceedsMaxSupply` fires
before the collection's `ExceedsMaxBears`.

## The voucher backend (`@mintabear/contracts-client/backend`, server-only)

The backend is MINT's code. This entry point is a reference implementation of its rules, and the
tests pin them. [`examples/03-whitelist`](examples/03-whitelist.test.ts) shows it as an endpoint.

1. **`account = accountHash(serverKey, { userId } | { email })`**: HMAC-SHA256, with a key of at
   least 32 bytes that never rotates, over the canonical id. An email is NFKC, trimmed and
   lower-cased; a system-issued user id (an internal id, a Privy user id) is compared exactly,
   since case-folding it could merge two accounts. `account` is an indexed topic of
   `WhitelistClaimed`: an unsalted hash of a guessable id would publicly tie wallets to casino
   accounts.
2. **`allocationIndex` comes from the chain**: it is `accountClaims(account) + 1`, not the wager
   tier. `planVoucher` does this, and returns a refusal (`NOT_YET_ELIGIBLE`, `WALLET_LIMIT`,
   `ACCOUNT_LIMIT`, `CAMPAIGN_CLOSED`, `WHITELIST_SOLD_OUT`) instead of a voucher when the claim
   would fail.
3. **Check `claimsOf(wallet) < 2`** before signing; `planVoucher` does.
4. **The signer is an EOA key** (`signVoucher` takes a viem `LocalAccount`; a Privy server wallet
   qualifies). The contract recovers with `ecrecover` only. Never rotate a key back in after
   `setSigner`: its unexpired vouchers would work again. `signVoucher` does not read the chain, so
   compare the key's address with `campaign().signer` at start-up.
5. **`deadline` is short.** It defaults to 10 minutes; the contract sets no cap.

## The owner-imported whitelist (`WhitelistImport`, WL-7)

MINT deploys one of two registries: `WhitelistClaim` (holders claim with vouchers, above) or
`WhitelistImport`, which MINT's admin fills from a CSV on its admin page. Point
`addresses.registry` at whichever is deployed. The reads the mint needs — `whitelist.claimsOf`,
`whitelist.claimants`, `whitelist.allowList`, `mint.remainingWhitelistMints` — work on both;
`whitelist.campaign`, `isOpen`, `accountClaims` and `claim` are `WhitelistClaim`'s only, and
`whitelistImport.*` is `WhitelistImport`'s only.

1. **The file** is `wallet,allocations` per line, with an optional header: each wallet once, 1 or
   2 allocations, at most 1,000 in all. `whitelistImport.parseCsv` refuses anything else with the
   line and the reason.
2. **The plan makes the chain equal the file.** `whitelistImport.plan(csv)` reads the list on
   chain and returns only the calls that close the difference, in batches of 200: removals
   first, then additions. A wallet already right is left alone. Wallets on chain that the file
   leaves out are reported in `unlisted` and kept, unless `{ removeUnlisted: true }`.
3. **Send it from the owner** with `whitelistImport.execute(plan)`. A batch that fails leaves the
   batches before it mined (`completed`); planning the same file again plans only the rest.
4. **`closeAt` freezes the list for good.** Until then the owner can add, remove and move the
   close (`setCloseAt`; the current time freezes it from the next second). After it every write
   reverts `ListFrozen` and `plan` refuses `LIST_FROZEN`. Check with `whitelistImport.matches(rows)`
   before the close, then export to Studio as for `WhitelistClaim`.

```ts
const admin = createMintABearClient({ publicClient, walletClient: adminWallet, addresses });
const plan = await admin.whitelistImport.plan(await file.text());
if (!plan.ok) return showError(plan.userMessage);
showSummary(plan.add.length, plan.remove.length, plan.unlisted.length);
await admin.whitelistImport.execute(plan);
```

[`examples/08-whitelist-import`](examples/08-whitelist-import.test.ts) runs it end to end.

## Events and indexing

- **Decode by emitter.** `events.read` and `events.decode` decode each log only with the ABI of
  the contract that emitted it. A burn transaction carries $MNTD's ERC-20 `Transfer(holder, 0x0,
  amount)`, whose topic is the collection's ERC-721 `Transfer`.
- **Typed events.** Check `emitter` and `eventName`, and `args` is typed.
- **`TransferNonceAdvanced(tokenId, nonce)` is the reset.** It fires on every transfer, never on
  mint, and precedes `Transfer` in the same transaction. The indexer voids the bear's level
  there.
- **`ReferenceIndexer` is the reference.** A test replays a long sequence of events and checks
  that its `levelOf` and owners equal the contracts'.

## Royalty split (reference)

`split.run({ closingBlock, funding, carriedIn? })`, or `bin/split.ts` from the command line:

- **Weights:** a wallet's weight is the sum of its bears' weights. Bears held by `0x…dEaD` are
  excluded; contract-held bears keep their weight.
- **Amounts:** each wallet gets `floor(distributable × weight / eligibleWeight)`, and the rest is
  `carried`, fewer base units than there are wallets. Allocations plus carried equal the funding
  exactly.
- **Inputs:** read at the closing block from an **archive node**. On Robinhood Chain that is the L2
  block number.
  - `mode: "events"` (the default) takes owners from `Transfer` logs and weights from `weightOf`. It
    refuses (`SPLIT_MISSING_BEARS`) unless the owners found equal `totalSupply`.
  - `mode: "snapshot"` reads `Activation.snapshot`, paged by a gas budget (default 30M), because its
    cost is quadratic over a long untransferred mint batch.

```shell
npx tsx bin/split.ts --rpc $ARCHIVE_RPC --bears $BEARS --activation $ACTIVATION \
  --from-block $DEPLOY_BLOCK --block $CLOSING_BLOCK --funding $AMOUNT [--carried-in $LAST] [--mode snapshot]
```

## Development

- **Location:** the package lives in `packages/contracts-client` of the contracts repository and
  moves unchanged into MINT's repository, `github.com/mintdotio/NFT` (CQ-14), beside
  `packages/contracts`; only `scripts/gen-abis.mjs` reads the Forge build at `../../out`.
- **Toolchain:** TypeScript (strict, ESM), with viem 2 as the only peer dependency. The ABIs in
  `src/abi/` are generated from the Forge build: `forge build` at the repository root, then
  `npm run gen:abi`. CI runs `npm run check:abi`.
- **Tests:** `npm test` runs vitest against anvil, with the contracts deployed from `out/`. Run
  `forge build` first; `anvil` must be on the path. `test/` is the verification suite and
  `examples/` the usage layer.
- **Generated README section:** `npm run docs:errors` regenerates the error-code table above, and
  a test fails when it is stale.
- **Dev-only dependencies:** `merkletreejs@0.2.32` and `ethers@5` exist only for the allowlist
  known-answer test. `npm audit` flags `crypto-js` under them. None ships in the package.
