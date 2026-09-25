/**
 * Reference implementation of MINT's voucher backend (WL-3). The backend is MINT's code; these
 * helpers document its rules and the tests pin them. Import from
 * `@mintabear/contracts-client/backend` — nothing here belongs in the browser, and the server key
 * must never reach it.
 *
 * The rules:
 *
 * 1. `account` is a keyed hash of a canonical account id (`accountHash`). It is an indexed topic of
 *    `WhitelistClaimed`, so an unsalted hash of a guessable id would tie wallets to casino accounts
 *    in public; and a non-canonical id (email case, whitespace) would split one person into two
 *    accounts past the two-per-account cap.
 * 2. `allocationIndex` comes from the chain — `accountClaims(account) + 1` — not from the wager
 *    tier. The tier only says how many the account may hold; index 2 is issued once index 1 is
 *    claimed. Two vouchers for the same index sent to two wallets at once: the first claim wins,
 *    the second reverts `WrongAllocation`.
 * 3. Check `claimsOf(wallet) < 2` before signing, or the claim reverts `WalletLimit`.
 * 4. The signer is an EOA key: the contract recovers with `ecrecover` only, so a contract signer's
 *    vouchers revert `BadSigner`. A key rotated out with `setSigner` is never rotated back in — its
 *    unexpired vouchers would work again.
 * 5. `deadline` is short (minutes). The contract sets no cap; the backend's promise is the cap.
 */
import type { Address, Chain, Hex, LocalAccount, PublicClient, Transport } from "viem";
import { bytesToHex, stringToBytes } from "viem";

import { MAX_CLAIMS_PER_ACCOUNT, MAX_CLAIMS_PER_WALLET } from "./constants.js";
import { campaignOpen, claimTypedData, readAccountClaims, readCampaign, readClaimsOf, type Voucher } from "./whitelist.js";

type Client = PublicClient<Transport, Chain | undefined>;

/**
 * The canonical form of an account id that a person can type differently: Unicode NFKC, trimmed,
 * lower-cased — so `" Alice@Example.com"` and `"alice@example.com"` are one account. An immutable
 * internal user id, where MINT has one, is a better input than an email; which id MINT uses is its
 * choice.
 */
export function canonicalAccountId(id: string): string {
  return id.normalize("NFKC").trim().toLowerCase();
}

/**
 * `account` for a voucher: HMAC-SHA256 under the server's key over the canonical account id. The
 * key is at least 32 random bytes, kept server-side and never rotated (a new key makes every
 * account new, past the cap).
 */
export async function accountHash(serverKey: Uint8Array, accountId: string): Promise<Hex> {
  if (serverKey.length < 32) throw new Error("accountHash: the server key must be at least 32 bytes");
  const subtle = globalThis.crypto.subtle;
  const key = await subtle.importKey("raw", serverKey, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = await subtle.sign("HMAC", key, stringToBytes(canonicalAccountId(accountId)));
  return bytesToHex(new Uint8Array(mac));
}

/** Why no voucher can be issued now. */
export type VoucherRefusal = "CampaignClosed" | "SoldOut" | "WalletLimit" | "AccountLimit" | "NotYetEligible";

export interface PlanVoucherArgs {
  wallet: Address;
  account: Hex;
  /** Allocations the account's wagering entitles it to: 0, 1 (at $50) or 2 (at $100). */
  eligibleAllocations: number;
  /** The chain's current timestamp (seconds). */
  now: bigint;
  /** Voucher lifetime in seconds; short. Default 10 minutes. */
  ttlSeconds?: bigint;
}

/**
 * Decides whether to sign, from the chain's state: the next allocation index is
 * `accountClaims + 1`, the wallet must hold fewer than two, the window must be open with spots
 * left, and the account's wagering must reach the next index.
 */
export async function planVoucher(
  client: Client,
  registry: Address,
  a: PlanVoucherArgs,
): Promise<{ ok: true; voucher: Voucher } | { ok: false; reason: VoucherRefusal }> {
  const [campaign, walletClaims, accountClaims] = await Promise.all([
    readCampaign(client, registry),
    readClaimsOf(client, registry, a.wallet),
    readAccountClaims(client, registry, a.account),
  ]);
  if (campaign.spotsLeft === 0n) return { ok: false, reason: "SoldOut" };
  if (!campaignOpen(campaign, a.now)) return { ok: false, reason: "CampaignClosed" };
  if (walletClaims >= MAX_CLAIMS_PER_WALLET) return { ok: false, reason: "WalletLimit" };
  if (accountClaims >= MAX_CLAIMS_PER_ACCOUNT) return { ok: false, reason: "AccountLimit" };
  const allocationIndex = accountClaims + 1;
  if (allocationIndex > a.eligibleAllocations) return { ok: false, reason: "NotYetEligible" };
  return {
    ok: true,
    voucher: { wallet: a.wallet, allocationIndex, account: a.account, deadline: a.now + (a.ttlSeconds ?? 600n) },
  };
}

/** Signs `voucher` with the eligibility signer's key. A `LocalAccount` only: the signer is an EOA. */
export async function signVoucher(signer: LocalAccount, chainId: number, registry: Address, voucher: Voucher): Promise<Hex> {
  return signer.signTypedData(claimTypedData(chainId, registry, voucher));
}
