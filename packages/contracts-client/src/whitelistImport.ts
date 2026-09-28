/**
 * The owner-imported whitelist (WL-7).
 *
 * `WhitelistImport` is the variant of the whitelist registry that MINT's admin fills itself from a
 * CSV: up to 1,000 allocations, at most two per wallet, written in batches until `closeAt` and
 * frozen for good after it. MINT deploys either this or `WhitelistClaim` (WL-3). The reads the
 * mint and the Studio allowlist need — `claimsOf`, `spotsLeft`, `claimants` — have the same names
 * and types in both, so `readClaimsOf`, `readClaimants`, `buildAllowList` and
 * `remainingWhitelistMints` work on either registry.
 *
 * The flow on MINT's admin page:
 *
 * 1. {@link parseAllocationCsv} checks the file: addresses, counts of 1 or 2, no wallet twice, at
 *    most 1,000 in all.
 * 2. {@link planImport} compares it with the chain and returns the calls that make the list equal
 *    to the file — removals first, then additions in batches. Planning again after a batch failed
 *    plans only what is still missing, so an interrupted import is simply planned and sent again.
 * 3. `executePlan` (or the facade's `whitelistImport.execute`) sends them from the owner.
 *
 * @module
 */
import { getAddress, isAddress, type Address } from "viem";

import { whitelistImportAbi } from "./abi/index.js";
import type { AnyPublicClient, Call } from "./calls.js";
import { ClientRefusal, refusal, type Refusal } from "./errors.js";
import { readClaimants } from "./whitelist.js";

/** Allocations in the whole list (WL-7, `TOTAL_SPOTS`). */
export const IMPORT_TOTAL_SPOTS = 1000;

/** Rows per `addAllocations` or `removeAllocations` call, unless the plan is given another. */
export const DEFAULT_IMPORT_BATCH = 200;

/** One row of the import: a wallet and the allocations it should hold, 1 or 2. */
export interface AllocationRow {
  wallet: Address;
  allocations: number;
}

/** `addAllocations`' contract errors, in the order the contract checks them. */
export const IMPORT_REVERTS = ["Unauthorized", "ListFrozen", "LengthMismatch", "ZeroWallet", "ZeroCount", "WalletLimit", "SoldOut"] as const;

/**
 * Parses and checks the CSV MINT imports: one `wallet,allocations` row per line, an optional
 * header, blank lines and surrounding spaces ignored.
 *
 * An address in mixed case must carry a valid checksum; an all-lowercase or all-uppercase one is
 * accepted. Every wallet is returned checksummed.
 *
 * @param text - The file's contents.
 * @returns The rows, in file order.
 * @throws {ClientRefusal} `IMPORT_INVALID_ROW` naming the line and the reason (not an address, a
 *   bad checksum, the zero address, a count other than 1 or 2, a missing or extra column);
 *   `IMPORT_DUPLICATE_WALLET` for a wallet on two lines; `IMPORT_OVER_TOTAL` above 1,000 in all.
 *
 * @example
 * ```ts
 * const rows = parseAllocationCsv(await file.text());
 * // [{ wallet: "0x1111…", allocations: 2 }, …]
 * ```
 */
export function parseAllocationCsv(text: string): AllocationRow[] {
  const rows: AllocationRow[] = [];
  const seen = new Map<string, number>();
  let total = 0;
  const lines = text.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]!.trim();
    const lineNumber = i + 1;
    if (line === "") continue;
    const cells = line.split(",").map((cell) => cell.trim());
    if (rows.length === 0 && seen.size === 0 && /^wallet$/i.test(cells[0] ?? "")) continue; // the header
    const invalid = (reason: string) => new ClientRefusal("IMPORT_INVALID_ROW", { line: lineNumber, reason });
    if (cells.length !== 2) throw invalid(`expected "wallet,allocations", found ${cells.length} column(s)`);
    const [raw, count] = cells as [string, string];
    if (!isAddress(raw, { strict: false })) throw invalid(`"${raw}" is not an address`);
    const mixedCase = raw.slice(2) !== raw.slice(2).toLowerCase() && raw.slice(2) !== raw.slice(2).toUpperCase();
    if (mixedCase && !isAddress(raw, { strict: true })) throw invalid(`"${raw}" has a bad checksum`);
    const wallet = getAddress(raw);
    if (wallet === "0x0000000000000000000000000000000000000000") throw invalid("the zero address cannot hold an allocation");
    if (!/^[12]$/.test(count)) throw invalid(`allocations must be 1 or 2, found "${count}"`);
    const key = wallet.toLowerCase();
    const first = seen.get(key);
    if (first !== undefined) throw new ClientRefusal("IMPORT_DUPLICATE_WALLET", { wallet, line: lineNumber, firstLine: first });
    seen.set(key, lineNumber);
    total += Number(count);
    rows.push({ wallet, allocations: Number(count) });
  }
  if (total > IMPORT_TOTAL_SPOTS) throw new ClientRefusal("IMPORT_OVER_TOTAL", { total, allowed: IMPORT_TOTAL_SPOTS });
  return rows;
}

/**
 * The `addAllocations` call for `rows`: each wallet gets `allocations` **more**.
 *
 * @param registry - The `WhitelistImport`'s address.
 * @param rows - The rows; the contract refuses the whole call on one bad row.
 */
export function addAllocationsCall(registry: Address, rows: readonly AllocationRow[]) {
  return {
    address: registry,
    abi: whitelistImportAbi,
    functionName: "addAllocations",
    args: [rows.map((row) => row.wallet), rows.map((row) => row.allocations)],
  } as const satisfies Call;
}

/**
 * The `removeAllocations` call: each wallet's allocations set to zero and the wallet dropped.
 *
 * @param registry - The `WhitelistImport`'s address.
 * @param wallets - Wallets that hold allocations; one that holds none refuses the call (`NotListed`).
 */
export function removeAllocationsCall(registry: Address, wallets: readonly Address[]) {
  return { address: registry, abi: whitelistImportAbi, functionName: "removeAllocations", args: [wallets] } as const satisfies Call;
}

/**
 * The `setCloseAt` call: extends the import, or freezes the list early (a close at the current
 * time freezes it from the next second).
 *
 * @param registry - The `WhitelistImport`'s address.
 * @param closeAt - The new close, Unix seconds; not in the past.
 */
export function setCloseAtCall(registry: Address, closeAt: bigint) {
  return { address: registry, abi: whitelistImportAbi, functionName: "setCloseAt", args: [Number(closeAt)] } as const satisfies Call;
}

/** The list's live state. */
export interface ImportState {
  /** Allocations still unwritten, of 1,000. */
  spotsLeft: bigint;
  /** Last Unix second the owner can write the list. */
  closeAt: bigint;
  /** Whether `closeAt` has passed: nothing can change the list any more. */
  frozen: boolean;
  /** The owner, who writes the list. */
  owner: Address;
}

/**
 * The list's live state.
 *
 * @param client - Any viem public client on the chain.
 * @param registry - The `WhitelistImport`'s address.
 */
export async function readImportState(client: AnyPublicClient, registry: Address): Promise<ImportState> {
  const [spotsLeft, closeAt, frozen, owner] = await Promise.all([
    client.readContract({ address: registry, abi: whitelistImportAbi, functionName: "spotsLeft" }),
    client.readContract({ address: registry, abi: whitelistImportAbi, functionName: "closeAt" }),
    client.readContract({ address: registry, abi: whitelistImportAbi, functionName: "frozen" }),
    client.readContract({ address: registry, abi: whitelistImportAbi, functionName: "owner" }),
  ]);
  return { spotsLeft, closeAt: BigInt(closeAt), frozen, owner };
}

/** A planned import: the calls that make the list on chain equal to the file. */
export interface ImportPlan {
  ok: true;
  /** Removals first, then additions, each at most `batchSize` rows. */
  calls: Call[];
  /** What each wallet gets added, after any removal. */
  add: AllocationRow[];
  /** Wallets removed: listed on chain but not in the file (with `removeUnlisted`), or holding more than the file says. */
  remove: Address[];
  /** Wallets on chain and not in the file that the plan leaves in place (without `removeUnlisted`). */
  unlisted: AllocationRow[];
  /** Rows already on chain as the file has them. */
  unchanged: number;
  /** Allocations the list will hold once the plan is sent. */
  total: number;
}

/** Options of {@link planImport}. */
export interface PlanImportOptions {
  /** Rows per call; default {@link DEFAULT_IMPORT_BATCH}. */
  batchSize?: number;
  /** Remove wallets that are on chain but not in the file. Default false: they are reported in `unlisted` and kept. */
  removeUnlisted?: boolean;
}

/**
 * Plans the calls that make the list on chain equal to `rows`.
 *
 * A wallet already holding what the file says is left alone; one holding less gets the difference;
 * one holding more is removed and added again with the file's count. Because the plan is made from
 * what the chain holds now, planning again after an interrupted import plans only what is missing.
 *
 * @param client - Any viem public client on the chain.
 * @param registry - The `WhitelistImport`'s address.
 * @param rows - From {@link parseAllocationCsv}.
 * @param options - Batch size, and whether to remove wallets the file does not name.
 * @returns The plan, or a refusal: `LIST_FROZEN` once `closeAt` has passed, `IMPORT_OVER_TOTAL` when
 *   the file plus the wallets kept would exceed 1,000.
 * @throws {RangeError} For a batch size below 1.
 * @throws {ClientRefusal} `IMPORT_INVALID_ROW` or `IMPORT_DUPLICATE_WALLET` for rows that break the
 *   file's rules (rows from `parseAllocationCsv` never do).
 *
 * @example
 * ```ts
 * const plan = await planImport(publicClient, addresses.registry, parseAllocationCsv(csv));
 * if (plan.ok) await executePlan(publicClient, ownerWallet, plan.calls);
 * else showError(plan.userMessage);
 * ```
 */
export async function planImport(
  client: AnyPublicClient,
  registry: Address,
  rows: readonly AllocationRow[],
  options: PlanImportOptions = {},
): Promise<ImportPlan | Refusal<"LIST_FROZEN" | "IMPORT_OVER_TOTAL">> {
  const batchSize = options.batchSize ?? DEFAULT_IMPORT_BATCH;
  if (!Number.isInteger(batchSize) || batchSize < 1) throw new RangeError("batchSize must be a positive integer");
  checkRows(rows);

  const state = await readImportState(client, registry);
  if (state.frozen) return refusal("LIST_FROZEN", { closeAt: state.closeAt });

  const onChain = new Map<string, AllocationRow>(
    (await readClaimants(client, registry)).map((row) => [row.wallet.toLowerCase(), { wallet: row.wallet, allocations: Number(row.allocations) }]),
  );
  const wanted = new Set(rows.map((row) => row.wallet.toLowerCase()));

  const add: AllocationRow[] = [];
  const remove: Address[] = [];
  let unchanged = 0;
  for (const row of rows) {
    const held = onChain.get(row.wallet.toLowerCase())?.allocations ?? 0;
    if (held === row.allocations) unchanged++;
    else if (held < row.allocations) add.push({ wallet: row.wallet, allocations: row.allocations - held });
    else {
      remove.push(row.wallet);
      add.push(row);
    }
  }
  const unlisted: AllocationRow[] = [];
  for (const row of onChain.values()) {
    if (wanted.has(row.wallet.toLowerCase())) continue;
    if (options.removeUnlisted) remove.push(row.wallet);
    else unlisted.push(row);
  }

  const total = rows.reduce((sum, row) => sum + row.allocations, 0) + unlisted.reduce((sum, row) => sum + row.allocations, 0);
  if (total > IMPORT_TOTAL_SPOTS) return refusal("IMPORT_OVER_TOTAL", { total, allowed: IMPORT_TOTAL_SPOTS });

  const calls: Call[] = [];
  for (let i = 0; i < remove.length; i += batchSize) calls.push(removeAllocationsCall(registry, remove.slice(i, i + batchSize)));
  for (let i = 0; i < add.length; i += batchSize) calls.push(addAllocationsCall(registry, add.slice(i, i + batchSize)));
  return { ok: true, calls, add, remove, unlisted, unchanged, total };
}

/**
 * The file's rules, for rows that did not come through {@link parseAllocationCsv}: `line` is the
 * row's position, from 1.
 */
function checkRows(rows: readonly AllocationRow[]): void {
  const seen = new Map<string, number>();
  rows.forEach((row, i) => {
    const line = i + 1;
    if (!isAddress(row.wallet, { strict: false }) || /^0x0{40}$/i.test(row.wallet)) {
      throw new ClientRefusal("IMPORT_INVALID_ROW", { line, reason: `"${row.wallet}" is not a wallet that can hold an allocation` });
    }
    if (row.allocations !== 1 && row.allocations !== 2) {
      throw new ClientRefusal("IMPORT_INVALID_ROW", { line, reason: `allocations must be 1 or 2, found "${row.allocations}"` });
    }
    const key = row.wallet.toLowerCase();
    const first = seen.get(key);
    if (first !== undefined) throw new ClientRefusal("IMPORT_DUPLICATE_WALLET", { wallet: getAddress(row.wallet), line, firstLine: first });
    seen.set(key, line);
  });
}

/**
 * Whether `rows` is exactly the list on chain: the same wallets with the same allocations. The check
 * to run after an import, and before the export to Studio.
 *
 * @param client - Any viem public client on the chain.
 * @param registry - The `WhitelistImport`'s address.
 * @param rows - The file's rows.
 */
export async function importMatchesChain(client: AnyPublicClient, registry: Address, rows: readonly AllocationRow[]): Promise<boolean> {
  const onChain = await readClaimants(client, registry);
  if (onChain.length !== rows.length) return false;
  const byWallet = new Map(onChain.map((row) => [row.wallet.toLowerCase(), Number(row.allocations)]));
  return rows.every((row) => byWallet.get(row.wallet.toLowerCase()) === row.allocations);
}
