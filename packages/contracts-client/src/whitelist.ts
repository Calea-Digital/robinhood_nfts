/**
 * The whitelist claim (WL-3).
 *
 * MINT's backend signs a short-lived **voucher** once the wager API confirms a threshold; the
 * holder's wallet sends `claim(voucher, signature)` itself and pays the gas. 1,000 allocations,
 * two per wallet, two per getminted.io account, inside the campaign window. The backend half is
 * `@mintabear/contracts-client/backend`.
 *
 * @module
 */
import type { Address, Hex } from "viem";

import { whitelistClaimAbi } from "./abi/index.js";
import type { AllowListRow } from "./allowlist.js";
import type { AnyPublicClient, Call } from "./calls.js";

/**
 * A whitelist voucher, as the eligibility signer signs it.
 */
export interface Voucher {
  /** The wallet the allocation is for; it must send the claim itself (a smart wallet: the smart account). */
  wallet: Address;
  /** The **account's** allocation number — 1 once $50 is wagered, 2 once $100 is — whichever wallet claims it. */
  allocationIndex: number;
  /** The keyed hash of the getminted.io account id (`accountHash` in the backend entry point). */
  account: Hex;
  /** Last Unix second the voucher is accepted at; short (minutes). */
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

/**
 * The EIP-712 domain of a `WhitelistClaim` deployment.
 *
 * @param chainId - The chain the registry is on.
 * @param registry - The registry's address.
 * @returns `{ name: "WhitelistClaim", version: "1", chainId, verifyingContract: registry }`.
 */
export function claimDomain(chainId: number, registry: Address) {
  return { name: "WhitelistClaim", version: "1", chainId, verifyingContract: registry } as const;
}

/**
 * The full typed-data payload for viem's `signTypedData` and `hashTypedData`.
 *
 * @param chainId - The chain the registry is on.
 * @param registry - The registry's address.
 * @param voucher - The voucher to sign.
 */
export function claimTypedData(chainId: number, registry: Address, voucher: Voucher) {
  return {
    domain: claimDomain(chainId, registry),
    types: claimTypes,
    primaryType: "Claim",
    message: voucher,
  } as const;
}

/** `claim`'s contract errors, in the order the contract checks them. Each maps to a code in `REVERT_CODES`. */
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

/**
 * The `WhitelistClaim.claim` call, sent by the voucher's wallet.
 *
 * @param registry - The registry's address.
 * @param voucher - The voucher the backend returned.
 * @param signature - The backend's signature over it.
 *
 * @example
 * ```ts
 * const { voucher, signature } = await fetch("/api/whitelist/voucher").then((r) => r.json());
 * await execute(client, wallet, claimCall(addresses.registry, voucher, signature));
 * ```
 */
export function claimCall(registry: Address, voucher: Voucher, signature: Hex) {
  return {
    address: registry,
    abi: whitelistClaimAbi,
    functionName: "claim",
    args: [voucher, signature],
  } as const satisfies Call;
}

/** The campaign's live state. Times are Unix seconds, inclusive at both ends. */
export interface Campaign {
  /** Allocations still unclaimed, of 1,000 — the "spots left" counter. */
  spotsLeft: bigint;
  openAt: bigint;
  closeAt: bigint;
  /** The eligibility signer's address. */
  signer: Address;
}

/**
 * The campaign's live state.
 *
 * @param client - Any viem public client on the chain.
 * @param registry - The registry's address.
 */
export async function readCampaign(client: AnyPublicClient, registry: Address): Promise<Campaign> {
  const read = <F extends "spotsLeft" | "openAt" | "closeAt" | "signer">(functionName: F) =>
    client.readContract({ address: registry, abi: whitelistClaimAbi, functionName });
  const [spotsLeft, openAt, closeAt, signer] = await Promise.all([read("spotsLeft"), read("openAt"), read("closeAt"), read("signer")]);
  return { spotsLeft, openAt: BigInt(openAt), closeAt: BigInt(closeAt), signer };
}

/**
 * Whether claims are accepted at `timestamp`: inside the window with spots left.
 *
 * @param campaign - From {@link readCampaign}.
 * @param timestamp - Unix seconds (the latest block's, for the chain's view).
 */
export function campaignOpen(campaign: Pick<Campaign, "spotsLeft" | "openAt" | "closeAt">, timestamp: bigint): boolean {
  return campaign.spotsLeft > 0n && timestamp >= campaign.openAt && timestamp <= campaign.closeAt;
}

/**
 * Allocations `wallet` holds.
 *
 * @param client - Any viem public client on the chain.
 * @param registry - The registry's address.
 * @param wallet - The wallet.
 * @returns 0, 1 or 2.
 */
export async function readClaimsOf(client: AnyPublicClient, registry: Address, wallet: Address): Promise<number> {
  return client.readContract({ address: registry, abi: whitelistClaimAbi, functionName: "claimsOf", args: [wallet] });
}

/**
 * Allocations the account has claimed across all its wallets.
 *
 * @param client - Any viem public client on the chain.
 * @param registry - The registry's address.
 * @param account - The account hash.
 * @returns 0, 1 or 2.
 */
export async function readAccountClaims(client: AnyPublicClient, registry: Address, account: Hex): Promise<number> {
  return client.readContract({ address: registry, abi: whitelistClaimAbi, functionName: "accountClaims", args: [account] });
}

/**
 * Every claimant with its allocations, in order of first claim — the rows the Studio allowlist is
 * built from (`buildAllowList`).
 *
 * @param client - Any viem public client on the chain.
 * @param registry - The registry's address.
 * @param pageSize - Rows per `claimants(offset, limit)` call; default 200.
 */
export async function readClaimants(client: AnyPublicClient, registry: Address, pageSize = 200n): Promise<AllowListRow[]> {
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
