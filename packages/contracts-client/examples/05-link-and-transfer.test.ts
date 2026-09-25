/**
 * Example 5 — the Status link, and transfers.
 *
 * A wallet has no Status boost until it links a bear (`bears.link`), level 5 included; prompt for it
 * after a purchase and after a first burn (`bears.linkPrompt`). Every transfer resets the bear —
 * level, burns and any link to it — so `bears.planTransfer` refuses the transfer that is always a
 * mistake (to yourself) and warns about the ones that cost something.
 *
 * How several wallets' links count for one getminted.io account is MINT's Status service's rule
 * (CQ-21); the library reads each wallet's link on its own.
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

it("prompts for a link after a burn, and links", async () => {
  /* Scenario:
     Given alice has just burned bear 1 to level 3 and links nothing
     When the page asks whether to prompt, and she links it
     Then it prompts, and afterwards her link reads bear 1 at level 3 */
  expect(await alice.bears.linkPrompt(1n)).toEqual({ prompt: true, currentLink: 0n, currentLevel: 0 });

  const { events } = await alice.bears.link(1n);
  expect(events[0]?.eventName).toBe("BearLinked");
  expect(await alice.bears.linkStatus()).toEqual({ state: "active", tokenId: 1n, level: 3 });
});

it("warns before a transfer, and the transfer resets the bear", async () => {
  /* Scenario:
     Given bear 1 at level 3, linked from alice's wallet
     When alice plans to send it to bob, confirms the warnings, and sends
     Then the plan warns RESETS_LEVEL and VOIDS_LINK; afterwards bob holds it at level 0 and alice's link reads voided */
  const plan = await alice.bears.planTransfer({ to: chain.address("bob"), tokenId: 1n });
  expect(plan.warnings.map((w) => w.message)).toEqual([
    "Bear #1 is at level 3. Transferring it resets it to level 0 for the recipient, and the $MNTD burned into it is not refunded.",
    "Bear #1 carries your Status boost. Transferring it removes the boost until you link another bear.",
  ]);

  await alice.bears.executeTransfer(plan); // after the holder confirms

  const bear = await bob.bears.get(1n);
  expect(bear.exists && { owner: bear.owner, level: bear.level }).toEqual({ owner: chain.address("bob"), level: 0 });
  expect(await alice.bears.linkStatus()).toEqual({ state: "voided", tokenId: 1n }); // "your linked bear was sold"
  expect((await bob.bears.linkPrompt(1n)).prompt).toBe(true); // prompt the buyer to link
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
      userMessage: "Sending a bear to the wallet that already holds it moves nothing, but it resets the bear's level and its Status link.",
    });
  }
});
