/**
 * Example 7 — reading the event history, and the royalty split.
 *
 * `events.read` returns the system's events decoded by the contract that emitted them, and typed:
 * checking `emitter` and `eventName` narrows `args`. `events.index` feeds them to the reference
 * indexer, whose `levelOf` and `linkOf` answer as the contracts do.
 *
 * `split.run` reads every owned bear's owner and weight at a closing block (from an archive node)
 * and shares the funding: each wallet by the sum of its bears' weights, the dead address excluded,
 * the rounding carried to next time. `bin/split.ts` is the same from the command line.
 */
import { afterAll, beforeAll, expect, it } from "vitest";

import { createMintABearClient, DEAD_ADDRESS, formatMntd, type MintABearClient } from "@mintabear/contracts-client";

import { localChain, type LocalChain } from "./setup.js";

let chain: LocalChain;
let alice: MintABearClient;
let bob: MintABearClient;
let closingBlock: bigint;
beforeAll(async () => {
  chain = await localChain();
  await chain.studio.openPublicStage(0n);
  const clientFor = (who: "alice" | "bob") =>
    createMintABearClient({ publicClient: chain.publicClient, walletClient: chain.wallet(who), addresses: chain.addresses, feeRecipient: chain.feeRecipient, deployBlock: chain.deployBlock });
  alice = clientFor("alice");
  bob = clientFor("bob");
  await alice.mint.public({ quantity: 2n }); // bears 1, 2
  await bob.mint.public({ quantity: 2n }); // bears 3, 4
  await chain.faucet("alice", 50_000n);
  await alice.bears.burnTo({ tokenId: 1n, targetLevel: 5 }); // weight 200
  await alice.bears.link(1n);
  await bob.bears.executeTransfer(await bob.bears.planTransfer({ to: DEAD_ADDRESS, tokenId: 4n })); // excluded from the split
  closingBlock = await chain.publicClient.getBlockNumber();
});
afterAll(() => chain.stop());

it("reads typed events and indexes them", async () => {
  /* Scenario:
     Given mints, a level-5 burn, a link and a transfer to the dead address
     When the page reads the events and indexes them
     Then BearActivated's args are typed, and the indexer answers bear 1 at level 5 linked from alice */
  const events = await alice.events.read();
  const activation = events.find((e) => e.emitter === "activation" && e.eventName === "BearActivated");
  if (activation?.emitter === "activation" && activation.eventName === "BearActivated") {
    expect(activation.args.newLevel).toBe(5); // typed: number
    expect(formatMntd(activation.args.amount)).toBe("41666");
  } else {
    expect.unreachable();
  }

  const indexer = await alice.events.index();
  expect(indexer.levelOf(1n)).toBe(5);
  expect(indexer.linkOf(chain.address("alice"))).toEqual({ tokenId: 1n, level: 5 });
  expect(indexer.owners.get(4n)).toBe(DEAD_ADDRESS);
});

it("splits a distribution at the closing block", async () => {
  /* Scenario:
     Given at the closing block alice holds bears weighing 200 and 100, bob one of 100, and the dead address one of 100
     When 1,000,000 base units are split, in events mode and in snapshot mode
     Then both give alice 750,000 and bob 250,000 of an eligible 400, with nothing carried */
  const split = await alice.split.run({ closingBlock, funding: 1_000_000n });
  expect(split.eligibleWeight).toBe(400n);
  expect(split.excludedWeight).toBe(100n); // the dead address's bear
  expect(split.allocations.map(({ wallet, amount }) => ({ wallet, amount }))).toEqual(
    [
      { wallet: chain.address("alice"), amount: 750_000n },
      { wallet: chain.address("bob"), amount: 250_000n },
    ].sort((x, y) => (BigInt(x.wallet) < BigInt(y.wallet) ? -1 : 1)),
  );
  expect(split.carried).toBe(0n);

  // The other way of reading the same inputs gives the same answer.
  expect(await alice.split.run({ closingBlock, funding: 1_000_000n, mode: "snapshot" })).toEqual(split);
});
