import { erc20Abi, type Address, type Chain, type PublicClient, type Transport } from "viem";

import { activationAbi, mintABearAbi } from "./abi/index.js";
import type { Call } from "./calls.js";
import { MAX_LEVEL } from "./constants.js";

type Client = PublicClient<Transport, Chain | undefined>;

/** The contracts a burn touches: `Activation`, the collection it reads, and $MNTD. */
export interface ActivationAddresses {
  activation: Address;
  bears: Address;
  mntd: Address;
}

/**
 * `burn`'s reverts in the order the contract checks them (ACT-4, ACT-8). Besides these: an id
 * never minted reverts with the collection's `OwnerQueryForNonexistentToken`, not `NotBearOwner`;
 * the $MNTD token's own reverts for a short allowance or balance come from `burnFrom` after the
 * record is written, and undo it; `Reentrancy` never happens in normal use.
 */
export const BURN_REVERTS = ["ContractPaused", "ZeroAmount", "NotBearOwner", "AlreadyAtMaxLevel", "Overshoot"] as const;

/** `linkBear`'s reverts: `ContractPaused`, `NotBearOwner`; an unminted id reverts `OwnerQueryForNonexistentToken`. */
export const LINK_REVERTS = ["ContractPaused", "NotBearOwner"] as const;

// ---------------------------------------------------------------------------------------------
// Reads (ACT-14, COL-12)
// ---------------------------------------------------------------------------------------------

const act = (a: Pick<ActivationAddresses, "activation">) => ({ address: a.activation, abi: activationAbi }) as const;
const col = (a: Pick<ActivationAddresses, "bears">) => ({ address: a.bears, abi: mintABearAbi }) as const;

/** A bear's current level, 0–5; zero after any transfer. */
export const readLevel = (client: Client, a: Pick<ActivationAddresses, "activation">, tokenId: bigint) =>
  client.readContract({ ...act(a), functionName: "levelOf", args: [tokenId] });

/** $MNTD burned for a bear under its current owner, in base units; zero after any transfer. */
export const readCumulative = (client: Client, a: Pick<ActivationAddresses, "activation">, tokenId: bigint) =>
  client.readContract({ ...act(a), functionName: "cumulativeOf", args: [tokenId] });

/** $MNTD ever burned for a bear, across owners; never resets. */
export const readLifetimeBurned = (client: Client, a: Pick<ActivationAddresses, "activation">, tokenId: bigint) =>
  client.readContract({ ...act(a), functionName: "lifetimeBurned", args: [tokenId] });

/** A bear's royalty weight, basis 100. 100 for an id never minted as well: sum it only over owned ids. */
export const readWeight = (client: Client, a: Pick<ActivationAddresses, "activation">, tokenId: bigint) =>
  client.readContract({ ...act(a), functionName: "weightOf", args: [tokenId] });

/** The weight of a level. */
export const readWeightFor = (client: Client, a: Pick<ActivationAddresses, "activation">, level: number) =>
  client.readContract({ ...act(a), functionName: "weightFor", args: [level] });

/** The cumulative burn a level requires, in base units. */
export const readThreshold = (client: Client, a: Pick<ActivationAddresses, "activation">, level: number) =>
  client.readContract({ ...act(a), functionName: "thresholdFor", args: [level] });

/** How much more $MNTD a bear needs to reach `targetLevel`; zero if already there. */
export const readCostToReach = (client: Client, a: Pick<ActivationAddresses, "activation">, tokenId: bigint, targetLevel: number) =>
  client.readContract({ ...act(a), functionName: "costToReach", args: [tokenId, targetLevel] });

/** Whether `burn` and `linkBear` are suspended. */
export const readPaused = (client: Client, a: Pick<ActivationAddresses, "activation">) =>
  client.readContract({ ...act(a), functionName: "paused" });

/** A bear's transfer counter: advances on every transfer, never on mint (COL-3). */
export const readTransferNonce = (client: Client, a: Pick<ActivationAddresses, "bears">, tokenId: bigint) =>
  client.readContract({ ...col(a), functionName: "transferNonce", args: [tokenId] });

/** Whether an id has been minted. */
export const readExists = (client: Client, a: Pick<ActivationAddresses, "bears">, tokenId: bigint) =>
  client.readContract({ ...col(a), functionName: "exists", args: [tokenId] });

/** A bear's owner. Reverts `OwnerQueryForNonexistentToken` for an id never minted. */
export const readOwner = (client: Client, a: Pick<ActivationAddresses, "bears">, tokenId: bigint) =>
  client.readContract({ ...col(a), functionName: "ownerOf", args: [tokenId] });

/**
 * The bear carrying `wallet`'s Status boost and its level, or `tokenId` 0 when the wallet has no
 * link or its bear has moved since. How several wallets' links combine for one getminted.io
 * account is MINT's Status service's rule (CQ-21); this library reads each wallet on its own.
 */
export async function readLink(client: Client, a: Pick<ActivationAddresses, "activation">, wallet: Address) {
  const [tokenId, level] = await client.readContract({ ...act(a), functionName: "linkOf", args: [wallet] });
  return { tokenId, level };
}

/** `snapshot(ids)`: owner, level and weight per id; zeroes for an id never minted. */
export const readSnapshot = (client: Client, a: Pick<ActivationAddresses, "activation">, ids: readonly bigint[], blockNumber?: bigint) =>
  client.readContract({ ...act(a), functionName: "snapshot", args: [ids], blockNumber });

/** Everything the portal shows for one bear, read together. */
export async function readBear(client: Client, a: Omit<ActivationAddresses, "mntd">, tokenId: bigint) {
  const exists = await readExists(client, a, tokenId);
  if (!exists) return { tokenId, exists } as const;
  const [owner, level, cumulative, lifetimeBurned, weight, transferNonce, costToMax] = await Promise.all([
    readOwner(client, a, tokenId),
    readLevel(client, a, tokenId),
    readCumulative(client, a, tokenId),
    readLifetimeBurned(client, a, tokenId),
    readWeight(client, a, tokenId),
    readTransferNonce(client, a, tokenId),
    readCostToReach(client, a, tokenId, MAX_LEVEL),
  ]);
  return { tokenId, exists, owner, level, cumulative, lifetimeBurned, weight, transferNonce, costToMax } as const;
}

// ---------------------------------------------------------------------------------------------
// Burn (ACT-4, ACT-7, ACT-8)
// ---------------------------------------------------------------------------------------------

/** `$MNTD.approve(Activation, amount)`. Approve `Activation` itself; nothing else spends for a burn. */
export function approveBurnCall(a: ActivationAddresses, amount: bigint) {
  return { address: a.mntd, abi: erc20Abi, functionName: "approve", args: [a.activation, amount] } as const satisfies Call;
}

/** `Activation.burn(tokenId, amount)`, sent by the bear's owner, burning the owner's own $MNTD. */
export function burnCall(a: Pick<ActivationAddresses, "activation">, tokenId: bigint, amount: bigint) {
  return { ...act(a), functionName: "burn", args: [tokenId, amount] } as const satisfies Call;
}

/** Why a burn cannot go ahead, found before anything is sent. The first four mirror `burn`'s own checks. */
export type BurnRefusal = "ContractPaused" | "NotBearOwner" | "AlreadyAtMaxLevel" | "TargetReached" | "NonexistentToken" | "InsufficientBalance";

/** Something the holder should see before confirming a burn. */
export type BurnWarning =
  /** The bear has open marketplace listings: one filled after the burn costs the seller the $MNTD and gives the buyer level 0. */
  | { code: "OPEN_LISTINGS"; count: number }
  /** The burner's wallet does not link this bear: its Status gains nothing until `linkBear` (a level-5 bear included). */
  | { code: "NOT_LINKED"; currentLink: bigint };

export interface PlanBurnArgs {
  tokenId: bigint;
  /** The wallet that will send the burn; it must own the bear. */
  owner: Address;
  targetLevel: number;
  /**
   * Counts the bear's open marketplace listings (MINT's call to OpenSea's API, or any other
   * source). The library has no marketplace client; without this, no listing warning is given.
   */
  countOpenListings?: (tokenId: bigint) => Promise<number>;
}

export type BurnPlan =
  | {
      ok: true;
      /** Base units to burn: `costToReach(tokenId, targetLevel)`. */
      amount: bigint;
      /** The calls to send in order: `approve` if the allowance is short, then `burn`. */
      calls: Call[];
      warnings: BurnWarning[];
    }
  | { ok: false; reason: BurnRefusal };

/**
 * Sizes a burn to `targetLevel` and checks it the way `burn` will, so the portal can refuse
 * before a wallet prompt: paused, not the owner, already at level 5, target already reached, id
 * never minted, balance short. The amount is exactly `costToReach`, so it can never overshoot.
 */
export async function planBurn(client: Client, a: ActivationAddresses, p: PlanBurnArgs): Promise<BurnPlan> {
  if (!(await readExists(client, a, p.tokenId))) return { ok: false, reason: "NonexistentToken" };
  const [paused, owner, amount, costToMax, balance, allowance, link] = await Promise.all([
    readPaused(client, a),
    readOwner(client, a, p.tokenId),
    readCostToReach(client, a, p.tokenId, p.targetLevel),
    readCostToReach(client, a, p.tokenId, MAX_LEVEL),
    client.readContract({ address: a.mntd, abi: erc20Abi, functionName: "balanceOf", args: [p.owner] }),
    client.readContract({ address: a.mntd, abi: erc20Abi, functionName: "allowance", args: [p.owner, a.activation] }),
    readLink(client, a, p.owner),
  ]);
  if (paused) return { ok: false, reason: "ContractPaused" };
  if (owner.toLowerCase() !== p.owner.toLowerCase()) return { ok: false, reason: "NotBearOwner" };
  if (costToMax === 0n) return { ok: false, reason: "AlreadyAtMaxLevel" };
  if (amount === 0n) return { ok: false, reason: "TargetReached" };
  if (balance < amount) return { ok: false, reason: "InsufficientBalance" };

  const warnings: BurnWarning[] = [];
  const listings = p.countOpenListings ? await p.countOpenListings(p.tokenId) : 0;
  if (listings > 0) warnings.push({ code: "OPEN_LISTINGS", count: listings });
  if (link.tokenId !== p.tokenId) warnings.push({ code: "NOT_LINKED", currentLink: link.tokenId });

  const calls: Call[] = [];
  if (allowance < amount) calls.push(approveBurnCall(a, amount));
  calls.push(burnCall(a, p.tokenId, amount));
  return { ok: true, amount, calls, warnings };
}

// ---------------------------------------------------------------------------------------------
// Status link (ACT-9)
// ---------------------------------------------------------------------------------------------

/** `linkBear(tokenId)`: the sender's wallet nominates a bear it owns; replaces any earlier link. */
export function linkCall(a: Pick<ActivationAddresses, "activation">, tokenId: bigint) {
  return { ...act(a), functionName: "linkBear", args: [tokenId] } as const satisfies Call;
}

/** `unlinkBear()`: removes the sender's link; a no-op without one, and allowed while paused. */
export function unlinkCall(a: Pick<ActivationAddresses, "activation">) {
  return { ...act(a), functionName: "unlinkBear", args: [] } as const satisfies Call;
}

/**
 * The state of a wallet's link: `none`, `active` (with the bear and its level), or `voided` — the
 * wallet's last link was to a bear that has changed hands since, so it carries no boost. `voided`
 * needs the link history, read from `BearLinked` / `BearUnlinked` logs from `fromBlock` (the
 * `Activation` deployment block).
 */
export async function readLinkStatus(
  client: Client,
  a: Pick<ActivationAddresses, "activation">,
  wallet: Address,
  fromBlock: bigint,
): Promise<{ state: "none" } | { state: "active"; tokenId: bigint; level: number } | { state: "voided"; tokenId: bigint }> {
  const link = await readLink(client, a, wallet);
  if (link.tokenId !== 0n) return { state: "active", tokenId: link.tokenId, level: link.level };
  const [linked, unlinked] = await Promise.all([
    client.getContractEvents({ ...act(a), eventName: "BearLinked", args: { wallet }, fromBlock }),
    client.getContractEvents({ ...act(a), eventName: "BearUnlinked", args: { wallet }, fromBlock }),
  ]);
  const last = [...linked, ...unlinked].sort((x, y) =>
    x.blockNumber === y.blockNumber ? x.logIndex - y.logIndex : x.blockNumber < y.blockNumber ? -1 : 1,
  ).at(-1);
  if (last?.eventName === "BearLinked" && last.args.tokenId !== undefined) return { state: "voided", tokenId: last.args.tokenId };
  return { state: "none" };
}

/**
 * Whether to prompt `wallet` to link `tokenId` — after it buys a bear and after its first burn.
 * A wallet has no Status boost until it links, level 5 included. The prompt is shown whenever the
 * wallet's active link is not this bear; `currentLink` lets the portal word it (none yet, or
 * switching from another bear). Which of an account's links counts is CQ-21's, not the library's.
 */
export async function linkPrompt(client: Client, a: Pick<ActivationAddresses, "activation">, wallet: Address, tokenId: bigint) {
  const link = await readLink(client, a, wallet);
  return { prompt: link.tokenId !== tokenId, currentLink: link.tokenId, currentLevel: link.level };
}
