/**
 * The royalty split's inputs: each bear's owner and weight at the closing block, from an archive
 * node. Two ways to read them, which agree:
 *
 * - {@link rowsFromEvents} (default): owners from the collection's `Transfer` logs, weights from
 *   `weightOf` at the block. Flat cost.
 * - {@link rowsFromSnapshot}: `Activation.snapshot`, paged by a gas budget. Its cost grows with the
 *   square of a long untransferred mint batch.
 *
 * On Robinhood Chain the closing block is the chain's own block number, not `block.number`
 * inside a contract (which reads L1).
 *
 * @module
 */
import { decodeFunctionResult, encodeFunctionData, getAbiItem, zeroAddress, type Address } from "viem";

import { activationAbi, mintABearAbi } from "../abi/index.js";
import type { AnyPublicClient } from "../calls.js";
import { MAX_BEARS } from "../constants.js";
import { ClientRefusal } from "../errors.js";
import type { BearRow } from "./compute.js";

type Client = AnyPublicClient;

const transferEvent = getAbiItem({ abi: mintABearAbi, name: "Transfer" });
const consecutiveTransferEvent = getAbiItem({ abi: mintABearAbi, name: "ConsecutiveTransfer" });

/** Arguments of {@link rowsFromEvents}. */
export interface EventsModeArgs {
  /** The collection's deployment block: no bear moved before it. */
  fromBlock: bigint;
  /** The closing block, inclusive. On Robinhood Chain this is the chain's own block number, not `block.number` (which reads L1). */
  closingBlock: bigint;
  /** Blocks per `eth_getLogs` request; lower it for RPCs that cap the range. */
  blockRange?: bigint;
  /** `weightOf` reads in flight at once. */
  concurrency?: number;
}

/**
 * Each bear's owner at the closing block, from the collection's indexed `Transfer` events: the
 * last recipient of each id. `ConsecutiveTransfer` (ERC-2309) is applied too, though SeaDrop's
 * mint path does not emit it. No `ownerOf` walk, so collecting owners does not grow with mint
 * batches; {@link rowsFromEvents} then checks each one against `ownerOf`.
 *
 * @param client - A viem public client.
 * @param bears - The collection's address.
 * @param a - The deployment block, the closing block, and blocks per request.
 * @returns Each owned token id with its owner.
 */
export async function ownersFromTransferLogs(
  client: Client,
  bears: Address,
  a: Pick<EventsModeArgs, "fromBlock" | "closingBlock" | "blockRange">,
): Promise<Map<bigint, Address>> {
  const owners = new Map<bigint, Address>();
  const range = a.blockRange ?? 10_000n;
  for (let from = a.fromBlock; from <= a.closingBlock; from += range) {
    const to = from + range - 1n < a.closingBlock ? from + range - 1n : a.closingBlock;
    const logs = await client.getLogs({ address: bears, events: [transferEvent, consecutiveTransferEvent], fromBlock: from, toBlock: to, strict: true });
    logs.sort((x, y) => (x.blockNumber === y.blockNumber ? x.logIndex - y.logIndex : x.blockNumber < y.blockNumber ? -1 : 1));
    for (const log of logs) {
      if (log.eventName === "Transfer") {
        owners.set(log.args.tokenId, log.args.to);
      } else {
        for (let id = log.args.fromTokenId; id <= log.args.toTokenId; id++) owners.set(id, log.args.to);
      }
    }
  }
  for (const [id, owner] of owners) if (owner === zeroAddress) owners.delete(id);
  return owners;
}

/**
 * Split inputs, mode (a): owners from `Transfer` events up to the closing block, weights from
 * `weightOf` at that block — only for ids that have an owner. Each owner from the logs is checked
 * against `ownerOf` at the closing block, so a log the RPC dropped cannot pay a previous holder. `weightOf` answers 100 for an id
 * never minted, so summing it over the whole 1..4,444 range before sell-out would count phantom
 * bears. Needs an archive node for reads at a past block.
 *
 * @param client - A viem public client on an archive node.
 * @param c - Where the collection and `Activation` are.
 * @param a - The deployment block, the closing block, and paging.
 * @returns One row per owned bear, ascending by id.
 * @throws {ClientRefusal} `SPLIT_MISSING_BEARS` unless the owners found equal `totalSupply` at the
 *   closing block — a late `fromBlock` or a truncated log read would otherwise drop bears silently;
 *   `SPLIT_OWNER_MISMATCH` when a bear's last recipient in the logs is not its `ownerOf` at the
 *   closing block — a dropped resale log would otherwise pay the seller.
 */
export async function rowsFromEvents(
  client: Client,
  c: { bears: Address; activation: Address },
  a: EventsModeArgs,
): Promise<BearRow[]> {
  const [owners, totalSupply] = await Promise.all([
    ownersFromTransferLogs(client, c.bears, a),
    client.readContract({ address: c.bears, abi: mintABearAbi, functionName: "totalSupply", blockNumber: a.closingBlock }),
  ]);
  // A fromBlock after the first mint, or an RPC that silently truncates getLogs, would drop bears
  // and underpay their owners; no bear can be burned, so every minted id has an owner.
  if (BigInt(owners.size) !== totalSupply) {
    throw new ClientRefusal("SPLIT_MISSING_BEARS", { owned: owners.size, totalSupply, closingBlock: a.closingBlock });
  }
  const ids = [...owners.keys()].filter((id) => id >= 1n && id <= BigInt(MAX_BEARS)).sort((x, y) => (x < y ? -1 : 1));
  const rows: BearRow[] = [];
  const concurrency = a.concurrency ?? 50;
  for (let i = 0; i < ids.length; i += concurrency) {
    const batch = ids.slice(i, i + concurrency);
    const [weights, onChain] = await Promise.all([
      Promise.all(
        batch.map((id) =>
          client.readContract({ address: c.activation, abi: activationAbi, functionName: "weightOf", args: [id], blockNumber: a.closingBlock }),
        ),
      ),
      Promise.all(
        batch.map((id) => client.readContract({ address: c.bears, abi: mintABearAbi, functionName: "ownerOf", args: [id], blockNumber: a.closingBlock })),
      ),
    ]);
    batch.forEach((id, j) => {
      const fromLogs = owners.get(id)!;
      if (fromLogs.toLowerCase() !== onChain[j]!.toLowerCase()) {
        throw new ClientRefusal("SPLIT_OWNER_MISMATCH", { tokenId: id, fromLogs, onChain: onChain[j], closingBlock: a.closingBlock });
      }
      rows.push({ tokenId: id, owner: fromLogs, weight: weights[j]! });
    });
  }
  return rows;
}

// Encoded by hand: viem's typed estimateContractGas and readContract take no gas cap for a view.
const snapshotData = (ids: readonly bigint[]) => encodeFunctionData({ abi: activationAbi, functionName: "snapshot", args: [ids] });

/** Arguments of {@link rowsFromSnapshot}. */
export interface SnapshotModeArgs {
  closingBlock: bigint;
  /** Most gas one `snapshot` call may use. Default 30M, under common `eth_call` caps. */
  gasBudget?: bigint;
  /** The ids to read. Default exactly 1..4,444, each once. */
  ids?: readonly bigint[];
  /** Largest page tried. */
  maxPage?: number;
}

/**
 * Split inputs, mode (b): `Activation.snapshot` at the closing block, paged by a **gas budget**, not
 * a fixed count. `snapshot` reads every id's owner, and the collection's `ownerOf` walks back to the
 * start of an untransferred mint batch, so a page's cost grows with the square of such a batch:
 * measured 56.2M gas for 1..4,444 at two bears per wallet, and a long batch runs out of gas at any
 * fixed size. Each page is estimated first and halved until it fits; after a page fits, the next
 * tries twice the size. Rows with no owner (ids never minted) are dropped.
 *
 * @param client - A viem public client on an archive node.
 * @param c - Where `Activation` is.
 * @param a - The closing block, the gas budget, and the ids (default 1..4,444).
 * @returns The owned rows, and the size of each page read.
 * @throws {ClientRefusal} `SPLIT_INVALID_INPUT` for duplicate ids; `SPLIT_GAS_BUDGET` when a single
 *   id does not fit the budget (the RPC's own error is the `cause`).
 */
export async function rowsFromSnapshot(
  client: Client,
  c: { activation: Address },
  a: SnapshotModeArgs,
): Promise<{ rows: BearRow[]; pages: number[] }> {
  const ids = a.ids ?? Array.from({ length: MAX_BEARS }, (_, i) => BigInt(i + 1));
  if (new Set(ids).size !== ids.length) {
    throw new ClientRefusal("SPLIT_INVALID_INPUT", { reason: "The snapshot ids contain duplicates; snapshot would return duplicate rows." });
  }
  const budget = a.gasBudget ?? 30_000_000n;
  const maxPage = a.maxPage ?? 1_000;
  const rows: BearRow[] = [];
  const pages: number[] = [];
  let size = Math.min(maxPage, ids.length);
  for (let start = 0; start < ids.length; ) {
    const page = ids.slice(start, start + size);
    let fits = false;
    let failure: unknown;
    try {
      const gas = await client.estimateGas({ to: c.activation, data: snapshotData(page), blockNumber: a.closingBlock, account: zeroAddress });
      fits = gas <= budget;
    } catch (error) {
      failure = error; // out of gas under the node's cap, or the RPC refused the estimate
    }
    if (!fits) {
      if (page.length === 1) {
        throw new ClientRefusal("SPLIT_GAS_BUDGET", { tokenId: page[0], gasBudget: budget }, failure);
      }
      size = Math.max(1, Math.floor(page.length / 2));
      continue;
    }
    const { data } = await client.call({ to: c.activation, data: snapshotData(page), blockNumber: a.closingBlock, gas: budget });
    const result = decodeFunctionResult({ abi: activationAbi, functionName: "snapshot", data: data! });
    result.forEach((row, j) => {
      if (row.owner !== zeroAddress) rows.push({ tokenId: page[j]!, owner: row.owner, weight: row.weight });
    });
    pages.push(page.length);
    start += page.length;
    size = Math.min(maxPage, page.length * 2);
  }
  return { rows, pages };
}
