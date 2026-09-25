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

1. **`account = accountHash(serverKey, id)`**: HMAC-SHA256 over the canonical id (NFKC, trimmed,
   lower-cased), with a key of at least 32 bytes that never rotates. `account` is an indexed topic
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
