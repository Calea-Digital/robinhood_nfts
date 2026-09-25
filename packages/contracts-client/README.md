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
