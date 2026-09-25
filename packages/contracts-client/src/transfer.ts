import { zeroAddress, type Address, type Chain, type PublicClient, type Transport } from "viem";

import { mintABearAbi } from "./abi/index.js";
import { readCumulative, readLevel, readLink, type ActivationAddresses } from "./activation.js";
import type { Call } from "./calls.js";
import { ClientRefusal } from "./errors.js";

type Client = PublicClient<Transport, Chain | undefined>;

/** Something the sender should confirm before a transfer. */
export type TransferWarning =
  /** The bear is activated: the transfer resets its level to 0 and its cumulative burn with it, whoever receives it. */
  | { code: "RESETS_LEVEL"; level: number; cumulative: bigint }
  /** The owner's wallet links this bear: the transfer voids the link and the owner's Status boost. */
  | { code: "VOIDS_LINK" };

export interface TransferArgs {
  from: Address;
  to: Address;
  tokenId: bigint;
  /** `safeTransferFrom` instead of `transferFrom` (checks a contract recipient accepts ERC-721). */
  safe?: boolean;
}

/** The raw `transferFrom` / `safeTransferFrom` call, unguarded. */
export function transferCall(a: Pick<ActivationAddresses, "bears">, t: TransferArgs) {
  return t.safe
    ? ({ address: a.bears, abi: mintABearAbi, functionName: "safeTransferFrom", args: [t.from, t.to, t.tokenId] } as const satisfies Call)
    : ({ address: a.bears, abi: mintABearAbi, functionName: "transferFrom", args: [t.from, t.to, t.tokenId] } as const satisfies Call);
}

/**
 * A transfer checked before it is offered. Refused outright (`ClientRefusal`): `from == to`, which
 * moves nothing yet resets the bear, and the zero address, which the collection refuses with
 * `BurnDisabled`. Warned: an activated bear loses its level and a linked bear its link — on every
 * transfer, a self-transfer and an approved operator's included (COL-3, ACT-5).
 */
export async function planTransfer(client: Client, a: Omit<ActivationAddresses, "mntd">, t: TransferArgs) {
  if (t.from.toLowerCase() === t.to.toLowerCase()) {
    throw new ClientRefusal("SELF_TRANSFER", "A transfer to the same wallet moves nothing but resets the bear's level and link.");
  }
  if (t.to.toLowerCase() === zeroAddress) {
    throw new ClientRefusal("ZERO_ADDRESS", "Bears cannot be burned or sent to the zero address (BurnDisabled).");
  }
  const [level, cumulative, link] = await Promise.all([
    readLevel(client, a, t.tokenId),
    readCumulative(client, a, t.tokenId),
    readLink(client, a, t.from),
  ]);
  const warnings: TransferWarning[] = [];
  if (cumulative > 0n) warnings.push({ code: "RESETS_LEVEL", level, cumulative });
  if (link.tokenId === t.tokenId) warnings.push({ code: "VOIDS_LINK" });
  return { call: transferCall(a, t), warnings };
}
