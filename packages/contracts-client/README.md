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
