/**
 * Activation: burning $MNTD for a bear's level, and every read about a bear.
 *
 * A burn is **approve, then one call**: approve `Activation` on $MNTD, then `burn(tokenId, amount)`
 * from the bear's owner, with the amount from `costToReach(tokenId, targetLevel)`. {@link planBurn}
 * works that out and checks it; `executePlan` sends it. Anything above the level-5 remainder is
 * refused (`OVERSHOOT`), so nothing is destroyed for nothing.
 *
 * Every transfer resets a bear: its level and its cumulative burn read zero for the new holder (and
 * after a self-transfer too).
 *
 * @module
 */
import { erc20Abi, type Address } from "viem";

import { activationAbi, mintABearAbi } from "./abi/index.js";
import type { MintABearAddresses } from "./addresses.js";
import type { AnyPublicClient, Call } from "./calls.js";
import { MAX_LEVEL } from "./constants.js";
import { ClientRefusal, refusal, type Refusal } from "./errors.js";

/** The addresses a burn touches: `Activation`, the collection it reads, and $MNTD. */
export type ActivationAddresses = Pick<MintABearAddresses, "activation" | "bears" | "mntd">;

type WithActivation = Pick<MintABearAddresses, "activation">;
type WithBears = Pick<MintABearAddresses, "bears">;

/**
 * `burn`'s contract errors, in the order the contract checks them (ACT-4, ACT-8). Besides these: an
 * id never minted reverts with the collection's `OwnerQueryForNonexistentToken`
 * (`TOKEN_DOES_NOT_EXIST`); a short $MNTD allowance or balance reverts from the token
 * (`INSUFFICIENT_MNTD_ALLOWANCE`, `INSUFFICIENT_MNTD_BALANCE`) and undoes the record; `Reentrancy`
 * never happens in normal use.
 */
export const BURN_REVERTS = ["ContractPaused", "ZeroAmount", "NotBearOwner", "AlreadyAtMaxLevel", "Overshoot"] as const;

// ---------------------------------------------------------------------------------------------
// Reads (ACT-14, COL-12) — free; poll them
// ---------------------------------------------------------------------------------------------

const act = (a: WithActivation) => ({ address: a.activation, abi: activationAbi }) as const;
const col = (a: WithBears) => ({ address: a.bears, abi: mintABearAbi }) as const;

/**
 * A bear's current level.
 * @param client - Any viem public client on the chain.
 * @param addresses - Where `Activation` is.
 * @param tokenId - The bear.
 * @returns 0–5; 0 after any transfer.
 */
export const readLevel = (client: AnyPublicClient, addresses: WithActivation, tokenId: bigint): Promise<number> =>
  client.readContract({ ...act(addresses), functionName: "levelOf", args: [tokenId] });

/**
 * $MNTD burned for a bear under its current owner.
 * @param client - Any viem public client on the chain.
 * @param addresses - Where `Activation` is.
 * @param tokenId - The bear.
 * @returns Base units; 0 after any transfer.
 */
export const readCumulative = (client: AnyPublicClient, addresses: WithActivation, tokenId: bigint): Promise<bigint> =>
  client.readContract({ ...act(addresses), functionName: "cumulativeOf", args: [tokenId] });

/**
 * $MNTD ever burned for a bear, across all its owners. Never resets.
 * @param client - Any viem public client on the chain.
 * @param addresses - Where `Activation` is.
 * @param tokenId - The bear.
 * @returns Base units.
 */
export const readLifetimeBurned = (client: AnyPublicClient, addresses: WithActivation, tokenId: bigint): Promise<bigint> =>
  client.readContract({ ...act(addresses), functionName: "lifetimeBurned", args: [tokenId] });

/**
 * A bear's royalty weight: the weight of its level.
 * @param client - Any viem public client on the chain.
 * @param addresses - Where `Activation` is.
 * @param tokenId - The bear.
 * @returns Basis 100 (100 at level 0 … 200 at level 5). Also 100 for an id never minted — check
 *   {@link readExists} before summing.
 */
export const readWeight = (client: AnyPublicClient, addresses: WithActivation, tokenId: bigint): Promise<number> =>
  client.readContract({ ...act(addresses), functionName: "weightOf", args: [tokenId] });

/**
 * The royalty weight of a level.
 * @param client - Any viem public client on the chain.
 * @param addresses - Where `Activation` is.
 * @param level - 0–5.
 * @returns Basis 100.
 */
export const readWeightFor = (client: AnyPublicClient, addresses: WithActivation, level: number): Promise<number> =>
  client.readContract({ ...act(addresses), functionName: "weightFor", args: [level] });

/**
 * The cumulative burn a level requires.
 * @param client - Any viem public client on the chain.
 * @param addresses - Where `Activation` is.
 * @param level - 0–5.
 * @returns Base units; 0 for level 0.
 */
export const readThreshold = (client: AnyPublicClient, addresses: WithActivation, level: number): Promise<bigint> =>
  client.readContract({ ...act(addresses), functionName: "thresholdFor", args: [level] });

/**
 * How much more $MNTD a bear needs to reach `targetLevel` — the amount to burn.
 * @param client - Any viem public client on the chain.
 * @param addresses - Where `Activation` is.
 * @param tokenId - The bear.
 * @param targetLevel - 1–5.
 * @returns Base units; 0 when the bear is already there.
 */
export const readCostToReach = (client: AnyPublicClient, addresses: WithActivation, tokenId: bigint, targetLevel: number): Promise<bigint> =>
  client.readContract({ ...act(addresses), functionName: "costToReach", args: [tokenId, targetLevel] });

/**
 * Whether burning is suspended (it is until the switch-on date).
 * @param client - Any viem public client on the chain.
 * @param addresses - Where `Activation` is.
 */
export const readPaused = (client: AnyPublicClient, addresses: WithActivation): Promise<boolean> =>
  client.readContract({ ...act(addresses), functionName: "paused" });

/**
 * A bear's transfer counter: it advances on every transfer, never on mint (COL-3).
 * @param client - Any viem public client on the chain.
 * @param addresses - Where the collection is.
 * @param tokenId - The bear.
 */
export const readTransferNonce = (client: AnyPublicClient, addresses: WithBears, tokenId: bigint): Promise<bigint> =>
  client.readContract({ ...col(addresses), functionName: "transferNonce", args: [tokenId] });

/**
 * Whether a bear has been minted.
 * @param client - Any viem public client on the chain.
 * @param addresses - Where the collection is.
 * @param tokenId - The bear.
 */
export const readExists = (client: AnyPublicClient, addresses: WithBears, tokenId: bigint): Promise<boolean> =>
  client.readContract({ ...col(addresses), functionName: "exists", args: [tokenId] });

/**
 * A bear's owner.
 * @param client - Any viem public client on the chain.
 * @param addresses - Where the collection is.
 * @param tokenId - The bear.
 * @throws A viem error (`OwnerQueryForNonexistentToken`) for an id never minted — use {@link readBear}
 *   to read a bear that may not exist.
 */
export const readOwner = (client: AnyPublicClient, addresses: WithBears, tokenId: bigint): Promise<Address> =>
  client.readContract({ ...col(addresses), functionName: "ownerOf", args: [tokenId] });

/**
 * `snapshot(ids)`: owner, level and weight per id, as the royalty split reads them.
 * @param client - Any viem public client on the chain.
 * @param addresses - Where `Activation` is.
 * @param ids - Token ids; keep a call to a few hundred (the cost grows with long mint batches).
 * @param blockNumber - Read at this block instead of the latest (needs an archive node).
 * @returns One row per id; zeroes for an id never minted.
 */
export const readSnapshot = (client: AnyPublicClient, addresses: WithActivation, ids: readonly bigint[], blockNumber?: bigint) =>
  client.readContract({ ...act(addresses), functionName: "snapshot", args: [ids], blockNumber });

/** Everything the portal shows for one bear. */
export type Bear =
  | { tokenId: bigint; exists: false }
  | {
      tokenId: bigint;
      exists: true;
      owner: Address;
      /** 0–5. */
      level: number;
      /** $MNTD burned under this owner, base units. */
      cumulative: bigint;
      /** $MNTD burned across all owners, base units. */
      lifetimeBurned: bigint;
      /** Royalty weight, basis 100. */
      weight: number;
      transferNonce: bigint;
      /** $MNTD still needed for level 5, base units; 0 at level 5. */
      costToMax: bigint;
    };

/**
 * Everything the portal shows for one bear, read together.
 * @param client - Any viem public client on the chain.
 * @param addresses - Where `Activation` and the collection are.
 * @param tokenId - The bear.
 * @returns `{ exists: false }` for an id never minted, otherwise owner, level, burns, weight and the cost to level 5.
 */
export async function readBear(client: AnyPublicClient, addresses: Omit<ActivationAddresses, "mntd">, tokenId: bigint): Promise<Bear> {
  const exists = await readExists(client, addresses, tokenId);
  if (!exists) return { tokenId, exists };
  const [owner, level, cumulative, lifetimeBurned, weight, transferNonce, costToMax] = await Promise.all([
    readOwner(client, addresses, tokenId),
    readLevel(client, addresses, tokenId),
    readCumulative(client, addresses, tokenId),
    readLifetimeBurned(client, addresses, tokenId),
    readWeight(client, addresses, tokenId),
    readTransferNonce(client, addresses, tokenId),
    readCostToReach(client, addresses, tokenId, MAX_LEVEL),
  ]);
  return { tokenId, exists, owner, level, cumulative, lifetimeBurned, weight, transferNonce, costToMax };
}

// ---------------------------------------------------------------------------------------------
// Burn (ACT-4, ACT-7, ACT-8)
// ---------------------------------------------------------------------------------------------

/**
 * The `$MNTD.approve(Activation, amount)` call. Approve `Activation` itself; nothing else spends
 * $MNTD for a burn.
 * @param addresses - Where $MNTD and `Activation` are.
 * @param amount - Base units; approve exactly the burn.
 */
export function approveBurnCall(addresses: Pick<MintABearAddresses, "activation" | "mntd">, amount: bigint) {
  return { address: addresses.mntd, abi: erc20Abi, functionName: "approve", args: [addresses.activation, amount] } as const satisfies Call;
}

/**
 * The `Activation.burn(tokenId, amount)` call, sent by the bear's owner, burning the owner's own $MNTD.
 * @param addresses - Where `Activation` is.
 * @param tokenId - The bear.
 * @param amount - Base units, at most `costToReach(tokenId, 5)`.
 */
export function burnCall(addresses: WithActivation, tokenId: bigint, amount: bigint) {
  return { ...act(addresses), functionName: "burn", args: [tokenId, amount] } as const satisfies Call;
}

/** Why {@link planBurn} refused. Each is the code the burn would have reverted with, or `TARGET_REACHED`. */
export type BurnRefusalCode =
  | "TOKEN_DOES_NOT_EXIST"
  | "ACTIVATION_PAUSED"
  | "NOT_BEAR_OWNER"
  | "ALREADY_MAX_LEVEL"
  | "TARGET_REACHED"
  | "INSUFFICIENT_MNTD_BALANCE";

/** Something the holder should see, and confirm, before a burn. */
export type BurnWarning =
  /** The bear has open marketplace listings: one filled after the burn costs the seller the $MNTD and gives the buyer level 0. Offer to cancel them. */
  | { code: "OPEN_LISTINGS"; count: number; message: string };

/** Arguments of {@link planBurn}. */
export interface PlanBurnArgs {
  /** The bear. */
  tokenId: bigint;
  /** The wallet that will send the burn; it must own the bear. */
  owner: Address;
  /** The level to reach, 1–5. */
  targetLevel: number;
  /**
   * Counts the bear's open marketplace listings (MINT's call to OpenSea's API). The library has no
   * marketplace client; without this, no listing warning is given.
   */
  countOpenListings?: (tokenId: bigint) => Promise<number>;
}

/** A burn, worked out and checked — or the reason it cannot happen. */
export type BurnPlan =
  | {
      ok: true;
      tokenId: bigint;
      /** The bear's level now. */
      currentLevel: number;
      targetLevel: number;
      /** $MNTD to burn, base units: exactly `costToReach(tokenId, targetLevel)`. */
      amount: bigint;
      /** The calls to send in order: `approve` if the allowance is short, then `burn`. Pass to `executePlan`. */
      calls: Call[];
      /** Show these and ask the holder to confirm before sending. */
      warnings: BurnWarning[];
    }
  | Refusal<BurnRefusalCode>;

/**
 * Works out a burn to `targetLevel` and checks it the way `burn` will, so the page can refuse
 * before a wallet prompt. The amount is exactly `costToReach`, so it can never overshoot.
 *
 * @param client - Any viem public client on the chain.
 * @param addresses - Where `Activation`, the collection and $MNTD are.
 * @param args - The bear, its owner, the target level, and optionally a listing counter.
 * @returns `{ ok: true, amount, calls, warnings }`, or `{ ok: false, code, userMessage }`.
 * @throws {ClientRefusal} `INVALID_ARGUMENT` when `targetLevel` is not an integer 1–5.
 *
 * @example
 * ```ts
 * const plan = await planBurn(client, addresses, { tokenId: 7n, owner: account.address, targetLevel: 3 });
 * if (!plan.ok) return showError(plan.userMessage);          // e.g. "This bear is already at level 5."
 * if (!(await confirm(plan.warnings.map((w) => w.message)))) return;
 * await executePlan(client, wallet, plan.calls);
 * ```
 */
export async function planBurn(client: AnyPublicClient, addresses: ActivationAddresses, args: PlanBurnArgs): Promise<BurnPlan> {
  if (!Number.isInteger(args.targetLevel) || args.targetLevel < 1 || args.targetLevel > MAX_LEVEL) {
    throw new ClientRefusal("INVALID_ARGUMENT", { reason: `The target level must be a whole number from 1 to ${MAX_LEVEL}, not ${args.targetLevel}.` });
  }
  if (!(await readExists(client, addresses, args.tokenId))) return refusal("TOKEN_DOES_NOT_EXIST", { tokenId: args.tokenId });
  const [paused, owner, currentLevel, amount, costToMax, balance, allowance] = await Promise.all([
    readPaused(client, addresses),
    readOwner(client, addresses, args.tokenId),
    readLevel(client, addresses, args.tokenId),
    readCostToReach(client, addresses, args.tokenId, args.targetLevel),
    readCostToReach(client, addresses, args.tokenId, MAX_LEVEL),
    client.readContract({ address: addresses.mntd, abi: erc20Abi, functionName: "balanceOf", args: [args.owner] }),
    client.readContract({ address: addresses.mntd, abi: erc20Abi, functionName: "allowance", args: [args.owner, addresses.activation] }),
  ]);
  if (paused) return refusal("ACTIVATION_PAUSED");
  if (owner.toLowerCase() !== args.owner.toLowerCase()) return refusal("NOT_BEAR_OWNER", { tokenId: args.tokenId, owner });
  if (costToMax === 0n) return refusal("ALREADY_MAX_LEVEL", { tokenId: args.tokenId });
  if (amount === 0n) return refusal("TARGET_REACHED", { tokenId: args.tokenId, targetLevel: args.targetLevel, currentLevel });
  if (balance < amount) return refusal("INSUFFICIENT_MNTD_BALANCE", { balance, needed: amount });

  const warnings: BurnWarning[] = [];
  const listings = args.countOpenListings ? await args.countOpenListings(args.tokenId) : 0;
  if (listings > 0) {
    warnings.push({
      code: "OPEN_LISTINGS",
      count: listings,
      message: `This bear has ${listings} open marketplace listing${listings === 1 ? "" : "s"}. If one fills after this burn, the buyer gets the bear at level 0 and the $MNTD is lost. Cancel the listings first.`,
    });
  }
  const calls: Call[] = [];
  if (allowance < amount) calls.push(approveBurnCall(addresses, amount));
  calls.push(burnCall(addresses, args.tokenId, amount));
  return { ok: true, tokenId: args.tokenId, currentLevel, targetLevel: args.targetLevel, amount, calls, warnings };
}
