import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { getAddress, type Address, type Hex } from "viem";

import {
  addAllocationsCall,
  buildAllowList,
  ClientRefusal,
  ContractRevertError,
  createMintABearClient,
  decodeSystemLogs,
  execute,
  importMatchesChain,
  IMPORT_REVERTS,
  parseAllocationCsv,
  planImport,
  readClaimants,
  readClaimsOf,
  readImportState,
  REVERT_CODES,
  type AllocationRow,
} from "../src/index.js";
import { startAnvil, type Anvil } from "./setup/anvil.js";
import { accounts, deployFixture, type Fixture } from "./setup/fixture.js";

/** A distinct, checksummed wallet for row `i`. */
const walletOf = (i: number): Address => getAddress(`0x${(0x10000 + i).toString(16).padStart(40, "0")}`);

function csv(rows: readonly AllocationRow[], header = true): string {
  return (header ? "wallet,allocations\n" : "") + rows.map((row) => `${row.wallet},${row.allocations}`).join("\n") + "\n";
}

function refusalOf(fn: () => unknown): ClientRefusal {
  try {
    fn();
  } catch (error) {
    if (error instanceof ClientRefusal) return error;
    throw error;
  }
  throw new Error("expected a ClientRefusal");
}

describe("parseAllocationCsv", () => {
  it("reads rows with or without a header, ignoring blank lines and spaces, and checksums every wallet", () => {
    /* Scenario:
       Given a CSV with a header, a blank line, spaces around cells and an all-lowercase address
       When it is parsed
       Then each row reads its wallet checksummed and its count, in file order; without the header the rows are the same */
    const lower = walletOf(1).toLowerCase();
    const text = `wallet,allocations\n\n  ${lower} , 2 \n${walletOf(2)},1\r\n`;
    const rows = parseAllocationCsv(text);
    expect(rows).toEqual([
      { wallet: walletOf(1), allocations: 2 },
      { wallet: walletOf(2), allocations: 1 },
    ]);
    expect(parseAllocationCsv(csv(rows, false))).toEqual(rows);
    expect(parseAllocationCsv("")).toEqual([]);
  });

  it("refuses an invalid row, naming its line and the reason", () => {
    /* Scenario:
       Given rows that are not an address, carry a bad checksum, name the zero address, give a count other than 1 or 2, or have the wrong number of columns
       When each file is parsed
       Then each is refused with IMPORT_INVALID_ROW, its line and a reason in the message */
    const good = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed";
    const badChecksum = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAeD";
    const cases: [string, RegExp][] = [
      ["not-an-address,1", /not an address/],
      [`${badChecksum},1`, /bad checksum/],
      ["0x0000000000000000000000000000000000000000,1", /zero address/],
      [`${good},0`, /must be 1 or 2/],
      [`${good},3`, /must be 1 or 2/],
      [`${good},one`, /must be 1 or 2/],
      [`${good}`, /1 column/],
      [`${good},1,extra`, /3 column/],
    ];
    for (const [row, reason] of cases) {
      const refused = refusalOf(() => parseAllocationCsv(`wallet,allocations\n${row}\n`));
      expect(refused.code, row).toBe("IMPORT_INVALID_ROW");
      expect(refused.details.line, row).toBe(2);
      expect(refused.userMessage, row).toMatch(reason);
      expect(refused.userMessage, row).toMatch(/^Line 2 of the whitelist file is invalid/);
    }
    expect(parseAllocationCsv(`${good.toUpperCase().replace("0X", "0x")},1`)[0]!.wallet).toBe(good);
  });

  it("refuses a wallet named twice, whatever its case, and more than 1,000 allocations in all", () => {
    /* Scenario:
       Given a file naming one wallet on two lines (once in lower case), and a file of 501 wallets of 2
       When each is parsed
       Then the first is refused with IMPORT_DUPLICATE_WALLET naming both lines, the second with IMPORT_OVER_TOTAL at 1,002 */
    const dup = refusalOf(() => parseAllocationCsv(`${walletOf(1)},1\n${walletOf(2)},1\n${walletOf(1).toLowerCase()},1\n`));
    expect(dup.code).toBe("IMPORT_DUPLICATE_WALLET");
    expect(dup.details).toMatchObject({ wallet: walletOf(1), firstLine: 1, line: 3 });
    expect(dup.userMessage).toContain("lines 1 and 3");

    const many = Array.from({ length: 501 }, (_, i) => ({ wallet: walletOf(i), allocations: 2 }));
    const over = refusalOf(() => parseAllocationCsv(csv(many)));
    expect(over.code).toBe("IMPORT_OVER_TOTAL");
    expect(over.details).toEqual({ total: 1002, allowed: 1000 });
    expect(parseAllocationCsv(csv(many.slice(0, 500)))).toHaveLength(500);
  });
});

describe("on chain", () => {
  let anvil: Anvil;
  let f: Fixture;
  let snapshot: Hex;

  beforeAll(async () => {
    anvil = await startAnvil();
    f = await deployFixture(anvil.rpcUrl);
  });
  afterAll(() => anvil.stop());
  beforeEach(async () => {
    snapshot = await f.testClient.snapshot();
  });
  afterEach(async () => {
    await f.testClient.revert({ id: snapshot });
  });

  const admin = () =>
    createMintABearClient({
      publicClient: f.publicClient,
      walletClient: f.wallet(accounts.deployer),
      addresses: { bears: f.bears, activation: f.activation, registry: f.importRegistry, mntd: f.mntd, seaDrop: f.seaDrop },
    });
  const freeze = async () => {
    await f.testClient.setNextBlockTimestamp({ timestamp: f.closeAt + 1n });
    await f.testClient.mine({ blocks: 1 });
  };
  const rows5: AllocationRow[] = [1, 2, 3, 4, 5].map((i) => ({ wallet: walletOf(i), allocations: (i % 2) + 1 }));

  it("imports a CSV in batches, and the list then matches it", async () => {
    /* Scenario:
       Given an empty WhitelistImport and a CSV of five wallets totalling 8 allocations
       When the admin plans it in batches of 2 and sends the plan
       Then three addAllocations calls are sent, the list matches the file, spotsLeft reads 992, and claimsOf reads each row's count */
    const mintabear = admin();
    const plan = await mintabear.whitelistImport.plan(csv(rows5), { batchSize: 2 });
    if (!plan.ok) throw new Error(plan.userMessage);
    expect(plan.calls.map((c) => c.functionName)).toEqual(["addAllocations", "addAllocations", "addAllocations"]);
    expect(plan.total).toBe(8);
    expect(plan.remove).toEqual([]);

    const results = await mintabear.whitelistImport.execute(plan);
    expect(results).toHaveLength(3);
    expect(await mintabear.whitelistImport.matches(rows5)).toBe(true);
    const state = await mintabear.whitelistImport.state();
    expect(state).toMatchObject({ spotsLeft: 992n, closeAt: f.closeAt, frozen: false, owner: accounts.deployer.address });
    for (const row of rows5) expect(await mintabear.whitelist.claimsOf(row.wallet)).toBe(row.allocations);

    // The events decode as the registry's.
    const added = decodeSystemLogs(results[0]!.receipt.logs, { bears: f.bears, activation: f.activation, registry: f.importRegistry });
    expect(added.map((e) => e.eventName)).toEqual(["AllocationsAdded", "AllocationsAdded"]);
    const first = added[0]!;
    if (first.emitter !== "registry" || first.eventName !== "AllocationsAdded") throw new Error("not decoded");
    expect(first.args).toEqual({ wallet: rows5[0]!.wallet, count: 2, total: 2 });
  });

  it("plans only what is missing after an interrupted import", async () => {
    /* Scenario:
       Given the first batch of a five-row import sent and the rest not
       When the admin plans the same file again
       Then the plan adds only the three rows still missing and counts two unchanged */
    const mintabear = admin();
    const plan = await planImport(f.publicClient, f.importRegistry, rows5, { batchSize: 2 });
    if (!plan.ok) throw new Error(plan.userMessage);
    await execute(f.publicClient, f.wallet(accounts.deployer), plan.calls[0]!);

    const again = await mintabear.whitelistImport.plan(rows5, { batchSize: 2 });
    if (!again.ok) throw new Error(again.userMessage);
    expect(again.unchanged).toBe(2);
    expect(again.add.map((r) => r.wallet)).toEqual(rows5.slice(2).map((r) => r.wallet));
    await mintabear.whitelistImport.execute(again);
    expect(await importMatchesChain(f.publicClient, f.importRegistry, rows5)).toBe(true);
  });

  it("corrects a changed file: a lower count is removed and re-added, a higher one topped up, an unlisted wallet kept or removed", async () => {
    /* Scenario:
       Given the five rows imported, and a new file where row 1 falls from 2 to 1, row 2 rises from 1 to 2 and row 5 is left out
       When the admin plans it, then plans it with removeUnlisted
       Then the first plan removes and re-adds row 1, tops up row 2 by 1 and reports row 5 as unlisted; the second also removes row 5, and the list then matches the new file */
    const mintabear = admin();
    await mintabear.whitelistImport.execute(await mintabear.whitelistImport.plan(rows5));
    const changed: AllocationRow[] = [
      { wallet: rows5[0]!.wallet, allocations: 1 },
      { wallet: rows5[1]!.wallet, allocations: 2 },
      ...rows5.slice(2, 4),
    ];

    const keep = await mintabear.whitelistImport.plan(changed);
    if (!keep.ok) throw new Error(keep.userMessage);
    expect(keep.remove).toEqual([rows5[0]!.wallet]);
    expect(keep.add).toEqual([
      { wallet: rows5[0]!.wallet, allocations: 1 },
      { wallet: rows5[1]!.wallet, allocations: 1 },
    ]);
    expect(keep.unlisted).toEqual([rows5[4]!]);
    expect(keep.calls.map((c) => c.functionName)).toEqual(["removeAllocations", "addAllocations"]);

    const drop = await mintabear.whitelistImport.plan(changed, { removeUnlisted: true });
    if (!drop.ok) throw new Error(drop.userMessage);
    expect(drop.remove).toEqual([rows5[0]!.wallet, rows5[4]!.wallet]);
    expect(drop.unlisted).toEqual([]);
    await mintabear.whitelistImport.execute(drop);
    expect(await mintabear.whitelistImport.matches(changed)).toBe(true);
    expect(await readClaimsOf(f.publicClient, f.importRegistry, rows5[4]!.wallet)).toBe(0);
  });

  it("refuses a plan over 1,000 counting the wallets it keeps, and any plan once frozen", async () => {
    /* Scenario:
       Given 500 wallets of 2 imported, and a file naming a new wallet only
       When the admin plans it without removeUnlisted, and then plans anything after closeAt
       Then the first is IMPORT_OVER_TOTAL at 1,002 and the second LIST_FROZEN, each with a message */
    const mintabear = admin();
    const full = Array.from({ length: 500 }, (_, i) => ({ wallet: walletOf(100 + i), allocations: 2 }));
    await mintabear.whitelistImport.execute(await mintabear.whitelistImport.plan(full));
    expect((await readImportState(f.publicClient, f.importRegistry)).spotsLeft).toBe(0n);

    const over = await mintabear.whitelistImport.plan([{ wallet: walletOf(1), allocations: 2 }]);
    expect(over).toMatchObject({ ok: false, code: "IMPORT_OVER_TOTAL", details: { total: 1002, allowed: 1000 } });

    await freeze();
    const frozen = await mintabear.whitelistImport.plan(rows5);
    expect(frozen).toMatchObject({ ok: false, code: "LIST_FROZEN" });
    if (frozen.ok) throw new Error("expected a refusal");
    expect(frozen.userMessage).toMatch(/final/);
    await expect(mintabear.whitelistImport.execute(frozen)).rejects.toMatchObject({ code: "LIST_FROZEN" });
    await expect(planImport(f.publicClient, f.importRegistry, rows5, { batchSize: 0 })).rejects.toThrow(RangeError);
  });

  it("maps the contract's refusals to codes", async () => {
    /* Scenario:
       Given the list with a wallet at 2
       When the admin adds one more to it, removes a wallet not listed, sets a close in the past, and a stranger adds a row; then after closeAt the admin adds a row
       Then each is a ContractRevertError: WALLET_LIMIT, NOT_LISTED, INVALID_WINDOW, NOT_CONTRACT_OWNER, then LIST_FROZEN */
    const mintabear = admin();
    await mintabear.whitelistImport.add([{ wallet: walletOf(1), allocations: 2 }]);

    const refused = async (promise: Promise<unknown>, code: string, errorName: string) => {
      const error = await promise.then(
        () => undefined,
        (e: unknown) => e,
      );
      expect(error, code).toBeInstanceOf(ContractRevertError);
      expect((error as ContractRevertError).code).toBe(code);
      expect((error as ContractRevertError).revert.errorName).toBe(errorName);
    };
    await refused(mintabear.whitelistImport.add([{ wallet: walletOf(1), allocations: 1 }]), "WALLET_LIMIT", "WalletLimit");
    await refused(mintabear.whitelistImport.remove([walletOf(2)]), "NOT_LISTED", "NotListed");
    await refused(mintabear.whitelistImport.setCloseAt(1n), "INVALID_WINDOW", "InvalidWindow");
    const stranger = createMintABearClient({
      publicClient: f.publicClient,
      walletClient: f.wallet(accounts.alice),
      addresses: { bears: f.bears, activation: f.activation, registry: f.importRegistry, mntd: f.mntd },
    });
    await refused(stranger.whitelistImport.add([{ wallet: walletOf(3), allocations: 1 }]), "NOT_CONTRACT_OWNER", "Unauthorized");

    await mintabear.whitelistImport.setCloseAt(f.closeAt + 86_400n);
    expect((await mintabear.whitelistImport.state()).closeAt).toBe(f.closeAt + 86_400n);
    await f.testClient.setNextBlockTimestamp({ timestamp: f.closeAt + 86_401n });
    await f.testClient.mine({ blocks: 1 });
    await refused(execute(f.publicClient, f.wallet(accounts.deployer), addAllocationsCall(f.importRegistry, [{ wallet: walletOf(4), allocations: 1 }])), "LIST_FROZEN", "ListFrozen");
    expect((await mintabear.whitelistImport.state()).frozen).toBe(true);
  });

  it("builds the Studio allowlist from a frozen import as from a claim registry", async () => {
    /* Scenario:
       Given the five rows imported and the list frozen
       When the claimants are read and the allowlist is built
       Then the rows equal the file and every row has an entry whose limit is its allocations */
    const mintabear = admin();
    await mintabear.whitelistImport.execute(await mintabear.whitelistImport.plan(rows5));
    await freeze();
    const onChain = await readClaimants(f.publicClient, f.importRegistry);
    expect(onChain.map((r) => ({ wallet: r.wallet, allocations: Number(r.allocations) }))).toEqual(rows5);
    const stage = {
      mintPrice: 0n,
      startTime: f.closeAt + 2n * 86_400n,
      endTime: f.closeAt + 3n * 86_400n,
      dropStageIndex: 1n,
      maxTokenSupplyForStage: 4444n,
      feeBps: 0n,
      restrictFeeRecipients: false,
    };
    const allowList = await mintabear.whitelist.allowList(stage);
    expect(allowList.root).toBe(buildAllowList(onChain, stage).root);
    for (const row of rows5) expect(allowList.entry(row.wallet)?.mintParams.maxTotalMintableByWallet).toBe(BigInt(row.allocations));
  });

  it("documents a code for every addAllocations revert", () => {
    /* Scenario:
       Given the reverts addAllocations can raise
       When each is mapped
       Then each has a code other than UNKNOWN_REVERT */
    for (const name of IMPORT_REVERTS) expect(REVERT_CODES[name], name).toBeDefined();
    for (const name of ["NotListed", "InvalidWindow"]) expect(REVERT_CODES[name], name).toBeDefined();
  });
});
