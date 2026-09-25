import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { toEventSelector, zeroAddress, type Address, type Hex, type TransactionReceipt } from "viem";

import {
  approveBurnCall,
  burnCall,
  ContractRevertError,
  decodeSystemLogs,
  execute,
  linkCall,
  readLevel,
  readLink,
  readSystemEvents,
  ReferenceIndexer,
  transferCall,
  unlinkCall,
  type Call,
  type SystemAddresses,
} from "../src/index.js";
import { startAnvil, type Anvil } from "./setup/anvil.js";
import { accounts, deployFixture, fundMntd, mintBears, openFreeMint, UNIT, type Fixture } from "./setup/fixture.js";

type Who = "alice" | "bob" | "carol";

describe("events and indexing", () => {
  let anvil: Anvil;
  let f: Fixture;
  let sys: Required<Omit<SystemAddresses, "registry">>;
  let a: { activation: Address; bears: Address; mntd: Address };
  let deployBlock: bigint;
  let snapshot: Hex;

  /** Sends `call` from `who` and returns the mined receipt. */
  const send = async (who: Who, call: Call) => (await execute(f.publicClient, f.wallet(accounts[who]), call)).receipt;
  const names = (receipt: TransactionReceipt) => decodeSystemLogs(receipt.logs, sys).map((e) => `${e.emitter}.${e.eventName}`);

  async function burn(who: Who, tokenId: bigint, whole: bigint) {
    await fundMntd(f, accounts[who].address, whole);
    await send(who, approveBurnCall(a, whole * UNIT));
    return send(who, burnCall(a, tokenId, whole * UNIT));
  }

  beforeAll(async () => {
    anvil = await startAnvil();
    f = await deployFixture(anvil.rpcUrl, { mntd: "oz" });
    sys = { bears: f.bears, activation: f.activation, mntd: f.mntd };
    a = { activation: f.activation, bears: f.bears, mntd: f.mntd };
    deployBlock = await f.publicClient.getBlockNumber();
    await openFreeMint(f);
    await mintBears(f, accounts.alice, 3n); // bears 1–3
    await mintBears(f, accounts.bob, 1n); // bear 4
  });
  afterAll(() => anvil.stop());
  beforeEach(async () => {
    snapshot = await f.testClient.snapshot();
  });
  afterEach(async () => {
    await f.testClient.revert({ id: snapshot });
  });

  it("emits TransferNonceAdvanced before Transfer in a transfer's logs, and not on mint", async () => {
    /* Scenario:
       Given alice's bear 1, never transferred
       When she transfers it to bob, and carol mints a bear
       Then the transfer's logs read TransferNonceAdvanced(1, 1) then Transfer(alice, bob, 1), and the mint carries no TransferNonceAdvanced */
    const receipt = await send("alice", transferCall(a, { from: accounts.alice.address, to: accounts.bob.address, tokenId: 1n }));
    const events = decodeSystemLogs(receipt.logs, sys).filter((e) => e.emitter === "bears");
    expect(events.map((e) => e.eventName)).toEqual(["TransferNonceAdvanced", "Transfer"]);
    const reset = events.find((e) => e.eventName === "TransferNonceAdvanced")!;
    const transfer = events.find((e) => e.eventName === "Transfer")!;
    expect(reset.args).toEqual({ tokenId: 1n, nonce: 1n });
    expect(transfer.args).toEqual({ from: accounts.alice.address, to: accounts.bob.address, tokenId: 1n });
    expect(reset.logIndex).toBeLessThan(transfer.logIndex);
    expect(reset.transactionHash).toBe(transfer.transactionHash);

    const before = await f.publicClient.getBlockNumber();
    await mintBears(f, accounts.carol, 1n);
    const minted = await readSystemEvents(f.publicClient, sys, before + 1n);
    expect(minted.map((e) => e.eventName)).toEqual(["Transfer"]);
    const mint = minted[0]!;
    expect(mint.emitter === "bears" && mint.eventName === "Transfer" && mint.args.from).toBe(zeroAddress);
  });

  it("separates $MNTD's Transfer from the collection's by emitter in a burn transaction", async () => {
    /* Scenario:
       Given bear 1 and the OpenZeppelin $MNTD stand-in
       When alice burns 1,666 $MNTD for it
       Then the logs hold $MNTD's Approval and Transfer(alice, 0x0, amount) — same topic as the collection's Transfer — and BearActivated,
            and decoding by emitter reads no bear moving */
    const receipt = await burn("alice", 1n, 1_666n);
    const transferTopic = toEventSelector("Transfer(address,address,uint256)");
    expect(receipt.logs.filter((l) => l.topics[0] === transferTopic)).toHaveLength(1);
    expect(names(receipt)).toEqual(["activation.BearActivated", "mntd.Approval", "mntd.Transfer"]);
    const tokenTransfer = decodeSystemLogs(receipt.logs, sys).find((e) => e.emitter === "mntd" && e.eventName === "Transfer")!;
    expect(tokenTransfer.args).toEqual({ from: accounts.alice.address, to: zeroAddress, value: 1_666n * UNIT });
    expect(decodeSystemLogs(receipt.logs, { bears: f.bears, activation: f.activation }).map((e) => e.eventName)).toEqual(["BearActivated"]);
  });

  it("decodes an OpenZeppelin v4 token's revert strings from a burn", async () => {
    /* Scenario:
       Given the OpenZeppelin $MNTD stand-in, alice with no allowance, then with an allowance and no balance
       When she burns for bear 1
       Then the reverts decode as Error with OpenZeppelin's strings, and map to INSUFFICIENT_MNTD_ALLOWANCE and INSUFFICIENT_MNTD_BALANCE */
    const reason = async (call: Call) =>
      (await send("alice", call).then(
        () => undefined,
        (e: unknown) => e,
      )) as ContractRevertError;
    await fundMntd(f, accounts.alice.address, 2_000n);
    const noAllowance = await reason(burnCall(a, 1n, 1_666n * UNIT));
    expect(noAllowance.revert).toMatchObject({ errorName: "Error", args: { reason: "ERC20: insufficient allowance" } });
    expect(noAllowance.code).toBe("INSUFFICIENT_MNTD_ALLOWANCE");
    await send("alice", approveBurnCall(a, 5_000n * UNIT));
    const noBalance = await reason(burnCall(a, 1n, 3_333n * UNIT));
    expect(noBalance.revert).toMatchObject({ errorName: "Error", args: { reason: "ERC20: burn amount exceeds balance" } });
    expect(noBalance.code).toBe("INSUFFICIENT_MNTD_BALANCE");
  });

  it("replaces a link with BearLinked alone, and a BearUnlinked for a voided link changes nothing", async () => {
    /* Scenario:
       Given alice linking bear 1, which she then sells to bob, who links it
       When alice unlinks her voided link, and bob relinks to bear 4
       Then alice's unlink emits BearUnlinked(alice, 1) and leaves bob's link to 1 standing; bob's relink emits BearLinked only */
    await send("alice", linkCall(a, 1n));
    await send("alice", transferCall(a, { from: accounts.alice.address, to: accounts.bob.address, tokenId: 1n }));
    await send("bob", linkCall(a, 1n));
    const unlink = await send("alice", unlinkCall(a));
    expect(names(unlink)).toEqual(["activation.BearUnlinked"]);
    const indexer = new ReferenceIndexer().applyAll(await readSystemEvents(f.publicClient, sys, deployBlock));
    expect(indexer.linkOf(accounts.bob.address)).toEqual({ tokenId: 1n, level: 0 });
    expect(indexer.linkOf(accounts.alice.address)).toEqual({ tokenId: 0n, level: 0 });
    const relink = await send("bob", linkCall(a, 4n));
    expect(names(relink)).toEqual(["activation.BearLinked"]);
  });

  it("indexes to exactly what the contracts answer", async () => {
    /* Scenario:
       Given a sequence of burns, links, sales, a self-transfer, a voided unlink, relinks and a buy-back
       When the reference indexer replays every event from Activation's deployment
       Then for every bear its level, and for every wallet its link, equal levelOf and linkOf on chain */
    await burn("alice", 1n, 8_333n); // bear 1 → level 3
    await send("alice", linkCall(a, 1n));
    await burn("bob", 4n, 1_666n); // bear 4 → level 1
    await send("bob", linkCall(a, 4n));
    await send("alice", transferCall(a, { from: accounts.alice.address, to: accounts.bob.address, tokenId: 1n })); // sale: resets 1, voids alice's link
    await send("alice", unlinkCall(a)); // BearUnlinked for a void link
    await send("bob", linkCall(a, 1n)); // replaces bob's link to 4
    await burn("bob", 1n, 3_333n); // bear 1 → level 2 under bob
    await send("alice", linkCall(a, 2n));
    await send("alice", linkCall(a, 3n)); // replaces
    await burn("alice", 3n, 41_666n); // bear 3 → level 5
    await send("bob", transferCall(a, { from: accounts.bob.address, to: accounts.bob.address, tokenId: 4n })); // self-transfer resets 4
    await send("bob", transferCall(a, { from: accounts.bob.address, to: accounts.alice.address, tokenId: 1n })); // buy-back: bob's link voided
    await send("carol", unlinkCall(a)); // carol never linked: no event

    const indexer = new ReferenceIndexer().applyAll(await readSystemEvents(f.publicClient, sys, deployBlock));
    for (const id of [1n, 2n, 3n, 4n]) expect(indexer.levelOf(id), `level of ${id}`).toBe(await readLevel(f.publicClient, a, id));
    for (const who of ["alice", "bob", "carol"] as const) {
      const wallet = accounts[who].address;
      expect(indexer.linkOf(wallet), `link of ${who}`).toEqual(await readLink(f.publicClient, a, wallet));
    }
    expect(indexer.linkOf(accounts.alice.address)).toEqual({ tokenId: 3n, level: 5 });
    expect(indexer.linkOf(accounts.bob.address)).toEqual({ tokenId: 0n, level: 0 });
    expect(indexer.owners.get(1n)).toBe(accounts.alice.address);
  });
});
