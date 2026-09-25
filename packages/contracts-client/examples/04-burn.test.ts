/**
 * Example 4 — burning $MNTD to raise a bear's level.
 *
 * The page's flow is plan → show → send:
 *
 * 1. `bears.planBurn({ tokenId, targetLevel })` works out the exact $MNTD and checks everything the
 *    contract will check. A "no" comes back as `{ ok: false, code, userMessage }` — not thrown.
 * 2. Show `plan.amount` and `plan.warnings` (open listings, missing Status link) and ask to confirm.
 * 3. `bears.executeBurn(plan)` sends `approve` (if needed) then `burn`, and returns the new level.
 */
import { afterAll, beforeAll, expect, it } from "vitest";

import { createMintABearClient, explainError, formatMntd, toTransaction } from "@mintabear/contracts-client";

import { localChain, type LocalChain } from "./setup.js";

let chain: LocalChain;
let mintabear: ReturnType<typeof createMintABearClient>;
beforeAll(async () => {
  chain = await localChain();
  await chain.studio.openPublicStage(0n);
  mintabear = createMintABearClient({
    publicClient: chain.publicClient,
    walletClient: chain.wallet("alice"),
    addresses: chain.addresses,
    feeRecipient: chain.feeRecipient,
    // MINT's call to OpenSea's API; the library has no marketplace client of its own.
    countOpenListings: async (tokenId) => (tokenId === 1n ? 1 : 0),
  });
  await mintabear.mint.public({ quantity: 2n }); // alice owns bears 1 and 2
  await chain.faucet("alice", 50_000n); // and 50,000 $MNTD
});
afterAll(() => chain.stop());

it("plans a burn, shows its warnings, and sends it", async () => {
  /* Scenario:
     Given alice's bear 1 at level 0, with one open listing and no Status link
     When she plans a burn to level 2, confirms the warnings, and sends it
     Then the plan asks for 3,333 $MNTD in approve-then-burn, and the bear reaches level 2 */

  // 1. Plan.
  const plan = await mintabear.bears.planBurn({ tokenId: 1n, targetLevel: 2 });
  if (!plan.ok) throw new Error(plan.userMessage);
  expect(`${formatMntd(plan.amount)} $MNTD`).toBe("3333 $MNTD");
  expect(plan.calls.map((c) => c.functionName)).toEqual(["approve", "burn"]); // two wallet prompts

  // 2. Show the warnings; each has a code for your own wording and a message ready to show.
  expect(plan.warnings.map((w) => w.code)).toEqual(["OPEN_LISTINGS", "NOT_LINKED"]);
  expect(plan.warnings[0]!.message).toBe(
    "This bear has 1 open marketplace listing. If one fills after this burn, the buyer gets the bear at level 0 and the $MNTD is lost. Cancel the listings first.",
  );

  // 3. Send, after the holder confirms.
  const { activated } = await mintabear.bears.executeBurn(plan);
  expect(activated).toEqual({ tokenId: 1n, previousLevel: 0, newLevel: 2, amount: plan.amount, cumulative: plan.amount });

  // The bear as the page shows it.
  const bear = await mintabear.bears.get(1n);
  if (!bear.exists) throw new Error("bear 1 exists");
  expect({ level: bear.level, weight: bear.weight, toMax: formatMntd(bear.costToMax) }).toEqual({ level: 2, weight: 125, toMax: "38333" });
});

it("refuses in the plan what the contract would refuse, with a message", async () => {
  /* Scenario:
     Given bear 1 at level 2 and bob's wallet
     When alice plans level 2 again, and bob plans a burn for alice's bear
     Then the plans answer TARGET_REACHED and NOT_BEAR_OWNER with messages, and nothing is sent */
  const again = await mintabear.bears.planBurn({ tokenId: 1n, targetLevel: 2 });
  expect(again).toMatchObject({ ok: false, code: "TARGET_REACHED", userMessage: "This bear is already at level 2 or above." });

  const bob = createMintABearClient({ publicClient: chain.publicClient, walletClient: chain.wallet("bob"), addresses: chain.addresses });
  const notHis = await bob.bears.planBurn({ tokenId: 1n, targetLevel: 3 });
  expect(notHis).toMatchObject({ ok: false, code: "NOT_BEAR_OWNER", userMessage: "Only the bear's owner can do this, and this wallet does not own it." });
});

it("burns in one call from a script, and throws the refusal there", async () => {
  /* Scenario:
     Given a script with no one to confirm warnings
     When it burns bear 2 to level 5, then asks for level 5 again
     Then the first reaches level 5 and the second throws ALREADY_MAX_LEVEL */
  const { activated } = await mintabear.bears.burnTo({ tokenId: 2n, targetLevel: 5 });
  expect(activated.newLevel).toBe(5);

  try {
    await mintabear.bears.burnTo({ tokenId: 2n, targetLevel: 5 });
    expect.unreachable();
  } catch (error) {
    expect(explainError(error)).toMatchObject({ code: "ALREADY_MAX_LEVEL", userMessage: "This bear is already at level 5." });
  }
});

it("hands a smart wallet the plan as one batch", async () => {
  /* Scenario:
     Given a holder on a Privy smart wallet, which can send several calls as one user operation
     When the plan's calls are turned into raw transactions
     Then there is one { to, data, value } per call, approve to $MNTD and burn to Activation */
  const plan = await mintabear.bears.planBurn({ tokenId: 1n, targetLevel: 3 });
  if (!plan.ok) throw new Error(plan.userMessage);

  // With Privy: await smartWalletClient.sendTransaction({ calls: plan.calls.map(toTransaction) })
  const batch = plan.calls.map(toTransaction);
  expect(batch.map((tx) => tx.to)).toEqual([chain.addresses.mntd, chain.addresses.activation]);
  expect(batch.every((tx) => tx.value === 0n)).toBe(true);
});
