import { decodeFunctionResult, encodeFunctionData, getAbiItem, zeroAddress, type Address, type Chain, type PublicClient, type Transport } from "viem";

import { activationAbi, mintABearAbi } from "../abi/index.js";
import { MAX_BEARS } from "../constants.js";
import type { BearRow } from "./compute.js";

type Client = PublicClient<Transport, Chain | undefined>;

const transferEvent = getAbiItem({ abi: mintABearAbi, name: "Transfer" });
const consecutiveTransferEvent = getAbiItem({ abi: mintABearAbi, name: "ConsecutiveTransfer" });

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
 * mint path does not emit it. No `ownerOf` walk, so the cost does not grow with mint batches.
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
 * `weightOf` at that block — only for ids that have an owner. `weightOf` answers 100 for an id
 * never minted, so summing it over the whole 1..4,444 range before sell-out would count phantom
 * bears. Needs an archive node for reads at a past block.
 */
export async function rowsFromEvents(
  client: Client,
  c: { bears: Address; activation: Address },
  a: EventsModeArgs,
): Promise<BearRow[]> {
  const owners = await ownersFromTransferLogs(client, c.bears, a);
  const ids = [...owners.keys()].filter((id) => id >= 1n && id <= BigInt(MAX_BEARS)).sort((x, y) => (x < y ? -1 : 1));
  const rows: BearRow[] = [];
  const concurrency = a.concurrency ?? 50;
  for (let i = 0; i < ids.length; i += concurrency) {
    const batch = ids.slice(i, i + concurrency);
    const weights = await Promise.all(
      batch.map((id) =>
        client.readContract({ address: c.activation, abi: activationAbi, functionName: "weightOf", args: [id], blockNumber: a.closingBlock }),
      ),
    );
    batch.forEach((id, j) => rows.push({ tokenId: id, owner: owners.get(id)!, weight: weights[j]! }));
  }
  return rows;
}

// Encoded by hand: viem's typed estimateContractGas and readContract take no gas cap for a view.
const snapshotData = (ids: readonly bigint[]) => encodeFunctionData({ abi: activationAbi, functionName: "snapshot", args: [ids] });

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
 */
export async function rowsFromSnapshot(
  client: Client,
  c: { activation: Address },
  a: SnapshotModeArgs,
): Promise<{ rows: BearRow[]; pages: number[] }> {
  const ids = a.ids ?? Array.from({ length: MAX_BEARS }, (_, i) => BigInt(i + 1));
  if (new Set(ids).size !== ids.length) throw new Error("snapshot ids contain duplicates; snapshot would return duplicate rows");
  const budget = a.gasBudget ?? 30_000_000n;
  const maxPage = a.maxPage ?? 1_000;
  const rows: BearRow[] = [];
  const pages: number[] = [];
  let size = Math.min(maxPage, ids.length);
  for (let start = 0; start < ids.length; ) {
    const page = ids.slice(start, start + size);
    let fits = false;
    try {
      const gas = await client.estimateGas({ to: c.activation, data: snapshotData(page), blockNumber: a.closingBlock, account: zeroAddress });
      fits = gas <= budget;
    } catch {
      fits = false; // out of gas under the node's cap
    }
    if (!fits) {
      if (page.length === 1) throw new Error(`snapshot of id ${page[0]} alone exceeds the gas budget ${budget}`);
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
