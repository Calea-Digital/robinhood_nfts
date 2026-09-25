import { erc20Abi, parseEventLogs, type Abi, type Address, type Chain, type Log, type PublicClient, type Transport } from "viem";

import { activationAbi, mintABearAbi, whitelistClaimAbi } from "./abi/index.js";

type Client = PublicClient<Transport, Chain | undefined>;

/** The contracts whose events an indexer follows. `registry` and `mntd` are optional. */
export interface SystemAddresses {
  bears: Address;
  activation: Address;
  registry?: Address;
  mntd?: Address;
}

export type EmitterName = "bears" | "activation" | "registry" | "mntd";

/** A decoded event with the contract that emitted it and its position in the chain. */
export interface SystemEvent {
  emitter: EmitterName;
  eventName: string;
  args: Record<string, unknown>;
  blockNumber: bigint;
  logIndex: number;
  transactionHash: `0x${string}`;
}

const ABIS: Record<EmitterName, Abi> = {
  bears: mintABearAbi,
  activation: activationAbi,
  registry: whitelistClaimAbi,
  mntd: erc20Abi,
};

/**
 * Decodes `logs` by **emitter**: each log is decoded only with the ABI of the contract at its
 * address, and logs from any other address are dropped. This matters because the collection's
 * ERC-721 `Transfer(from, to, tokenId)` and $MNTD's ERC-20 `Transfer(from, to, value)` share one
 * topic — a burn transaction carries $MNTD's `Transfer(holder, 0x0, amount)` beside
 * `BearActivated`, and decoding by topic alone would read it as a bear moving to the zero address.
 * The result is in chain order.
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
        args: e.args as Record<string, unknown>,
        blockNumber: e.blockNumber!,
        logIndex: e.logIndex!,
        transactionHash: e.transactionHash!,
      });
    }
  }
  return events.sort((x, y) => (x.blockNumber === y.blockNumber ? x.logIndex - y.logIndex : x.blockNumber < y.blockNumber ? -1 : 1));
}

/** Reads and decodes every event of the system between two blocks. */
export async function readSystemEvents(
  client: Client,
  addresses: SystemAddresses,
  fromBlock: bigint,
  toBlock?: bigint,
): Promise<SystemEvent[]> {
  const address = (Object.keys(ABIS) as EmitterName[]).map((k) => addresses[k]).filter((a): a is Address => a !== undefined);
  const logs = await client.getLogs({ address, fromBlock, toBlock });
  return decodeSystemLogs(logs, addresses);
}

/**
 * A reference indexer: the state an off-chain service keeps from the events, equal to what the
 * contracts answer.
 *
 * - `TransferNonceAdvanced(tokenId, nonce)` is the reset. It precedes the collection's `Transfer`
 *   in the same transaction. It voids the bear's level and every wallet's link to that bear.
 * - `BearActivated` sets the level; `BearLinked` sets (and replaces) a wallet's link — a new link
 *   comes without a `BearUnlinked` for the old bear.
 * - `BearUnlinked` for a link already voided by a reset is a no-op.
 * - $MNTD's events and anything else are ignored.
 *
 * How several wallets' links combine for one account is MINT's Status service's rule (CQ-21);
 * the indexer keeps one link per wallet.
 */
export class ReferenceIndexer {
  readonly owners = new Map<bigint, Address>();
  readonly levels = new Map<bigint, { level: number; cumulative: bigint }>();
  readonly links = new Map<Address, bigint>();

  apply(event: SystemEvent): void {
    const a = event.args;
    if (event.emitter === "bears") {
      if (event.eventName === "TransferNonceAdvanced") {
        const tokenId = a.tokenId as bigint;
        this.levels.delete(tokenId);
        for (const [wallet, linked] of this.links) if (linked === tokenId) this.links.delete(wallet);
      } else if (event.eventName === "Transfer") {
        this.owners.set(a.tokenId as bigint, a.to as Address);
      }
    } else if (event.emitter === "activation") {
      if (event.eventName === "BearActivated") {
        this.levels.set(a.tokenId as bigint, { level: a.newLevel as number, cumulative: a.cumulative as bigint });
      } else if (event.eventName === "BearLinked") {
        this.links.set(a.wallet as Address, a.tokenId as bigint);
      } else if (event.eventName === "BearUnlinked") {
        // Its tokenId is always the wallet's last BearLinked bear, which this map holds or a reset
        // has already removed; for a voided link the delete finds nothing.
        this.links.delete(a.wallet as Address);
      }
    }
  }

  applyAll(events: readonly SystemEvent[]): this {
    for (const event of events) this.apply(event);
    return this;
  }

  /** The bear's level as `levelOf` answers it. */
  levelOf(tokenId: bigint): number {
    return this.levels.get(tokenId)?.level ?? 0;
  }

  /** The wallet's link as `linkOf` answers it: the bear and its level, or zeroes. */
  linkOf(wallet: Address): { tokenId: bigint; level: number } {
    const tokenId = this.links.get(wallet);
    return tokenId === undefined ? { tokenId: 0n, level: 0 } : { tokenId, level: this.levelOf(tokenId) };
  }
}
