/**
 * Events and indexing.
 *
 * The rules an indexer follows:
 *
 * - **Decode by emitter.** The collection's ERC-721 `Transfer(from, to, tokenId)` and $MNTD's ERC-20
 *   `Transfer(from, to, value)` share one topic; a burn transaction carries $MNTD's
 *   `Transfer(holder, 0x0, amount)` beside `BearActivated`. Decoded by topic alone it would read as a
 *   bear sent to the zero address. {@link decodeSystemLogs} decodes each log only with the ABI of the
 *   contract that emitted it.
 * - **`TransferNonceAdvanced(tokenId, nonce)` is the reset.** It fires on every transfer, never on
 *   mint, and precedes the collection's `Transfer` in the same transaction. Void the bear's level
 *   there.
 * - `BearActivated(tokenId, burner, previousLevel, newLevel, amount, cumulative)` carries no `ref`.
 *
 * {@link ReferenceIndexer} is these rules in code; its tests check it against the contracts.
 *
 * @module
 */
import { erc20Abi, parseEventLogs, type Abi, type Address, type Hash, type Log, type ParseEventLogsReturnType } from "viem";

import { activationAbi, mintABearAbi, whitelistClaimAbi, whitelistImportAbi } from "./abi/index.js";
import type { MintABearAddresses } from "./addresses.js";
import type { AnyPublicClient } from "./calls.js";

/** The contracts whose events are read. `registry` (either `WhitelistClaim` or `WhitelistImport`) and `mntd` are optional. */
export type SystemAddresses = Pick<MintABearAddresses, "bears" | "activation"> & Partial<Pick<MintABearAddresses, "registry" | "mntd">>;

/** Which contract emitted an event. */
export type EmitterName = "bears" | "activation" | "registry" | "mntd";

type Decoded<A extends Abi> = ParseEventLogsReturnType<A, undefined, true>[number];
type Tagged<E extends EmitterName, A extends Abi> =
  Decoded<A> extends infer D
    ? D extends { eventName: infer N; args: infer R }
      ? { emitter: E; eventName: N; args: R; blockNumber: bigint; logIndex: number; transactionHash: Hash }
      : never
    : never;

/**
 * A decoded event, with the contract that emitted it and its place in the chain. It is a union keyed
 * by `emitter` and `eventName`, so checking both narrows `args` to that event's typed arguments.
 *
 * @example
 * ```ts
 * if (e.emitter === "activation" && e.eventName === "BearActivated") e.args.newLevel; // number
 * ```
 */
export type SystemEvent =
  | Tagged<"bears", typeof mintABearAbi>
  | Tagged<"activation", typeof activationAbi>
  | Tagged<"registry", typeof whitelistClaimAbi>
  | Tagged<"registry", typeof whitelistImportAbi>
  | Tagged<"mntd", typeof erc20Abi>;

const ABIS: Record<EmitterName, Abi> = {
  bears: mintABearAbi,
  activation: activationAbi,
  // Either registry: `WhitelistClaim`'s events, then `WhitelistImport`'s (their shared ownership
  // events decode the same either way).
  registry: [...whitelistClaimAbi, ...whitelistImportAbi.filter((item) => item.type === "event")],
  mntd: erc20Abi,
};

/**
 * Decodes `logs` by emitter, in chain order. Logs from any other address are dropped.
 *
 * @param logs - Raw logs (a receipt's, or `eth_getLogs`').
 * @param addresses - The contracts to decode; `mntd` to include the token's events.
 * @returns The decoded events, ordered by block and log index.
 */
export function decodeSystemLogs(logs: readonly Log[], addresses: SystemAddresses): SystemEvent[] {
  const events: SystemEvent[] = [];
  for (const emitter of Object.keys(ABIS) as EmitterName[]) {
    const address = addresses[emitter];
    if (!address) continue;
    const own = logs.filter((log) => log.address.toLowerCase() === address.toLowerCase());
    for (const e of parseEventLogs({ abi: ABIS[emitter], logs: own as Log[], strict: true })) {
      events.push({
        emitter,
        eventName: e.eventName,
        args: e.args,
        blockNumber: e.blockNumber!,
        logIndex: e.logIndex!,
        transactionHash: e.transactionHash!,
      } as SystemEvent);
    }
  }
  return events.sort((x, y) => (x.blockNumber === y.blockNumber ? x.logIndex - y.logIndex : x.blockNumber < y.blockNumber ? -1 : 1));
}

/**
 * Reads and decodes every event of the system between two blocks.
 *
 * @param client - Any viem public client on the chain.
 * @param addresses - The contracts to read.
 * @param fromBlock - First block, inclusive (the deployment block).
 * @param toBlock - Last block, inclusive; default the latest.
 */
export async function readSystemEvents(client: AnyPublicClient, addresses: SystemAddresses, fromBlock: bigint, toBlock?: bigint): Promise<SystemEvent[]> {
  const address = (Object.keys(ABIS) as EmitterName[]).map((k) => addresses[k]).filter((a): a is Address => a !== undefined);
  const logs = await client.getLogs({ address, fromBlock, toBlock });
  return decodeSystemLogs(logs, addresses);
}

/**
 * A reference indexer: the state an off-chain service keeps from the events, equal to what the
 * contracts answer. Feed it events in chain order; read `levelOf`.
 *
 * @example
 * ```ts
 * const indexer = new ReferenceIndexer().applyAll(await readSystemEvents(client, addresses, deployBlock));
 * indexer.levelOf(7n);            // as Activation.levelOf answers
 * ```
 */
export class ReferenceIndexer {
  /** Each bear's owner. */
  readonly owners = new Map<bigint, Address>();
  /** Each activated bear's level and cumulative burn under its current owner. */
  readonly levels = new Map<bigint, { level: number; cumulative: bigint }>();

  /** Applies one event. */
  apply(event: SystemEvent): void {
    if (event.emitter === "bears") {
      if (event.eventName === "TransferNonceAdvanced") {
        this.levels.delete(event.args.tokenId);
      } else if (event.eventName === "Transfer") {
        this.owners.set(event.args.tokenId, event.args.to);
      }
    } else if (event.emitter === "activation" && event.eventName === "BearActivated") {
      this.levels.set(event.args.tokenId, { level: event.args.newLevel, cumulative: event.args.cumulative });
    }
  }

  /** Applies events in order; returns the indexer. */
  applyAll(events: readonly SystemEvent[]): this {
    for (const event of events) this.apply(event);
    return this;
  }

  /** The bear's level, as `levelOf` answers it. */
  levelOf(tokenId: bigint): number {
    return this.levels.get(tokenId)?.level ?? 0;
  }
}
