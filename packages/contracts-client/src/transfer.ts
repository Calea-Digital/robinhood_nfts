/**
 * Transfers, guarded.
 *
 * Every transfer resets the bear — its level and its cumulative burn — a self-transfer and an approved operator's transfer included (COL-3, ACT-5). {@link planTransfer}
 * refuses the two transfers that are always mistakes and warns about the ones that cost something.
 *
 * @module
 */
import { zeroAddress, type Address } from "viem";

import { mintABearAbi } from "./abi/index.js";
import { readCumulative, readLevel, type ActivationAddresses } from "./activation.js";
import type { MintABearAddresses } from "./addresses.js";
import type { AnyPublicClient, Call } from "./calls.js";
import { ClientRefusal } from "./errors.js";

/** Something the sender should confirm before a transfer. */
export type TransferWarning =
  /** The bear is activated: the transfer resets its level to 0 and its cumulative burn with it, whoever receives it. */
  | { code: "RESETS_LEVEL"; level: number; cumulative: bigint; message: string };

/** Arguments of {@link planTransfer} and {@link transferCall}. */
export interface TransferArgs {
  /** The bear's owner. */
  from: Address;
  /** The recipient. */
  to: Address;
  /** The bear. */
  tokenId: bigint;
  /** Use `safeTransferFrom`, which checks that a contract recipient accepts ERC-721. */
  safe?: boolean;
}

/**
 * The raw `transferFrom` / `safeTransferFrom` call, unguarded. Prefer {@link planTransfer}.
 * @param addresses - Where the collection is.
 * @param args - From, to, the bear, and whether to use `safeTransferFrom`.
 */
export function transferCall(addresses: Pick<MintABearAddresses, "bears">, args: TransferArgs) {
  return args.safe
    ? ({ address: addresses.bears, abi: mintABearAbi, functionName: "safeTransferFrom", args: [args.from, args.to, args.tokenId] } as const satisfies Call)
    : ({ address: addresses.bears, abi: mintABearAbi, functionName: "transferFrom", args: [args.from, args.to, args.tokenId] } as const satisfies Call);
}

/** A transfer, checked. */
export interface TransferPlan {
  /** The call to send. */
  call: Call;
  /** Show these and ask the sender to confirm before sending. */
  warnings: TransferWarning[];
}

/**
 * Checks a transfer before it is offered.
 *
 * @param client - Any viem public client on the chain.
 * @param addresses - Where `Activation` and the collection are.
 * @param args - From, to, the bear.
 * @returns The call and its warnings: `RESETS_LEVEL` for a bear with $MNTD burned into it.
 * @throws {ClientRefusal} `SELF_TRANSFER` when `from == to` (it moves nothing but resets the bear);
 *   `BURN_DISABLED` for the zero address (the collection refuses it too).
 *
 * @example
 * ```ts
 * const plan = await planTransfer(client, addresses, { from: me, to: buyer, tokenId: 7n });
 * if (plan.warnings.length && !(await confirm(plan.warnings.map((w) => w.message)))) return;
 * await execute(client, wallet, plan.call);
 * ```
 */
export async function planTransfer(client: AnyPublicClient, addresses: Omit<ActivationAddresses, "mntd">, args: TransferArgs): Promise<TransferPlan> {
  if (args.from.toLowerCase() === args.to.toLowerCase()) throw new ClientRefusal("SELF_TRANSFER", { tokenId: args.tokenId });
  if (args.to.toLowerCase() === zeroAddress) throw new ClientRefusal("BURN_DISABLED", { tokenId: args.tokenId });
  const [level, cumulative] = await Promise.all([readLevel(client, addresses, args.tokenId), readCumulative(client, addresses, args.tokenId)]);
  const warnings: TransferWarning[] = [];
  if (cumulative > 0n) {
    warnings.push({
      code: "RESETS_LEVEL",
      level,
      cumulative,
      message: `Bear #${args.tokenId} is at level ${level}. Transferring it resets it to level 0 for the recipient, and the $MNTD burned into it is not refunded.`,
    });
  }
  return { call: transferCall(addresses, args), warnings };
}
