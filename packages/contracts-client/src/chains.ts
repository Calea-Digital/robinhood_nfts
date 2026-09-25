import { defineChain } from "viem";

/**
 * Robinhood Chain mainnet (chain id 4663), with the one RPC endpoint verified for this project
 * (`docs/HANDOVER.md`, "Verified on-chain facts"). Pass it to Privy's `supportedChains` and to
 * viem clients; replace `rpcUrls` with a provider of your own for production traffic.
 */
export const robinhoodChain = defineChain({
  id: 4663,
  name: "Robinhood Chain",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: ["https://rpc.mainnet.chain.robinhood.com"] } },
});

/** Robinhood Chain testnet (chain id 46630), where the rehearsal runs (OPS-4). */
export const robinhoodChainTestnet = defineChain({
  id: 46630,
  name: "Robinhood Chain Testnet",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: ["https://rpc.testnet.chain.robinhood.com"] } },
  testnet: true,
});
