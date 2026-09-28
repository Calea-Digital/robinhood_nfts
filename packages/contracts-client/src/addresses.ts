/**
 * Where the contracts are.
 *
 * One type, {@link MintABearAddresses}, carries every address the library needs. Every function
 * takes it (or the part it uses), so you build it once — from {@link getDeployment} for a known
 * chain, or by hand for a local one — and pass it everywhere.
 *
 * @module
 */
import type { Address } from "viem";

import { SEADROP_ADDRESS } from "./constants.js";
import { ClientRefusal } from "./errors.js";

/** The addresses of one MintABear deployment. */
export interface MintABearAddresses {
  /** The collection, `MintABear`. */
  bears: Address;
  /** The level record and burn route, `Activation`. */
  activation: Address;
  /** The whitelist registry MINT deployed: `WhitelistClaim` (vouchers, WL-3) or `WhitelistImport` (owner-imported, WL-7). */
  registry: Address;
  /** The $MNTD token. */
  mntd: Address;
  /** SeaDrop, the collection's minter. Default: OpenSea's canonical SeaDrop. */
  seaDrop?: Address;
}

/**
 * The recorded deployments, by chain id: Robinhood Chain 4663 and its testnet 46630. Both are
 * filled in when the contracts are deployed (OPS-1, OPS-4); until then they are absent and
 * {@link getDeployment} throws `UNKNOWN_DEPLOYMENT`.
 */
export const DEPLOYMENTS: Readonly<Partial<Record<number, MintABearAddresses>>> = {};

/**
 * The addresses recorded for `chainId`.
 *
 * @param chainId - `4663` (Robinhood Chain) or `46630` (its testnet).
 * @returns The deployment's addresses, with `seaDrop` filled in.
 * @throws {ClientRefusal} `UNKNOWN_DEPLOYMENT` when nothing is recorded for the chain.
 *
 * @example
 * ```ts
 * const mintabear = createMintABearClient({ publicClient, walletClient, addresses: getDeployment(4663) });
 * ```
 */
export function getDeployment(chainId: number): Required<MintABearAddresses> {
  const found = DEPLOYMENTS[chainId];
  if (!found) throw new ClientRefusal("UNKNOWN_DEPLOYMENT", { chainId });
  return { ...found, seaDrop: found.seaDrop ?? SEADROP_ADDRESS };
}

/**
 * `addresses.seaDrop`, or canonical SeaDrop when it is not given.
 * @param addresses - Any object with an optional `seaDrop`.
 */
export function seaDropOf(addresses: { seaDrop?: Address }): Address {
  return addresses.seaDrop ?? SEADROP_ADDRESS;
}
