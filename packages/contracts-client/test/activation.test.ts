import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { createWalletClient, http, parseEventLogs, type Address, type Hex } from "viem";
import { foundry } from "viem/chains";

import {
  activationAbi,
  approveBurnCall,
  burnCall,
  ContractRevertError,
  execute,
  linkCall,
  linkPrompt,
  planBurn,
  readBear,
  readCostToReach,
  readExists,
  readLevel,
  readLink,
  readLinkStatus,
  readPaused,
  readSnapshot,
  readThreshold,
  readWeight,
  readWeightFor,
  toTransaction,
  transferCall,
  unlinkCall,
  type ActivationAddresses,
  type Call,
} from "../src/index.js";
import { startAnvil, type Anvil } from "./setup/anvil.js";
import {
  accounts,
  deployFixture,
  fundMntd,
  mintBears,
  mockMntdAbi,
  openFreeMint,
  THRESHOLDS_WHOLE,
  UNIT,
  WEIGHTS,
  type Fixture,
} from "./setup/fixture.js";

type Who = "alice" | "bob" | "carol" | "deployer";

describe("activation: burn, link and reads", () => {
  let anvil: Anvil;
  let f: Fixture;
  let a: ActivationAddresses;
  let deployBlock: bigint;
  let snapshot: Hex;

  const T = (level: 1 | 2 | 3 | 4 | 5) => THRESHOLDS_WHOLE[level - 1]! * UNIT;

  /** Sends `call` from `who` (decoding the $MNTD stand-in's errors) and returns the mined receipt. */
  const send = async (who: Who, call: Call) => (await execute(f.publicClient, f.wallet(accounts[who]), call, { extraErrors: mockMntdAbi })).receipt;

  async function expectRevert(promise: Promise<unknown>, name: string) {
    const error = await promise.then(
      () => undefined,
      (e: unknown) => e,
    );
    expect(error).toBeInstanceOf(ContractRevertError);
    expect((error as ContractRevertError).revert.errorName).toBe(name);
  }

  /** `who` is funded and approves `amount` of $MNTD, then burns it for `tokenId`. */
  async function burnAs(who: Who, tokenId: bigint, amount: bigint) {
    await fundMntd(f, accounts[who].address, amount / UNIT + 1n);
    await send(who, approveBurnCall(a, amount));
    return send(who, burnCall(a, tokenId, amount));
  }

  const setPaused = (paused: boolean) =>
    send("deployer", { address: f.activation, abi: activationAbi, functionName: "setPaused", args: [paused] });

  beforeAll(async () => {
    anvil = await startAnvil();
    f = await deployFixture(anvil.rpcUrl);
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

  describe("reads", () => {
    it("answers the specified thresholds and weights, scaled by $MNTD's decimals", async () => {
      /* Scenario:
         Given Activation deployed with the specified thresholds and weights over an 18-decimal $MNTD
         When thresholdFor and weightFor are read for levels 0–5
         Then thresholds are 0 and 1,666 … 41,666 whole $MNTD in base units, weights 100 … 200 */
      expect(await readThreshold(f.publicClient, a, 0)).toBe(0n);
      for (const level of [1, 2, 3, 4, 5] as const) expect(await readThreshold(f.publicClient, a, level)).toBe(T(level));
      for (const [level, weight] of WEIGHTS.entries()) expect(await readWeightFor(f.publicClient, a, level)).toBe(weight);
      expect(await readPaused(f.publicClient, a)).toBe(false);
    });

    it("reads an unminted id as absent: weightOf 100, snapshot zeroes", async () => {
      /* Scenario:
         Given id 100, never minted
         When exists, weightOf and snapshot are read
         Then exists is false, weightOf answers the level-0 weight 100 and snapshot a zero row — why a split sums only owned ids */
      expect(await readExists(f.publicClient, a, 100n)).toBe(false);
      expect(await readWeight(f.publicClient, a, 100n)).toBe(100);
      expect(await readSnapshot(f.publicClient, a, [100n])).toEqual([{ owner: "0x0000000000000000000000000000000000000000", level: 0, weight: 0 }]);
      expect(await readBear(f.publicClient, a, 100n)).toEqual({ tokenId: 100n, exists: false });
    });
  });

  describe("burn", () => {
    it("plans approve then burn for exactly costToReach, and records the level", async () => {
      /* Scenario:
         Given alice owns bear 1 at level 0 with enough $MNTD and no allowance
         When she plans a burn to level 2 and sends the planned calls
         Then the amount is 3,333 $MNTD, the calls are approve then burn, and BearActivated reads 0 → 2 with that amount */
      await fundMntd(f, accounts.alice.address, 10_000n);
      const plan = await planBurn(f.publicClient, a, { tokenId: 1n, owner: accounts.alice.address, targetLevel: 2 });
      expect(plan.ok).toBe(true);
      if (!plan.ok) return;
      expect(plan.amount).toBe(T(2));
      expect(plan.calls.map((c) => c.functionName)).toEqual(["approve", "burn"]);
      expect(plan.calls[0]!.args).toEqual([f.activation, T(2)]);
      let receipt;
      for (const call of plan.calls) receipt = await send("alice", call);
      const [event] = parseEventLogs({ abi: activationAbi, logs: receipt!.logs, eventName: "BearActivated" });
      expect(event?.args).toEqual({ tokenId: 1n, burner: accounts.alice.address, previousLevel: 0, newLevel: 2, amount: T(2), cumulative: T(2) });
      const bear = await readBear(f.publicClient, a, 1n);
      expect(bear).toMatchObject({ exists: true, owner: accounts.alice.address, level: 2, cumulative: T(2), lifetimeBurned: T(2), weight: 125, costToMax: T(5) - T(2) });
    });

    it("plans burn alone when the allowance already covers it, and batches as raw transactions", async () => {
      /* Scenario:
         Given alice has approved Activation for more than the burn
         When she plans a burn to level 1 and sends it as raw transactions
         Then the plan is one burn call and the bear reaches level 1 */
      await fundMntd(f, accounts.alice.address, 10_000n);
      await send("alice", approveBurnCall(a, 10_000n * UNIT));
      const plan = await planBurn(f.publicClient, a, { tokenId: 1n, owner: accounts.alice.address, targetLevel: 1 });
      if (!plan.ok) throw new Error(plan.userMessage);
      expect(plan.calls.map((c) => c.functionName)).toEqual(["burn"]);
      const hash = await f.wallet(accounts.alice).sendTransaction(toTransaction(plan.calls[0]!));
      await f.publicClient.waitForTransactionReceipt({ hash });
      expect(await readLevel(f.publicClient, a, 1n)).toBe(1);
    });

    it("warns about open listings and a missing link before a burn", async () => {
      /* Scenario:
         Given bear 1 with two open listings and alice's wallet linking no bear
         When she plans a burn
         Then the plan warns OPEN_LISTINGS with the count and NOT_LINKED */
      await fundMntd(f, accounts.alice.address, 2_000n);
      const plan = await planBurn(f.publicClient, a, {
        tokenId: 1n,
        owner: accounts.alice.address,
        targetLevel: 1,
        countOpenListings: async () => 2,
      });
      expect(plan).toMatchObject({ ok: true, warnings: [{ code: "OPEN_LISTINGS", count: 2 }, { code: "NOT_LINKED", currentLink: 0n }] });
    });

    it("refuses in the plan what burn would refuse", async () => {
      /* Scenario:
         Given an unminted id, bob's bear, a bear at level 5, a target already reached, a short balance, and Activation paused
         When alice plans each burn
         Then the plan answers NonexistentToken, NotBearOwner, AlreadyAtMaxLevel, TargetReached, InsufficientBalance and ContractPaused */
      const plan = (tokenId: bigint, targetLevel: number) => planBurn(f.publicClient, a, { tokenId, owner: accounts.alice.address, targetLevel });
      expect(await plan(100n, 1)).toMatchObject({ ok: false, code: "TOKEN_DOES_NOT_EXIST" });
      expect(await plan(4n, 1)).toMatchObject({ ok: false, code: "NOT_BEAR_OWNER" });
      expect(await plan(2n, 1)).toMatchObject({ ok: false, code: "INSUFFICIENT_MNTD_BALANCE" });
      await burnAs("alice", 1n, T(5));
      expect(await plan(1n, 5)).toMatchObject({ ok: false, code: "ALREADY_MAX_LEVEL" });
      await burnAs("alice", 2n, T(2));
      expect(await plan(2n, 1)).toMatchObject({ ok: false, code: "TARGET_REACHED" });
      await setPaused(true);
      expect(await plan(3n, 1)).toMatchObject({ ok: false, code: "ACTIVATION_PAUSED" });
    });

    it("refuses a target level outside 1..5 before reading anything", async () => {
      /* Scenario:
         Given bear 1
         When a burn is planned to level 0, 6 or 2.5
         Then planBurn throws a RangeError rather than meeting the contract's InvalidLevel */
      for (const targetLevel of [0, 6, 2.5]) {
        await expect(planBurn(f.publicClient, a, { tokenId: 1n, owner: accounts.alice.address, targetLevel })).rejects.toMatchObject({ code: "INVALID_ARGUMENT" });
      }
    });

    it("reverts ContractPaused before ZeroAmount before NotBearOwner", async () => {
      /* Scenario:
         Given Activation paused
         When bob burns zero for alice's bear, then again unpaused, then a non-zero amount
         Then the reverts are ContractPaused, then ZeroAmount, then NotBearOwner — the contract's check order */
      await setPaused(true);
      await expectRevert(send("bob", burnCall(a, 1n, 0n)), "ContractPaused");
      await setPaused(false);
      await expectRevert(send("bob", burnCall(a, 1n, 0n)), "ZeroAmount");
      await expectRevert(send("bob", burnCall(a, 1n, 1n)), "NotBearOwner");
    });

    it("reverts NotBearOwner before AlreadyAtMaxLevel, and AlreadyAtMaxLevel before Overshoot", async () => {
      /* Scenario:
         Given bear 1 at level 5
         When bob burns for it, then alice burns more than any remainder
         Then bob's reverts NotBearOwner and alice's AlreadyAtMaxLevel */
      await burnAs("alice", 1n, T(5));
      await expectRevert(send("bob", burnCall(a, 1n, 1n)), "NotBearOwner");
      await expectRevert(send("alice", burnCall(a, 1n, T(5))), "AlreadyAtMaxLevel");
    });

    it("reverts Overshoot one base unit above the level-5 remainder, and burns exactly the remainder", async () => {
      /* Scenario:
         Given bear 1 at level 1
         When alice burns costToReach(1, 5) + 1, then exactly costToReach(1, 5)
         Then the first reverts Overshoot and the second takes the bear to level 5 */
      await burnAs("alice", 1n, T(1));
      const rest = await readCostToReach(f.publicClient, a, 1n, 5);
      expect(rest).toBe(T(5) - T(1));
      await fundMntd(f, accounts.alice.address, 50_000n);
      await send("alice", approveBurnCall(a, rest + 1n));
      await expectRevert(send("alice", burnCall(a, 1n, rest + 1n)), "Overshoot");
      await send("alice", burnCall(a, 1n, rest));
      expect(await readLevel(f.publicClient, a, 1n)).toBe(5);
    });

    it("reverts OwnerQueryForNonexistentToken for an id never minted, from burn and linkBear", async () => {
      /* Scenario:
         Given id 100, never minted
         When alice burns for it and links it
         Then both revert with the collection's OwnerQueryForNonexistentToken, not NotBearOwner */
      await expectRevert(send("alice", burnCall(a, 100n, 1n)), "OwnerQueryForNonexistentToken");
      await expectRevert(send("alice", linkCall(a, 100n)), "OwnerQueryForNonexistentToken");
    });

    it("passes the token's own reverts through for a short allowance or balance, and records nothing", async () => {
      /* Scenario:
         Given alice with $MNTD but no allowance, then with an allowance but no balance
         When she burns for bear 1
         Then the token's InsufficientAllowance and InsufficientBalance come through and the bear stays at level 0 */
      await fundMntd(f, accounts.alice.address, 2_000n);
      await expectRevert(send("alice", burnCall(a, 1n, T(1))), "InsufficientAllowance");
      await send("alice", approveBurnCall(a, 10_000n * UNIT));
      await expectRevert(send("alice", burnCall(a, 1n, 5_000n * UNIT)), "InsufficientBalance");
      expect(await readLevel(f.publicClient, a, 1n)).toBe(0);
    });

    it("burns from a smart-wallet address that owns the bear", async () => {
      /* Scenario:
         Given bear 1 moved to a contract address standing for a smart wallet, funded and approved from it
         When that address sends the burn
         Then the bear reaches level 1 under the smart account */
      const smart = f.validator as Address;
      await send("alice", transferCall(a, { from: accounts.alice.address, to: smart, tokenId: 1n }));
      await f.testClient.impersonateAccount({ address: smart });
      await f.testClient.setBalance({ address: smart, value: 10n ** 18n });
      const wallet = createWalletClient({ chain: foundry, transport: http(anvil.rpcUrl), account: smart });
      await fundMntd(f, smart, 2_000n);
      await execute(f.publicClient, wallet, approveBurnCall(a, T(1)));
      await execute(f.publicClient, wallet, burnCall(a, 1n, T(1)));
      await f.testClient.stopImpersonatingAccount({ address: smart });
      expect(await readLevel(f.publicClient, a, 1n)).toBe(1);
    });
  });

  describe("link", () => {
    it("links a bear, reads its level through the link, and replaces the link without BearUnlinked", async () => {
      /* Scenario:
         Given alice owns bears 1 (level 2) and 2
         When she links 1, then links 2
         Then linkOf reads (1, 2) and then (2, 0), and the second link emits BearLinked only */
      await burnAs("alice", 1n, T(2));
      await send("alice", linkCall(a, 1n));
      expect(await readLink(f.publicClient, a, accounts.alice.address)).toEqual({ tokenId: 1n, level: 2 });
      const receipt = await send("alice", linkCall(a, 2n));
      expect(parseEventLogs({ abi: activationAbi, logs: receipt.logs }).map((e) => e.eventName)).toEqual(["BearLinked"]);
      expect(await readLink(f.publicClient, a, accounts.alice.address)).toEqual({ tokenId: 2n, level: 0 });
    });

    it("unlinks, even while paused, and unlinking with no link is a silent no-op", async () => {
      /* Scenario:
         Given alice linking bear 1 and Activation paused
         When she unlinks, then unlinks again
         Then the first emits BearUnlinked and clears the link, the second emits nothing and does not revert */
      await send("alice", linkCall(a, 1n));
      await setPaused(true);
      const first = await send("alice", unlinkCall(a));
      expect(parseEventLogs({ abi: activationAbi, logs: first.logs }).map((e) => e.eventName)).toEqual(["BearUnlinked"]);
      expect(await readLink(f.publicClient, a, accounts.alice.address)).toEqual({ tokenId: 0n, level: 0 });
      const second = await send("alice", unlinkCall(a));
      expect(second.logs).toEqual([]);
    });

    it("refuses linkBear while paused and for another wallet's bear", async () => {
      /* Scenario:
         Given bob's bear 4
         When alice links it, and links her own while paused
         Then the reverts are NotBearOwner and ContractPaused */
      await expectRevert(send("alice", linkCall(a, 4n)), "NotBearOwner");
      await setPaused(true);
      await expectRevert(send("alice", linkCall(a, 1n)), "ContractPaused");
    });

    it("shows a link voided by a sale, and prompts the buyer to link", async () => {
      /* Scenario:
         Given alice linking bear 1 at level 3
         When she sells it to bob
         Then alice's link reads voided for bear 1, the bear reads level 0, and bob is prompted to link it */
      await burnAs("alice", 1n, T(3));
      await send("alice", linkCall(a, 1n));
      expect(await readLinkStatus(f.publicClient, a, accounts.alice.address, deployBlock)).toEqual({ state: "active", tokenId: 1n, level: 3 });
      await send("alice", transferCall(a, { from: accounts.alice.address, to: accounts.bob.address, tokenId: 1n }));
      expect(await readLinkStatus(f.publicClient, a, accounts.alice.address, deployBlock)).toEqual({ state: "voided", tokenId: 1n });
      expect(await readLevel(f.publicClient, a, 1n)).toBe(0);
      expect(await linkPrompt(f.publicClient, a, accounts.bob.address, 1n)).toEqual({ prompt: true, currentLink: 0n, currentLevel: 0 });
      await send("bob", linkCall(a, 1n));
      expect(await linkPrompt(f.publicClient, a, accounts.bob.address, 1n)).toMatchObject({ prompt: false });
    });

    it("reads none for a wallet that never linked or unlinked", async () => {
      /* Scenario:
         Given carol, who never linked, and alice, who linked and unlinked
         When their link status is read
         Then both read none */
      expect(await readLinkStatus(f.publicClient, a, accounts.carol.address, deployBlock)).toEqual({ state: "none" });
      await send("alice", linkCall(a, 1n));
      await send("alice", unlinkCall(a));
      expect(await readLinkStatus(f.publicClient, a, accounts.alice.address, deployBlock)).toEqual({ state: "none" });
    });

    it("prompts after a first burn when the wallet links another bear or none", async () => {
      /* Scenario:
         Given alice linking bear 2 and just having burned for bear 1
         When the link prompt is read for bear 1
         Then it prompts, with bear 2 as the current link */
      await send("alice", linkCall(a, 2n));
      await burnAs("alice", 1n, T(1));
      expect(await linkPrompt(f.publicClient, a, accounts.alice.address, 1n)).toEqual({ prompt: true, currentLink: 2n, currentLevel: 0 });
    });
  });
});
