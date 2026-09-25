import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { execFile } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { encodeFunctionData, type Address } from "viem";

import {
  activationAbi,
  approveBurnCall,
  burnCall,
  computeSplit,
  DEAD_ADDRESS,
  execute,
  MAX_BEARS,
  readWeight,
  rowsFromEvents,
  rowsFromSnapshot,
  transferCall,
  type BearRow,
  type Call,
} from "../src/index.js";
import { startAnvil, type Anvil } from "./setup/anvil.js";
import { accounts, deployFixture, fundMntd, mintBears, openFreeMint, UNIT, type Fixture } from "./setup/fixture.js";

const W = {
  a: "0x000000000000000000000000000000000000000A" as Address,
  b: "0x000000000000000000000000000000000000000b" as Address,
  c: "0x000000000000000000000000000000000000000C" as Address,
};

const byId = (rows: readonly BearRow[]) =>
  [...rows].map((r) => ({ ...r, weight: BigInt(r.weight) })).sort((x, y) => (x.tokenId < y.tokenId ? -1 : 1));

describe("computeSplit", () => {
  it("pins the allocations and the carried rounding on a fixture", () => {
    /* Scenario:
       Given wallet a with bears weighing 100 and 125, b with one at 200, c (a contract) with one at 110, and the dead address with one at 170
       When 1,000,000 base units are split
       Then the eligible weight is 535 and excludes the dead address's 170; a gets 420,560, b 373,831, c 205,607; 2 are carried; allocations plus carried equal the funding */
    const rows: BearRow[] = [
      { tokenId: 1n, owner: W.a, weight: 100 },
      { tokenId: 2n, owner: W.a, weight: 125 },
      { tokenId: 3n, owner: W.b, weight: 200 },
      { tokenId: 4n, owner: W.c, weight: 110 },
      { tokenId: 5n, owner: DEAD_ADDRESS, weight: 170 },
    ];
    const result = computeSplit(rows, 1_000_000n);
    expect(result.eligibleWeight).toBe(535n);
    expect(result.excludedWeight).toBe(170n);
    expect(result.allocations).toEqual([
      { wallet: "0x000000000000000000000000000000000000000A", weight: 225n, bears: 2, amount: 420_560n },
      { wallet: "0x000000000000000000000000000000000000000b", weight: 200n, bears: 1, amount: 373_831n },
      { wallet: "0x000000000000000000000000000000000000000C", weight: 110n, bears: 1, amount: 205_607n },
    ]);
    expect(result.carried).toBe(2n);
    expect(result.allocations.reduce((s, x) => s + x.amount, 0n) + result.carried).toBe(1_000_000n);
  });

  it("adds carried-in rounding to the funding, and carries fewer units than there are wallets", () => {
    /* Scenario:
       Given seven wallets of uneven weights, 1e18 + 3 base units of funding and 2 carried in
       When the split is computed
       Then the distributable is 1e18 + 5, allocations plus carried equal it, and carried is below seven */
    const rows: BearRow[] = Array.from({ length: 7 }, (_, i) => ({
      tokenId: BigInt(i + 1),
      owner: `0x${(i + 16).toString(16).padStart(40, "0")}` as Address,
      weight: [100, 110, 125, 145, 170, 200, 100][i]!,
    }));
    const result = computeSplit(rows, 10n ** 18n + 3n, { carriedIn: 2n });
    expect(result.distributable).toBe(10n ** 18n + 5n);
    expect(result.allocations.reduce((s, x) => s + x.amount, 0n) + result.carried).toBe(result.distributable);
    expect(result.carried < 7n).toBe(true);
  });

  it("carries everything when no bear is eligible", () => {
    /* Scenario:
       Given only a bear held by the dead address
       When 1,000 is split
       Then nothing is allocated and all 1,000 are carried */
    const result = computeSplit([{ tokenId: 1n, owner: DEAD_ADDRESS, weight: 100 }], 1_000n);
    expect(result.allocations).toEqual([]);
    expect(result.carried).toBe(1_000n);
  });

  it("refuses a duplicate id, an id outside 1..4,444 and a row with no owner", () => {
    /* Scenario:
       Given rows with id 1 twice, id 0, id 4,445, and a row owned by the zero address
       When each is split
       Then each throws: duplicates would pay twice, and an ownerless id is a bear never minted */
    const row = (tokenId: bigint, owner: Address = W.a): BearRow => ({ tokenId, owner, weight: 100 });
    expect(() => computeSplit([row(1n), row(1n)], 1n)).toThrow(/twice/);
    expect(() => computeSplit([row(0n)], 1n)).toThrow(/outside/);
    expect(() => computeSplit([row(BigInt(MAX_BEARS) + 1n)], 1n)).toThrow(/outside/);
    expect(() => computeSplit([row(1n, "0x0000000000000000000000000000000000000000")], 1n)).toThrow(/no owner/);
  });
});

describe("split inputs on chain", () => {
  let anvil: Anvil;
  let f: Fixture;
  let fromBlock: bigint;
  let closingBlock: bigint;
  const contractHolder = () => f.validator; // any contract address

  const send = (who: "alice" | "bob" | "carol", call: Call) => execute(f.publicClient, f.wallet(accounts[who]), call);
  const c = () => ({ bears: f.bears, activation: f.activation, mntd: f.mntd });

  async function burn(who: "alice" | "bob", tokenId: bigint, whole: bigint) {
    await fundMntd(f, accounts[who].address, whole);
    await send(who, approveBurnCall(c(), whole * UNIT));
    await send(who, burnCall(c(), tokenId, whole * UNIT));
  }

  beforeAll(async () => {
    anvil = await startAnvil();
    f = await deployFixture(anvil.rpcUrl);
    fromBlock = await f.publicClient.getBlockNumber();
    await openFreeMint(f);
    await mintBears(f, accounts.alice, 3n); // 1–3
    await mintBears(f, accounts.bob, 2n); // 4–5
    await mintBears(f, accounts.carol, 2n); // 6–7
    await mintBears(f, accounts.bob, 1n); // 8
    await send("bob", transferCall(c(), { from: accounts.bob.address, to: DEAD_ADDRESS, tokenId: 8n }));
    await send("carol", transferCall(c(), { from: accounts.carol.address, to: contractHolder(), tokenId: 7n }));
    await burn("alice", 1n, 3_333n); // level 2, weight 125
    await burn("bob", 4n, 41_666n); // level 5, weight 200
    closingBlock = await f.publicClient.getBlockNumber();
    // After the close: none of this may reach the split.
    await burn("alice", 2n, 1_666n);
    await send("bob", transferCall(c(), { from: accounts.bob.address, to: accounts.carol.address, tokenId: 5n }));
    await mintBears(f, accounts.carol, 1n); // 9
  });
  afterAll(() => anvil.stop());

  const expectedRows = () => [
    { tokenId: 1n, owner: accounts.alice.address, weight: 125n },
    { tokenId: 2n, owner: accounts.alice.address, weight: 100n },
    { tokenId: 3n, owner: accounts.alice.address, weight: 100n },
    { tokenId: 4n, owner: accounts.bob.address, weight: 200n },
    { tokenId: 5n, owner: accounts.bob.address, weight: 100n },
    { tokenId: 6n, owner: accounts.carol.address, weight: 100n },
    { tokenId: 7n, owner: contractHolder(), weight: 100n },
    { tokenId: 8n, owner: DEAD_ADDRESS, weight: 100n },
  ];

  it("reads owners from Transfer events and weights from weightOf at the closing block", async () => {
    /* Scenario:
       Given eight bears at the closing block — levels 2 and 5 among them, one with the dead address, one with a contract — and a burn, a sale and a mint after it
       When the inputs are read in events mode at the closing block
       Then they are exactly the eight bears with their owners and weights at the close */
    expect(byId(await rowsFromEvents(f.publicClient, c(), { fromBlock, closingBlock, blockRange: 3n }))).toEqual(expectedRows());
  });

  it("reads the same rows from snapshot, paged, and drops ids never minted", async () => {
    /* Scenario:
       Given the same closing block
       When snapshot is read over exactly 1..4,444 with a small gas budget
       Then it takes several pages, and after dropping ownerless ids gives the events mode's rows */
    const { rows, pages } = await rowsFromSnapshot(f.publicClient, c(), { closingBlock, gasBudget: 2_000_000n });
    expect(pages.length).toBeGreaterThan(1);
    expect(pages.reduce((s, n) => s + n, 0)).toBe(MAX_BEARS);
    expect(byId(rows)).toEqual(expectedRows());
  });

  it("splits the same way from either mode, with the dead address excluded and the contract kept", async () => {
    /* Scenario:
       Given the rows from both modes and 1,000,000 base units of funding
       When the split is computed
       Then both give alice 393,939 (325), bob 363,636 (300), carol and the contract 121,212 (100 each), eligible weight 825 without the dead address's 100, and 1 carried */
    const fromEvents = computeSplit(await rowsFromEvents(f.publicClient, c(), { fromBlock, closingBlock }), 1_000_000n);
    const fromSnapshot = computeSplit((await rowsFromSnapshot(f.publicClient, c(), { closingBlock })).rows, 1_000_000n);
    expect(fromSnapshot).toEqual(fromEvents);
    expect(fromEvents.eligibleWeight).toBe(825n);
    expect(fromEvents.excludedWeight).toBe(100n);
    const amount = (wallet: Address) => fromEvents.allocations.find((x) => x.wallet === wallet)?.amount;
    expect(amount(accounts.alice.address)).toBe(393_939n);
    expect(amount(accounts.bob.address)).toBe(363_636n);
    expect(amount(accounts.carol.address)).toBe(121_212n);
    expect(amount(contractHolder())).toBe(121_212n);
    expect(fromEvents.carried).toBe(1n);
  });

  it("would count phantom bears if weightOf were summed over the whole range", async () => {
    /* Scenario:
       Given the collection before sell-out
       When weightOf is read for an id never minted
       Then it answers 100 — so a whole-range sum would add 100 per unminted id, which the inputs never do */
    expect(await readWeight(f.publicClient, c(), 4_444n)).toBe(100);
    const rows = await rowsFromEvents(f.publicClient, c(), { fromBlock, closingBlock });
    expect(rows.some((r) => r.tokenId > 8n)).toBe(false);
  });

  it("refuses duplicate ids for snapshot", async () => {
    /* Scenario:
       Given an id list with 1 twice
       When snapshot mode is asked for it
       Then it throws, since snapshot would return a duplicate row */
    await expect(rowsFromSnapshot(f.publicClient, c(), { closingBlock, ids: [1n, 1n] })).rejects.toThrow(/duplicates/);
  });

  it("runs as a command and prints the split", async () => {
    /* Scenario:
       Given the closing block and 1,000,000 base units
       When bin/split.ts runs in each mode against the node
       Then its JSON is the split computed in-process, amounts as strings */
    const pkg = join(dirname(fileURLToPath(import.meta.url)), "..");
    const run = async (mode: string) => {
      const { stdout } = await promisify(execFile)(
        join(pkg, "node_modules", ".bin", "tsx"),
        [
          "bin/split.ts",
          "--rpc", anvil.rpcUrl,
          "--bears", f.bears,
          "--activation", f.activation,
          "--from-block", fromBlock.toString(),
          "--block", closingBlock.toString(),
          "--funding", "1000000",
          "--mode", mode,
        ],
        { cwd: pkg },
      );
      return JSON.parse(stdout);
    };
    const expected = computeSplit(await rowsFromEvents(f.publicClient, c(), { fromBlock, closingBlock }), 1_000_000n);
    for (const mode of ["events", "snapshot"]) {
      const out = await run(mode);
      expect(out.bears).toBe(8);
      expect(out.carried).toBe(expected.carried.toString());
      expect(out.allocations).toEqual(expected.allocations.map((x) => ({ ...x, weight: x.weight.toString(), amount: x.amount.toString() })));
    }
  }, 60_000);
});

describe("snapshot over a long untransferred mint batch", () => {
  let anvil: Anvil;
  let f: Fixture;

  beforeAll(async () => {
    anvil = await startAnvil();
    f = await deployFixture(anvil.rpcUrl);
    await openFreeMint(f);
    await mintBears(f, accounts.alice, 400n); // one batch: ownerOf walks back to id 1
  });
  afterAll(() => anvil.stop());

  it("pages by gas where a fixed count would not fit, and agrees with events mode", async () => {
    /* Scenario:
       Given 400 bears minted in one batch, so each ownerOf walks back to the batch start
       When snapshot mode reads 1..400 under a 3M gas budget
       Then one call over all 400 exceeds the budget, the pages shrink to fit, and the rows equal events mode's */
    const ids = Array.from({ length: 400 }, (_, i) => BigInt(i + 1));
    const closingBlock = await f.publicClient.getBlockNumber();
    const full = await f.publicClient.estimateGas({
      to: f.activation,
      data: encodeFunctionData({ abi: activationAbi, functionName: "snapshot", args: [ids] }),
    });
    expect(full > 3_000_000n).toBe(true);
    const { rows, pages } = await rowsFromSnapshot(f.publicClient, f, { closingBlock, gasBudget: 3_000_000n, ids });
    expect(pages.length).toBeGreaterThan(1);
    expect(Math.max(...pages)).toBeLessThan(400);
    const fromEvents = await rowsFromEvents(f.publicClient, f, { fromBlock: 0n, closingBlock });
    expect(byId(rows)).toEqual(byId(fromEvents));
    expect(rows).toHaveLength(400);
  });
});
