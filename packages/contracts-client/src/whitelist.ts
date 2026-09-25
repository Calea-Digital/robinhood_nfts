import type { Address, Chain, Hex, PublicClient, Transport } from "viem";

import { whitelistClaimAbi } from "./abi/index.js";
import type { AllowListRow } from "./allowlist.js";
import type { Call } from "./calls.js";

type Client = PublicClient<Transport, Chain | undefined>;

/**
 * A whitelist voucher (WL-3), as MINT's eligibility signer signs it.
 *
 * - `wallet` sends the claim itself (`NotClaimant` otherwise); for a smart wallet it is the smart
 *   account's address.
 * - `allocationIndex` is the **account's** allocation number — 1 once $50 is wagered, 2 once $100
 *   is — whichever wallet claims it, and must be the account's next (`accountClaims + 1`).
 * - `account` is a keyed hash of the getminted.io account id (`accountHash` in
 *   `@mintabear/contracts-client/backend`), never an unsalted hash.
 * - `deadline` is the last timestamp the voucher is accepted at; short, by the backend's promise.
 */
export interface Voucher {
  wallet: Address;
  allocationIndex: number;
  account: Hex;
  deadline: bigint;
}

/** The EIP-712 type, exactly `Claim(address wallet,uint8 allocationIndex,bytes32 account,uint256 deadline)`. */
export const claimTypes = {
  Claim: [
    { name: "wallet", type: "address" },
    { name: "allocationIndex", type: "uint8" },
    { name: "account", type: "bytes32" },
    { name: "deadline", type: "uint256" },
  ],
} as const;

/** The EIP-712 domain of a `WhitelistClaim` deployment: `WhitelistClaim` / `1` / chain id / registry. */
export function claimDomain(chainId: number, registry: Address) {
  return { name: "WhitelistClaim", version: "1", chainId, verifyingContract: registry } as const;
}

/** The full typed-data payload for viem's `signTypedData` and `hashTypedData`. */
export function claimTypedData(chainId: number, registry: Address, voucher: Voucher) {
  return {
    domain: claimDomain(chainId, registry),
    types: claimTypes,
    primaryType: "Claim",
    message: voucher,
  } as const;
}

/** `claim`'s reverts, in the order the contract checks them. */
export const CLAIM_REVERTS = [
  "NotClaimant",
  "BadSigner",
  "Expired",
  "CampaignClosed",
  "SoldOut",
  "WalletLimit",
  "AccountLimit",
  "WrongAllocation",
] as const;

/** `WhitelistClaim.claim(voucher, signature)`, sent by the voucher's wallet, which pays the gas. */
export function claimCall(registry: Address, voucher: Voucher, signature: Hex) {
  return {
    address: registry,
    abi: whitelistClaimAbi,
    functionName: "claim",
    args: [voucher, signature],
  } as const satisfies Call;
}

/** The campaign's live state: spots left of 1,000, the window, and the current signer. */
export async function readCampaign(client: Client, registry: Address) {
  const read = <F extends "spotsLeft" | "openAt" | "closeAt" | "signer">(functionName: F) =>
    client.readContract({ address: registry, abi: whitelistClaimAbi, functionName });
  const [spotsLeft, openAt, closeAt, signer] = await Promise.all([read("spotsLeft"), read("openAt"), read("closeAt"), read("signer")]);
  return { spotsLeft, openAt, closeAt, signer };
}

/** True while claims are accepted at `timestamp`: inside the window (inclusive) with spots left. */
export function campaignOpen(campaign: { spotsLeft: bigint; openAt: number; closeAt: number }, timestamp: bigint): boolean {
  return campaign.spotsLeft > 0n && timestamp >= BigInt(campaign.openAt) && timestamp <= BigInt(campaign.closeAt);
}

/** Allocations `wallet` holds (at most two). */
export async function readClaimsOf(client: Client, registry: Address, wallet: Address): Promise<number> {
  return client.readContract({ address: registry, abi: whitelistClaimAbi, functionName: "claimsOf", args: [wallet] });
}

/** Allocations the account has claimed across all its wallets (at most two). */
export async function readAccountClaims(client: Client, registry: Address, account: Hex): Promise<number> {
  return client.readContract({ address: registry, abi: whitelistClaimAbi, functionName: "accountClaims", args: [account] });
}

/**
 * Every claimant with its allocations, read page by page from `claimants(offset, limit)` — the rows
 * the Studio allowlist is built from (`buildAllowList`).
 */
export async function readClaimants(client: Client, registry: Address, pageSize = 200n): Promise<AllowListRow[]> {
  const rows: AllowListRow[] = [];
  for (let offset = 0n; ; offset += pageSize) {
    const page = await client.readContract({
      address: registry,
      abi: whitelistClaimAbi,
      functionName: "claimants",
      args: [offset, pageSize],
    });
    rows.push(...page.map((row) => ({ wallet: row.wallet, allocations: row.allocations })));
    if (BigInt(page.length) < pageSize) return rows;
  }
}
