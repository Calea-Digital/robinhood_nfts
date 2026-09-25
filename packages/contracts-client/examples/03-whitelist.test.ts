/**
 * Example 3 — the whitelist, from wager to mint.
 *
 * Two halves:
 *
 * - **MINT's backend** (server-side, `@mintabear/contracts-client/backend`): when the wager API says
 *   an account has reached $50 or $100, it hashes the account, plans a voucher from the chain's state
 *   and signs it.
 * - **The play page**: the holder's wallet sends the voucher with `whitelist.claim`.
 *
 * After the campaign closes, Studio loads the allowlist built from the claims, and each claimant
 * mints with `mint.allowList` using its entry.
 */
import { afterAll, beforeAll, expect, it } from "vitest";
import type { Address } from "viem";

import { createMintABearClient, explainError } from "@mintabear/contracts-client";
import { accountHash, planVoucher, signVoucher } from "@mintabear/contracts-client/backend";

import { localChain, type LocalChain } from "./setup.js";

let chain: LocalChain;
beforeAll(async () => {
  chain = await localChain();
});
afterAll(() => chain.stop());

/**
 * What the backend's `POST /api/whitelist/voucher` does, given the account, the wallet the holder
 * chose, and the dollars the wager API reports. Returns the JSON the page receives.
 */
async function voucherEndpoint(userId: string, wallet: Address, wageredUsd: number) {
  const account = await accountHash(chain.serverKey, { userId });
  const eligibleAllocations = wageredUsd >= 100 ? 2 : wageredUsd >= 50 ? 1 : 0;
  const plan = await planVoucher(chain.publicClient, chain.addresses.registry, { wallet, account, eligibleAllocations });
  if (!plan.ok) return { error: { code: plan.code, message: plan.userMessage } };
  const chainId = await chain.publicClient.getChainId();
  const signature = await signVoucher(chain.backendSigner, chainId, chain.addresses.registry, plan.voucher);
  return { voucher: plan.voucher, signature };
}

it("claims a spot with a voucher from the backend", async () => {
  /* Scenario:
     Given alice's account has wagered $60
     When the backend issues a voucher and her wallet claims it
     Then she holds spot 1 with allocation 1, and asking for a second voucher is refused as NOT_YET_ELIGIBLE */
  const mintabear = createMintABearClient({ publicClient: chain.publicClient, walletClient: chain.wallet("alice"), addresses: chain.addresses });

  // The page asks the backend for a voucher for the connected wallet.
  const response = await voucherEndpoint("privy-user-alice", chain.address("alice"), 60);
  if ("error" in response) throw new Error(response.error!.message);

  // The wallet sends it and pays the gas.
  const { spotNumber, allocationIndex } = await mintabear.whitelist.claim(response);
  expect(spotNumber).toBe(1n);
  expect(allocationIndex).toBe(1);
  expect((await mintabear.whitelist.campaign()).spotsLeft).toBe(999n);

  // At $60 the account has used its one allocation: the backend refuses with a message for the page.
  const again = await voucherEndpoint("privy-user-alice", chain.address("alice"), 60);
  expect(again).toEqual({ error: { code: "NOT_YET_ELIGIBLE", message: "This account has not wagered enough yet for another whitelist spot." } });
});

it("gives the second allocation to whichever wallet the account claims with", async () => {
  /* Scenario:
     Given alice's account reaches $100 and she claims its second allocation from her other wallet (bob's here)
     When that wallet claims
     Then it holds allocation number 2: the number belongs to the account, not the wallet */
  const response = await voucherEndpoint("privy-user-alice", chain.address("bob"), 100);
  if ("error" in response) throw new Error(response.error!.message);
  expect(response.voucher.allocationIndex).toBe(2);

  const fromOtherWallet = createMintABearClient({ publicClient: chain.publicClient, walletClient: chain.wallet("bob"), addresses: chain.addresses });
  expect((await fromOtherWallet.whitelist.claim(response)).allocationIndex).toBe(2);
});

it("explains a voucher that expired before it was sent", async () => {
  /* Scenario:
     Given carol received a voucher and waited past its ten-minute deadline
     When her wallet sends it
     Then the claim fails with VOUCHER_EXPIRED and a message telling her to request a new one */
  const response = await voucherEndpoint("privy-user-carol", chain.address("carol"), 50);
  if ("error" in response) throw new Error(response.error!.message);
  await chain.advance(601n);

  const mintabear = createMintABearClient({ publicClient: chain.publicClient, walletClient: chain.wallet("carol"), addresses: chain.addresses });
  try {
    await mintabear.whitelist.claim(response);
    expect.unreachable();
  } catch (error) {
    expect(explainError(error)).toMatchObject({ code: "VOUCHER_EXPIRED", userMessage: "This whitelist pass has expired. Request a new one." });
  }
});

it("mints in the whitelist stage with the wallet's entry from the allowlist", async () => {
  /* Scenario:
     Given the campaign's claims, and Studio's whitelist stage loaded with the allowlist built from them
     When alice mints her allocation with her entry
     Then she gets one bear and has no whitelist mints left; carol, with no spot, has no entry */
  const mintabear = createMintABearClient({
    publicClient: chain.publicClient,
    walletClient: chain.wallet("alice"),
    addresses: chain.addresses,
    feeRecipient: chain.feeRecipient,
  });

  // After the campaign has closed: the allowlist is the claimants under the stage exactly as Studio set it.
  await chain.advance(8n * 86_400n);
  expect(await mintabear.whitelist.isOpen()).toBe(false);
  const stage = await chain.studio.whitelistStage();
  const allowList = await mintabear.whitelist.allowList(stage);
  await chain.studio.loadAllowList(allowList.root); // Studio's step, from the exported CSV
  expect(await mintabear.mint.allowListMatchesChain(allowList)).toBe(true);

  // The page: find the wallet's entry; no entry means "not whitelisted".
  expect(allowList.entry(chain.address("carol"))).toBeUndefined();
  const entry = allowList.entry(chain.address("alice"))!;
  expect(await mintabear.mint.remainingWhitelistMints()).toBe(1n);

  const { tokenIds } = await mintabear.mint.allowList({ quantity: 1n, ...entry });
  expect(tokenIds).toHaveLength(1);
  expect(await mintabear.mint.remainingWhitelistMints()).toBe(0n);
});
