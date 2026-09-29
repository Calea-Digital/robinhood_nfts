import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { zeroAddress, type Hex } from "viem";

import {
  approveBurnCall,
  burnCall,
  ClientRefusal,
  ContractRevertError,
  execute,
  mintABearAbi,
  planTransfer,
  readLevel,
  readOwner,
  readTransferNonce,
  transferCall,
  type ActivationAddresses,
  type Call,
} from "../src/index.js";
import { startAnvil, type Anvil } from "./setup/anvil.js";
import { accounts, artifact, deployFixture, fundMntd, mintBears, mockMntdAbi, openFreeMint, UNIT, type Fixture } from "./setup/fixture.js";

type Who = "alice" | "bob" | "carol" | "deployer";

describe("transfers", () => {
  let anvil: Anvil;
  let f: Fixture;
  let a: ActivationAddresses;
  let snapshot: Hex;
  const validatorAbi = artifact("MockTransferValidator").abi;

  const send = (who: Who, call: Call) =>
    execute(f.publicClient, f.wallet(accounts[who]), call, { extraErrors: [...mockMntdAbi, ...validatorAbi] });

  async function rejection(promise: Promise<unknown>) {
    return promise.then(
      () => undefined,
      (e: unknown) => e,
    );
  }

  /** alice's bear 1 at level 2 (3,333 $MNTD burned). */
  async function activate() {
    const amount = 3_333n * UNIT;
    await fundMntd(f, accounts.alice.address, 3_333n);
    await send("alice", approveBurnCall(a, amount));
    await send("alice", burnCall(a, 1n, amount));
  }

  beforeAll(async () => {
    anvil = await startAnvil();
    f = await deployFixture(anvil.rpcUrl);
    a = { activation: f.activation, bears: f.bears, mntd: f.mntd };
    await openFreeMint(f);
    await mintBears(f, accounts.alice, 2n); // bears 1–2
  });
  afterAll(() => anvil.stop());
  beforeEach(async () => {
    snapshot = await f.testClient.snapshot();
  });
  afterEach(async () => {
    await f.testClient.revert({ id: snapshot });
  });

  it("refuses a transfer to the same wallet before anything is sent", async () => {
    /* Scenario:
       Given alice owns bear 1
       When she plans a transfer of it to herself
       Then planTransfer throws ClientRefusal SELF_TRANSFER and no transaction is made */
    const block = await f.publicClient.getBlockNumber();
    const error = await rejection(planTransfer(f.publicClient, a, { from: accounts.alice.address, to: accounts.alice.address, tokenId: 1n }));
    expect(error).toBeInstanceOf(ClientRefusal);
    expect((error as ClientRefusal).code).toBe("SELF_TRANSFER");
    expect(await f.publicClient.getBlockNumber()).toBe(block);
  });

  it("shows why: a self-transfer sent anyway resets the level", async () => {
    /* Scenario:
       Given alice's bear 1 at level 2
       When the raw transferFrom(alice, alice, 1) is sent past the guard
       Then the bear stays alice's but its counter advances and its level reads 0 */
    await activate();
    await send("alice", transferCall(a, { from: accounts.alice.address, to: accounts.alice.address, tokenId: 1n }));
    expect(await readOwner(f.publicClient, a, 1n)).toBe(accounts.alice.address);
    expect(await readTransferNonce(f.publicClient, a, 1n)).toBe(1n);
    expect(await readLevel(f.publicClient, a, 1n)).toBe(0);
  });

  it("refuses the zero address in the client, and the collection refuses it with BurnDisabled", async () => {
    /* Scenario:
       Given alice owns bear 1
       When she plans a transfer to the zero address, and sends raw transferFrom and safeTransferFrom to it
       Then the plan throws ZERO_ADDRESS and both raw calls revert BurnDisabled */
    const error = await rejection(planTransfer(f.publicClient, a, { from: accounts.alice.address, to: zeroAddress, tokenId: 1n }));
    expect((error as ClientRefusal).code).toBe("BURN_DISABLED");
    for (const safe of [false, true]) {
      const revert = await rejection(send("alice", transferCall(a, { from: accounts.alice.address, to: zeroAddress, tokenId: 1n, safe })));
      expect((revert as ContractRevertError).revert.errorName).toBe("BurnDisabled");
    }
  });

  it("warns that a transfer resets an activated bear, and it does", async () => {
    /* Scenario:
       Given alice's bear 1 at level 2
       When alice plans a transfer to bob and sends the planned call
       Then the plan warns RESETS_LEVEL (level 2, 3,333 $MNTD) alone, and after it bob's bear reads level 0 */
    await activate();
    const plan = await planTransfer(f.publicClient, a, { from: accounts.alice.address, to: accounts.bob.address, tokenId: 1n, safe: true });
    expect(plan.warnings).toMatchObject([{ code: "RESETS_LEVEL", level: 2, cumulative: 3_333n * UNIT }]);
    expect(plan.warnings).toHaveLength(1);
    await send("alice", plan.call);
    expect(await readOwner(f.publicClient, a, 1n)).toBe(accounts.bob.address);
    expect(await readLevel(f.publicClient, a, 1n)).toBe(0);
  });

  it("gives no warning for a bear never activated", async () => {
    /* Scenario:
       Given bear 2, level 0, never burned for
       When alice plans a transfer to bob
       Then the plan carries no warnings */
    const plan = await planTransfer(f.publicClient, a, { from: accounts.alice.address, to: accounts.bob.address, tokenId: 2n });
    expect(plan.warnings).toEqual([]);
  });

  it("resets on an approved operator's transfer too", async () => {
    /* Scenario:
       Given bear 1 at level 2, alice's approval for bob, and bob a whitelisted operator on the validator
       When bob transfers alice's bear to carol
       Then the plan warns RESETS_LEVEL and the bear reads level 0 for carol */
    await activate();
    await send("alice", { address: f.bears, abi: mintABearAbi, functionName: "setApprovalForAll", args: [accounts.bob.address, true] });
    await send("deployer", { address: f.validator, abi: validatorAbi, functionName: "setWhitelisted", args: [accounts.bob.address, true] });
    const plan = await planTransfer(f.publicClient, a, { from: accounts.alice.address, to: accounts.carol.address, tokenId: 1n });
    expect(plan.warnings[0]).toMatchObject({ code: "RESETS_LEVEL" });
    await send("bob", plan.call);
    expect(await readOwner(f.publicClient, a, 1n)).toBe(accounts.carol.address);
    expect(await readLevel(f.publicClient, a, 1n)).toBe(0);
  });

  it("passes the transfer validator's refusal through for an operator it does not allow", async () => {
    /* Scenario:
       Given alice's approval for bob, who is not a whitelisted operator (the V3 stand-in at level 0)
       When bob transfers alice's bear
       Then the validator's own error comes through (OperatorNotWhitelisted on the stand-in; the real V3's differs) */
    await send("alice", { address: f.bears, abi: mintABearAbi, functionName: "setApprovalForAll", args: [accounts.bob.address, true] });
    const revert = await rejection(send("bob", transferCall(a, { from: accounts.alice.address, to: accounts.carol.address, tokenId: 1n })));
    expect((revert as ContractRevertError).revert.errorName).toBe("OperatorNotWhitelisted");
  });
});
