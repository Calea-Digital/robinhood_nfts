/**
 * Example 6 — handling errors.
 *
 * Everything the library throws is a `MintABearError`: `code` to branch on, `userMessage` to show,
 * `details` for the numbers, `cause` for the underlying error. In a `catch`, call
 * `explainError(error)` — it turns anything (the library's errors, viem's, a wallet's) into a code
 * and a message:
 *
 * ```ts
 * try {
 *   await mintabear.bears.executeBurn(plan);
 * } catch (error) {
 *   const { code, userMessage } = explainError(error);
 *   if (code === "USER_REJECTED") return;     // they closed the wallet prompt: say nothing
 *   toast.error(userMessage);
 * }
 * ```
 *
 * The codes are listed in the README ("Error codes") and in the `ErrorCode` type.
 */
import { afterAll, beforeAll, expect, it } from "vitest";
import { createPublicClient, createWalletClient, custom, http } from "viem";
import { foundry } from "viem/chains";
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";

import { ContractRevertError, createMintABearClient, explainError, isMintABearError, MintABearError, type MintABearClient } from "@mintabear/contracts-client";

import { localChain, type LocalChain } from "./setup.js";

let chain: LocalChain;
let alice: MintABearClient;
beforeAll(async () => {
  chain = await localChain();
  await chain.studio.openPublicStage(0n);
  alice = createMintABearClient({ publicClient: chain.publicClient, walletClient: chain.wallet("alice"), addresses: chain.addresses, feeRecipient: chain.feeRecipient });
  await alice.mint.public({ quantity: 1n }); // bear 1
  await chain.faucet("alice", 10_000n);
});
afterAll(() => chain.stop());

it("tells a declined wallet prompt apart from a failure", async () => {
  /* Scenario:
     Given a wallet whose holder closes the signing prompt (the provider answers EIP-1193 code 4001, as Privy does)
     When the page links a bear through it
     Then the error's code is USER_REJECTED, so the page can stay quiet */
  const node = createPublicClient({ chain: foundry, transport: http(chain.rpcUrl) });
  const declining = createWalletClient({
    chain: foundry,
    account: chain.address("alice"),
    transport: custom({
      async request({ method, params }) {
        if (method === "eth_sendTransaction") throw Object.assign(new Error("User rejected the request."), { code: 4001 });
        return node.request({ method, params } as never);
      },
    }),
  });
  const mintabear = createMintABearClient({ publicClient: chain.publicClient, walletClient: declining, addresses: chain.addresses });

  try {
    await mintabear.bears.link(1n);
    expect.unreachable();
  } catch (error) {
    expect(explainError(error)).toMatchObject({ code: "USER_REJECTED", userMessage: "The request was cancelled in the wallet." });
  }
});

it("explains a wallet with no ETH for the network fee", async () => {
  /* Scenario:
     Given a new wallet holding no ETH
     When it tries to mint
     Then the error's code is INSUFFICIENT_GAS_FUNDS with a message saying so */
  const empty = createWalletClient({ chain: foundry, transport: http(chain.rpcUrl), account: privateKeyToAccount(generatePrivateKey()) });
  const mintabear = createMintABearClient({ publicClient: chain.publicClient, walletClient: empty, addresses: chain.addresses, feeRecipient: chain.feeRecipient });

  try {
    await mintabear.mint.public({ quantity: 1n });
    expect.unreachable();
  } catch (error) {
    expect(explainError(error)).toMatchObject({ code: "INSUFFICIENT_GAS_FUNDS", userMessage: "This wallet does not have enough ETH to pay the network fee." });
  }
});

it("gives developers the contract's own error beside the message", async () => {
  /* Scenario:
     Given bear 1, which bob does not own
     When bob links it
     Then the error is a ContractRevertError: code NOT_BEAR_OWNER for the page, revert.errorName "NotBearOwner" and functionName "linkBear" for the logs */
  const bob = createMintABearClient({ publicClient: chain.publicClient, walletClient: chain.wallet("bob"), addresses: chain.addresses });
  try {
    await bob.bears.link(1n);
    expect.unreachable();
  } catch (error) {
    // Narrow with instanceof (or isMintABearError) to reach the typed fields.
    expect(error).toBeInstanceOf(ContractRevertError);
    if (!(error instanceof ContractRevertError)) throw error;
    expect(error.code).toBe("NOT_BEAR_OWNER");
    expect(error.userMessage).toBe("Only the bear's owner can do this, and this wallet does not own it.");
    expect(error.revert.errorName).toBe("NotBearOwner");
    expect(error.functionName).toBe("linkBear");
    expect(error.message).toBe("linkBear reverted with NotBearOwner: [NOT_BEAR_OWNER] Only the bear's owner can do this, and this wallet does not own it.");
  }
});

it("reports how far a plan got when a later step fails", async () => {
  /* Scenario:
     Given a burn plan of approve then burn, and burning paused by the admin after the plan was made
     When the plan is sent
     Then the error is ACTIVATION_PAUSED and its completed list holds the approve that was mined, so a retry can skip it */
  const plan = await alice.bears.planBurn({ tokenId: 1n, targetLevel: 1 });
  if (!plan.ok) throw new Error(plan.userMessage);
  expect(plan.calls).toHaveLength(2);
  await chain.admin.pauseActivation(true);

  try {
    await alice.bears.executeBurn(plan);
    expect.unreachable();
  } catch (error) {
    expect(isMintABearError(error, "ACTIVATION_PAUSED")).toBe(true);
    expect((error as MintABearError).userMessage).toBe("Burning and Status linking are not open yet.");
    expect((error as MintABearError).completed?.map((r) => r.receipt.status)).toEqual(["success"]); // the approve
  }

  // After the pause lifts, a fresh plan sees the allowance already in place: one call, the burn.
  await chain.admin.pauseActivation(false);
  const retry = await alice.bears.planBurn({ tokenId: 1n, targetLevel: 1 });
  expect(retry.ok && retry.calls.map((c) => c.functionName)).toEqual(["burn"]);
});
