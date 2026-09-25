/**
 * Example 2 — minting in the public stage.
 *
 * `mint.public` reads the stage's price, sends SeaDrop's `mintPublic` with exactly that payment,
 * and returns the ids minted. A refusal comes back as a `MintABearError` whose `userMessage` can be
 * shown as it is.
 */
import { afterAll, beforeAll, expect, it } from "vitest";
import { parseEther } from "viem";

import { createMintABearClient, explainError } from "@mintabear/contracts-client";

import { localChain, type LocalChain } from "./setup.js";

let chain: LocalChain;
beforeAll(async () => {
  chain = await localChain();
  await chain.studio.openPublicStage(parseEther("0.001"), 2); // 0.001 ETH each, two per wallet
});
afterAll(() => chain.stop());

it("mints and reports the ids", async () => {
  /* Scenario:
     Given an open public stage at 0.001 ETH, two per wallet
     When alice mints two
     Then she gets bears 1 and 2, and her mint count reads two */
  const mintabear = createMintABearClient({
    publicClient: chain.publicClient,
    walletClient: chain.wallet("alice"),
    addresses: chain.addresses,
    feeRecipient: chain.feeRecipient,
  });

  // Show the price before the button: wei per bear.
  const stage = await mintabear.mint.publicStage();
  expect(stage.mintPrice).toBe(parseEther("0.001"));

  // Mint. The payment is `mintPrice × quantity`, read at the moment of the call.
  const { tokenIds, hash } = await mintabear.mint.public({ quantity: 2n });
  expect(tokenIds).toEqual([1n, 2n]);
  expect(hash).toMatch(/^0x/);

  // Her count and the supply, for "minted 2 / 4,444".
  expect(await mintabear.mint.stats()).toEqual({ numberMinted: 2n, totalSupply: 2n, maxSupply: 4444n });
});

it("shows the holder why a mint was refused", async () => {
  /* Scenario:
     Given alice has minted her two
     When she tries to mint a third
     Then the error's code is MINT_WALLET_LIMIT and its userMessage names the limit */
  const mintabear = createMintABearClient({
    publicClient: chain.publicClient,
    walletClient: chain.wallet("alice"),
    addresses: chain.addresses,
    feeRecipient: chain.feeRecipient,
  });

  try {
    await mintabear.mint.public({ quantity: 1n });
    expect.unreachable();
  } catch (error) {
    // The one call a catch needs: a stable code to branch on, and text to show.
    const { code, userMessage, details } = explainError(error);
    expect(code).toBe("MINT_WALLET_LIMIT");
    expect(userMessage).toBe("This wallet can mint at most 2 in this stage, and it has reached that limit.");
    expect(details).toEqual({ total: 3n, allowed: 2n }); // the contract error's arguments, by name
  }
});
