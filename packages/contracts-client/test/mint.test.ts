import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { parseEther, type Address, type Hex } from "viem";

import {
  allowListMatchesChain,
  buildAllowList,
  ContractRevertError,
  execute,
  mintABearAbi,
  mintAllowListCall,
  mintPublicCall,
  readMintStats,
  readPublicDrop,
  readRemainingWhitelistMints,
  remainingWhitelistMints,
  toTransaction,
  type AllowList,
  type CollectionAddresses,
  type StageParams,
} from "../src/index.js";
import { startAnvil, type Anvil } from "./setup/anvil.js";
import { accounts, deployFixture, type Fixture } from "./setup/fixture.js";

describe("mint through SeaDrop", () => {
  let anvil: Anvil;
  let f: Fixture;
  let c: CollectionAddresses;
  let now: bigint;
  let snapshot: Hex;

  const PRICE = parseEther("0.001");

  async function owner(functionName: string, args: readonly unknown[]) {
    await execute(f.publicClient, f.wallet(accounts.deployer), { address: f.bears, abi: mintABearAbi, functionName, args });
  }

  async function publicStage(opts: { start?: bigint; price?: bigint; perWallet?: number } = {}) {
    await owner("updatePublicDrop", [
      f.seaDrop,
      {
        mintPrice: opts.price ?? PRICE,
        startTime: opts.start ?? now,
        endTime: now + 86_400n,
        maxTotalMintableByWallet: opts.perWallet ?? 10,
        feeBps: 0,
        restrictFeeRecipients: true,
      },
    ]);
  }

  function stage(): StageParams {
    return {
      mintPrice: 0n,
      startTime: now,
      endTime: now + 86_400n,
      dropStageIndex: 1n,
      maxTokenSupplyForStage: 4444n,
      feeBps: 0n,
      restrictFeeRecipients: true,
    };
  }

  async function whitelistStage(rows: { wallet: Address; allocations: number }[]): Promise<AllowList> {
    const list = buildAllowList(rows, stage());
    await owner("updateAllowList", [f.seaDrop, { merkleRoot: list.root, publicKeyURIs: [], allowListURI: "" }]);
    return list;
  }

  async function expectRevert(promise: Promise<unknown>, name: string) {
    const error = await promise.then(
      () => undefined,
      (e: unknown) => e,
    );
    expect(error).toBeInstanceOf(ContractRevertError);
    expect((error as ContractRevertError).revert.errorName).toBe(name);
  }

  beforeAll(async () => {
    anvil = await startAnvil();
    f = await deployFixture(anvil.rpcUrl);
    c = { bears: f.bears, seaDrop: f.seaDrop };
    now = (await f.publicClient.getBlock()).timestamp;
    await owner("updateCreatorPayoutAddress", [f.seaDrop, accounts.payout.address]);
    await owner("updateAllowedFeeRecipient", [f.seaDrop, accounts.feeRecipient.address, true]);
  });
  afterAll(() => anvil.stop());
  beforeEach(async () => {
    snapshot = await f.testClient.snapshot();
  });
  afterEach(async () => {
    await f.testClient.revert({ id: snapshot });
  });

  const alice = () => f.wallet(accounts.alice);
  const feeRecipient = accounts.feeRecipient.address;

  describe("public stage", () => {
    it("mints to the sender at the stage price and reads the stage back", async () => {
      /* Scenario:
         Given an open public stage at 0.001 ETH
         When alice mints two bears with mintPublicCall
         Then she owns bears 1 and 2 and her mint stats count two */
      await publicStage();
      const drop = await readPublicDrop(f.publicClient, c);
      expect(drop.mintPrice).toBe(PRICE);
      await execute(f.publicClient, alice(), mintPublicCall(c, { feeRecipient, quantity: 2n, mintPrice: drop.mintPrice }));
      const read = (id: bigint) => f.publicClient.readContract({ address: f.bears, abi: mintABearAbi, functionName: "ownerOf", args: [id] });
      expect(await read(1n)).toBe(accounts.alice.address);
      expect(await read(2n)).toBe(accounts.alice.address);
      expect(await readMintStats(f.publicClient, c, accounts.alice.address)).toEqual({ numberMinted: 2n, totalSupply: 2n, maxSupply: 4444n });
    });

    it("mints to a recipient other than the payer only for a payer the collection allows", async () => {
      /* Scenario:
         Given an open public stage
         When alice pays for one bear with bob as the minter, before and after the owner allows her as a payer
         Then the first reverts PayerNotAllowed and after the allowance bob owns the bear */
      await publicStage({ price: 0n });
      const forBob = mintPublicCall(c, { feeRecipient, quantity: 1n, mintPrice: 0n, minter: accounts.bob.address });
      await expectRevert(execute(f.publicClient, alice(), forBob), "PayerNotAllowed");
      await owner("updatePayer", [f.seaDrop, accounts.alice.address, true]);
      await execute(f.publicClient, alice(), forBob);
      const owner1 = await f.publicClient.readContract({ address: f.bears, abi: mintABearAbi, functionName: "ownerOf", args: [1n] });
      expect(owner1).toBe(accounts.bob.address);
    });

    it("builds the raw transaction a smart wallet batches", async () => {
      /* Scenario:
         Given a public mint call
         When it is turned into a raw transaction and sent as one
         Then the mint lands just as through execute */
      await publicStage();
      const tx = toTransaction(mintPublicCall(c, { feeRecipient, quantity: 1n, mintPrice: PRICE }));
      expect(tx.to).toBe(f.seaDrop);
      expect(tx.value).toBe(PRICE);
      const hash = await alice().sendTransaction(tx);
      expect((await f.publicClient.waitForTransactionReceipt({ hash })).status).toBe("success");
      expect((await readMintStats(f.publicClient, c, accounts.alice.address)).numberMinted).toBe(1n);
    });

    it("decodes NotActive, IncorrectPayment, FeeRecipientNotAllowed and MintQuantityExceedsMaxMintedPerWallet", async () => {
      /* Scenario:
         Given a public stage not yet started, then an open one with two per wallet
         When alice mints early, underpays, names a fee recipient Studio does not allow, and mints a third
         Then each call reverts with SeaDrop's error decoded by name */
      await publicStage({ start: now + 3_600n, perWallet: 2 });
      await expectRevert(execute(f.publicClient, alice(), mintPublicCall(c, { feeRecipient, quantity: 1n, mintPrice: PRICE })), "NotActive");
      await publicStage({ perWallet: 2 });
      await expectRevert(execute(f.publicClient, alice(), mintPublicCall(c, { feeRecipient, quantity: 1n, mintPrice: 1n })), "IncorrectPayment");
      await expectRevert(
        execute(f.publicClient, alice(), mintPublicCall(c, { feeRecipient: accounts.carol.address, quantity: 1n, mintPrice: PRICE })),
        "FeeRecipientNotAllowed",
      );
      await execute(f.publicClient, alice(), mintPublicCall(c, { feeRecipient, quantity: 2n, mintPrice: PRICE }));
      await expectRevert(
        execute(f.publicClient, alice(), mintPublicCall(c, { feeRecipient, quantity: 1n, mintPrice: PRICE })),
        "MintQuantityExceedsMaxMintedPerWallet",
      );
    });

    it("meets SeaDrop's MintQuantityExceedsMaxSupply first while maxSupply is 4,444", async () => {
      /* Scenario:
         Given 4,443 bears minted and maxSupply at 4,444
         When alice mints two more
         Then SeaDrop refuses with MintQuantityExceedsMaxSupply before the collection's ExceedsMaxBears */
      await publicStage({ price: 0n, perWallet: 65_535 });
      await execute(f.publicClient, f.wallet(accounts.bob), mintPublicCall(c, { feeRecipient, quantity: 4443n, mintPrice: 0n }));
      await expectRevert(
        execute(f.publicClient, alice(), mintPublicCall(c, { feeRecipient, quantity: 2n, mintPrice: 0n })),
        "MintQuantityExceedsMaxSupply",
      );
    });

    it("meets the collection's ExceedsMaxBears once Studio raises maxSupply", async () => {
      /* Scenario:
         Given maxSupply raised to 5,000
         When a mint would take the supply past 4,444
         Then the collection refuses with ExceedsMaxBears */
      await owner("setMaxSupply", [5000n]);
      await publicStage({ price: 0n, perWallet: 65_535 });
      await expectRevert(
        execute(f.publicClient, alice(), mintPublicCall(c, { feeRecipient, quantity: 4445n, mintPrice: 0n })),
        "ExceedsMaxBears",
      );
    });
  });

  describe("whitelist stage", () => {
    it("mints each row's allocations with its proof, and refuses one more", async () => {
      /* Scenario:
         Given an allowlist with alice at two allocations and bob at one, set as Studio sets it
         When alice mints two with her proof and then one more
         Then the two land, the third reverts MintQuantityExceedsMaxMintedPerWallet and her remaining mints read zero */
      const list = await whitelistStage([
        { wallet: accounts.alice.address, allocations: 2 },
        { wallet: accounts.bob.address, allocations: 1 },
      ]);
      expect(await allowListMatchesChain(f.publicClient, c, list)).toBe(true);
      const entry = list.entry(accounts.alice.address)!;
      expect(await readRemainingWhitelistMints(f.publicClient, c, accounts.alice.address, 2)).toBe(2n);
      await execute(f.publicClient, alice(), mintAllowListCall(c, { feeRecipient, quantity: 2n, ...entry }));
      expect(await readRemainingWhitelistMints(f.publicClient, c, accounts.alice.address, 2)).toBe(0n);
      await expectRevert(
        execute(f.publicClient, alice(), mintAllowListCall(c, { feeRecipient, quantity: 1n, ...entry })),
        "MintQuantityExceedsMaxMintedPerWallet",
      );
    });

    it("counts a public mint against the whitelist allocations", async () => {
      /* Scenario:
         Given alice listed with two allocations who has already minted one bear in the public stage
         When her remaining whitelist mints are read and she mints two with her proof
         Then one remains, and the second of the two is refused */
      await publicStage({ price: 0n });
      await execute(f.publicClient, alice(), mintPublicCall(c, { feeRecipient, quantity: 1n, mintPrice: 0n }));
      const list = await whitelistStage([{ wallet: accounts.alice.address, allocations: 2 }]);
      expect(await readRemainingWhitelistMints(f.publicClient, c, accounts.alice.address, 2)).toBe(1n);
      expect(remainingWhitelistMints(2, 3n)).toBe(0n);
      await expectRevert(
        execute(f.publicClient, alice(), mintAllowListCall(c, { feeRecipient, quantity: 2n, ...list.entry(accounts.alice.address)! })),
        "MintQuantityExceedsMaxMintedPerWallet",
      );
    });

    it("refuses another wallet's proof and a list Studio did not set", async () => {
      /* Scenario:
         Given the allowlist set on SeaDrop
         When carol, not listed, mints with alice's proof, and a different list is compared to the chain
         Then the mint reverts InvalidProof and the other list does not match */
      const list = await whitelistStage([
        { wallet: accounts.alice.address, allocations: 2 },
        { wallet: accounts.bob.address, allocations: 1 },
      ]);
      expect(list.entry(accounts.carol.address)).toBeUndefined();
      await expectRevert(
        execute(f.publicClient, f.wallet(accounts.carol), mintAllowListCall(c, { feeRecipient, quantity: 1n, ...list.entry(accounts.alice.address)! })),
        "InvalidProof",
      );
      const other = buildAllowList([{ wallet: accounts.carol.address, allocations: 1 }], stage());
      expect(await allowListMatchesChain(f.publicClient, c, other)).toBe(false);
    });
  });
});
