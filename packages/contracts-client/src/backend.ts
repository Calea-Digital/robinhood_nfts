/**
 * Reference implementation of MINT's voucher backend (WL-3). **Server-side only**: import from
 * `@mintabear/contracts-client/backend`; the server key and the signer key must never reach a
 * browser.
 *
 * The backend is MINT's code; these helpers document its rules and the tests pin them.
 *
 * 1. `account` is a keyed hash of a canonical account id ({@link accountHash}). It is an indexed
 *    topic of `WhitelistClaimed`, so an unsalted hash of a guessable id would tie wallets to casino
 *    accounts in public; and a non-canonical id (email case, whitespace) would split one person
 *    into two accounts past the two-per-account cap.
 * 2. `allocationIndex` comes from the chain — `accountClaims(account) + 1` — not from the wager
 *    tier. The tier only says how many the account may hold; index 2 is issued once index 1 is
 *    claimed. Two vouchers for the same index sent to two wallets at once: the first claim wins,
 *    the second reverts `WRONG_ALLOCATION`.
 * 3. Check `claimsOf(wallet) < 2` before signing, or the claim reverts `WALLET_LIMIT`.
 * 4. The signer is an EOA key: the contract recovers with `ecrecover` only, so a contract signer's
 *    vouchers revert `VOUCHER_INVALID`. A key rotated out with `setSigner` is never rotated back in
 *    — its unexpired vouchers would work again.
 * 5. `deadline` is short (minutes). The contract sets no cap; the backend's promise is the cap.
 *
 * @example
 * ```ts
 * // POST /api/whitelist/voucher — after the wager API confirms the account's total
 * import { accountHash, planVoucher, signVoucher } from "@mintabear/contracts-client/backend";
 *
 * const account = await accountHash(SERVER_KEY, { userId: privyUser.id });
 * const plan = await planVoucher(publicClient, REGISTRY, { wallet, account, eligibleAllocations: wagered >= 100 ? 2 : wagered >= 50 ? 1 : 0 });
 * if (!plan.ok) return res.status(409).json({ code: plan.code, message: plan.userMessage });
 * const signature = await signVoucher(signerAccount, chainId, REGISTRY, plan.voucher);
 * return res.json({ voucher: plan.voucher, signature });
 * ```
 *
 * @module
 */
import type { Address, Hex, LocalAccount } from "viem";
import { bytesToHex, stringToBytes } from "viem";

import type { AnyPublicClient } from "./calls.js";
import { MAX_CLAIMS_PER_ACCOUNT, MAX_CLAIMS_PER_WALLET } from "./constants.js";
import { ClientRefusal, refusal, type Refusal } from "./errors.js";
import { campaignOpen, claimTypedData, readAccountClaims, readCampaign, readClaimsOf, type Voucher } from "./whitelist.js";

export type { Voucher } from "./whitelist.js";

/**
 * A getminted.io account, by the id the backend hashes. An `email` is something a person types,
 * so its case and spacing vary; a `userId` is an identifier the system issued (an internal user id,
 * a Privy user id), compared exactly — lower-casing it could merge two accounts. Which one MINT
 * uses is its choice; an immutable `userId` is the better input where there is one.
 */
export type AccountId = { email: string } | { userId: string };

/**
 * The canonical string an account id is hashed as. An email is Unicode NFKC, trimmed and
 * lower-cased, so `" Alice@Example.com"` and `"alice@example.com"` are one account; a user id is
 * trimmed only. A kind prefix keeps an email and a user id that spell the same from colliding.
 *
 * @param id - The account id and its kind.
 * @returns `"email:<canonical email>"` or `"user:<user id>"`.
 */
export function canonicalAccountId(id: AccountId): string {
  if ("email" in id) return `email:${id.email.normalize("NFKC").trim().toLowerCase()}`;
  return `user:${id.userId.trim()}`;
}

/**
 * The `account` of a voucher: HMAC-SHA256 under the server's key over the canonical account id.
 *
 * @param serverKey - At least 32 random bytes, kept server-side and **never rotated** (a new key
 *   makes every account new, past the cap).
 * @param id - The account id and its kind.
 * @returns A `bytes32` hex string.
 * @throws {ClientRefusal} `WEAK_SERVER_KEY` for a key shorter than 32 bytes.
 */
export async function accountHash(serverKey: Uint8Array, id: AccountId): Promise<Hex> {
  if (serverKey.length < 32) throw new ClientRefusal("WEAK_SERVER_KEY");
  const subtle = globalThis.crypto.subtle;
  const key = await subtle.importKey("raw", serverKey, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = await subtle.sign("HMAC", key, stringToBytes(canonicalAccountId(id)));
  return bytesToHex(new Uint8Array(mac));
}

/** Why no voucher can be issued now. The codes are the ones the claim itself would revert with. */
export type VoucherRefusalCode = "CAMPAIGN_CLOSED" | "WHITELIST_SOLD_OUT" | "WALLET_LIMIT" | "ACCOUNT_LIMIT" | "NOT_YET_ELIGIBLE";

/** Arguments of {@link planVoucher}. */
export interface PlanVoucherArgs {
  /** The wallet the holder chose to claim with. */
  wallet: Address;
  /** `accountHash(...)` of the holder's account. */
  account: Hex;
  /** Allocations the account's wagering entitles it to: 0, 1 (at $50) or 2 (at $100). */
  eligibleAllocations: number;
  /** The chain's current time, Unix seconds. Default: the latest block's timestamp. */
  now?: bigint;
  /** Voucher lifetime in seconds. Default 600 (10 minutes). */
  ttlSeconds?: bigint;
}

/**
 * Decides whether to sign, from the chain's state (rules 2 and 3): the next allocation index is
 * `accountClaims + 1`, the wallet must hold fewer than two, the window must be open with spots left,
 * and the account's wagering must reach the next index.
 *
 * @param client - Any viem public client on the chain.
 * @param registry - The registry's address.
 * @param args - Wallet, account, eligibility, and optionally the time and lifetime.
 * @returns `{ ok: true, voucher }` to sign, or a refusal with a `code` and a `userMessage` to return
 *   to the page.
 */
export async function planVoucher(
  client: AnyPublicClient,
  registry: Address,
  args: PlanVoucherArgs,
): Promise<{ ok: true; voucher: Voucher } | Refusal<VoucherRefusalCode>> {
  const [campaign, walletClaims, accountClaims, now] = await Promise.all([
    readCampaign(client, registry),
    readClaimsOf(client, registry, args.wallet),
    readAccountClaims(client, registry, args.account),
    args.now ?? client.getBlock().then((b) => b.timestamp),
  ]);
  if (campaign.spotsLeft === 0n) return refusal("WHITELIST_SOLD_OUT");
  if (!campaignOpen(campaign, now)) return refusal("CAMPAIGN_CLOSED");
  if (walletClaims >= MAX_CLAIMS_PER_WALLET) return refusal("WALLET_LIMIT");
  if (accountClaims >= MAX_CLAIMS_PER_ACCOUNT) return refusal("ACCOUNT_LIMIT");
  const allocationIndex = accountClaims + 1;
  if (allocationIndex > args.eligibleAllocations) return refusal("NOT_YET_ELIGIBLE", { allocationIndex });
  return {
    ok: true,
    voucher: { wallet: args.wallet, allocationIndex, account: args.account, deadline: now + (args.ttlSeconds ?? 600n) },
  };
}

/**
 * Signs `voucher` with the eligibility signer's key (rule 4: an EOA, so a viem `LocalAccount` —
 * `privateKeyToAccount`, or a Privy server wallet's account).
 *
 * This does not read the chain: compare `signer.address` with `readCampaign(...).signer` at start-up
 * and after any `setSigner`, or the vouchers revert `VOUCHER_INVALID`.
 *
 * @param signer - The eligibility signer.
 * @param chainId - The registry's chain.
 * @param registry - The registry's address.
 * @param voucher - From {@link planVoucher}.
 * @returns The signature the wallet passes to `claim`.
 */
export async function signVoucher(signer: LocalAccount, chainId: number, registry: Address, voucher: Voucher): Promise<Hex> {
  return signer.signTypedData(claimTypedData(chainId, registry, voucher));
}
