/**
 * Example 1 — creating the client, and reading.
 *
 * `createMintABearClient` is the one object the play page needs. Give it a public client (reads)
 * and, once the holder has connected, a wallet client (writes). Reads cost nothing and need no
 * wallet; poll them.
 */
import { afterAll, beforeAll, expect, it } from "vitest";

import { createMintABearClient, formatMntd, isMintABearError } from "@mintabear/contracts-client";

import { localChain, type LocalChain } from "./setup.js";

let chain: LocalChain;
beforeAll(async () => {
  chain = await localChain();
});
afterAll(() => chain.stop());

it("creates a read-only client before the holder connects", async () => {
  /* Scenario:
     Given the page has loaded but no wallet is connected
     When it creates the client with a public client only and reads
     Then reads work, and a write throws NO_WALLET with a message to show */

  // 1. Before login: a public client and the deployment's addresses are enough to read.
  const mintabear = createMintABearClient({ publicClient: chain.publicClient, addresses: chain.addresses });

  // 2. The whitelist counter: "spots left — 1,000 / 1,000".
  const campaign = await mintabear.whitelist.campaign();
  expect(campaign.spotsLeft).toBe(1000n);

  // 3. A bear that has not been minted reads as `{ exists: false }` — no exception to catch.
  const bear = await mintabear.bears.get(1n);
  expect(bear.exists).toBe(false);

  // 4. Level costs: thresholds are $MNTD base units; formatMntd makes them readable.
  const thresholds = await mintabear.bears.thresholds();
  expect(thresholds.map((t) => formatMntd(t))).toEqual(["0", "1666", "3333", "8333", "16666", "41666"]);
  expect(await mintabear.bears.weights()).toEqual([100, 110, 125, 145, 170, 200]);

  // 5. A write without a wallet throws a MintABearError you can show as it is.
  try {
    await mintabear.bears.burnTo({ tokenId: 1n, targetLevel: 1 });
    expect.unreachable();
  } catch (error) {
    expect(isMintABearError(error, "NO_WALLET")).toBe(true);
    if (isMintABearError(error)) expect(error.userMessage).toBe("Connect a wallet first.");
  }
});

it("creates the full client once the holder connects", async () => {
  /* Scenario:
     Given the holder has connected a wallet
     When the page creates the client with the wallet client too
     Then reads default to the connected wallet */

  // After login: add the wallet client (from Privy's provider on getminted.io).
  const mintabear = createMintABearClient({
    publicClient: chain.publicClient,
    walletClient: chain.wallet("alice"),
    addresses: chain.addresses,
    feeRecipient: chain.feeRecipient,
  });

  // Reads that take a wallet default to the connected one.
  expect(await mintabear.whitelist.claimsOf()).toBe(0);

  // $MNTD's decimals come from the chain; format and parse with them.
  expect(await mintabear.units.decimals()).toBe(18);
  expect(await mintabear.units.parseMntd("1666.5")).toBe(1_666_500_000_000_000_000_000n);
});
