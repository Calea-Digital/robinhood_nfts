/**
 * Example 5 — transfers.
 *
 * Every transfer resets the bear — its level and its burns — so `bears.planTransfer` refuses the
 * transfer that is always a mistake (to yourself) and warns about the one that costs something.
 */
import { afterAll, beforeAll, expect, it } from "vitest";

import { createMintABearClient, explainError, type MintABearClient } from "@mintabear/contracts-client";

import { localChain, type LocalChain } from "./setup.js";

let chain: LocalChain;
let alice: MintABearClient;
let bob: MintABearClient;
beforeAll(async () => {
  chain = await localChain();
  await chain.studio.openPublicStage(0n);
  const clientFor = (who: "alice" | "bob") =>
    createMintABearClient({
      publicClient: chain.publicClient,
      walletClient: chain.wallet(who),
      addresses: chain.addresses,
      feeRecipient: chain.feeRecipient,
      deployBlock: chain.deployBlock,
    });
  alice = clientFor("alice");
  bob = clientFor("bob");
  await alice.mint.public({ quantity: 1n }); // bear 1
  await chain.faucet("alice", 10_000n);
  await alice.bears.burnTo({ tokenId: 1n, targetLevel: 3 });
});
afterAll(() => chain.stop());

it("warns before a transfer, and the transfer resets the bear", async () => {
  /* Scenario:
     Given alice's bear 1 at level 3
     When alice plans to send it to bob, confirms the warning, and sends
     Then the plan warns RESETS_LEVEL; afterwards bob holds it at level 0 */
  const plan = await alice.bears.planTransfer({ to: chain.address("bob"), tokenId: 1n });
  expect(plan.warnings.map((w) => w.message)).toEqual([
    "Bear #1 is at level 3. Transferring it resets it to level 0 for the recipient, and the $MNTD burned into it is not refunded.",
  ]);

  await alice.bears.executeTransfer(plan); // after the holder confirms

  const bear = await bob.bears.get(1n);
  expect(bear.exists && { owner: bear.owner, level: bear.level }).toEqual({ owner: chain.address("bob"), level: 0 });
});

it("refuses a transfer to the wallet that already holds the bear", async () => {
  /* Scenario:
     Given bob holds bear 1
     When he plans a transfer of it to himself
     Then the plan throws SELF_TRANSFER with a message, and nothing is sent */
  try {
    await bob.bears.planTransfer({ to: chain.address("bob"), tokenId: 1n });
    expect.unreachable();
  } catch (error) {
    expect(explainError(error)).toMatchObject({
      code: "SELF_TRANSFER",
      userMessage: "Sending a bear to the wallet that already holds it moves nothing, but it resets the bear's level.",
    });
  }
});
