/**
 * Units and types.
 *
 * The conventions, everywhere in this library:
 *
 * - **`bigint`** for token ids, $MNTD and ETH amounts (always in **base units** — wei for ETH, the
 *   token's smallest unit for $MNTD), timestamps (Unix seconds) and block numbers.
 * - **`number`** for small counts: levels (0–5), whitelist allocations (0–2), weights (basis 100,
 *   100–200), bear counts.
 *
 * $MNTD amounts from the contracts (`costToReach`, `cumulativeOf`, `thresholdFor`,
 * `lifetimeBurned`) are base units. Show them with {@link formatMntd}; read what a holder types with
 * {@link parseMntd}. $MNTD's decimals come from the chain ({@link readMntdDecimals}); 18 is the
 * default when you do not pass them.
 *
 * @module
 */
import { formatUnits, parseUnits, type Address } from "viem";

import { activationAbi } from "./abi/index.js";
import type { AnyPublicClient } from "./calls.js";
import { ClientRefusal } from "./errors.js";

/** The decimals assumed when none are given: $MNTD's expected 18. */
export const DEFAULT_MNTD_DECIMALS = 18;

/**
 * $MNTD's decimals, as `Activation` read them from the token at deployment (the scale of every
 * threshold and cost it answers).
 *
 * @param client - Any viem public client on the chain.
 * @param addresses - Where `Activation` is.
 * @returns The decimals, e.g. `18`.
 */
export async function readMntdDecimals(client: AnyPublicClient, addresses: { activation: Address }): Promise<number> {
  return client.readContract({ address: addresses.activation, abi: activationAbi, functionName: "DECIMALS" });
}

/**
 * A $MNTD amount in base units as a decimal string, for display.
 *
 * @param amount - Base units.
 * @param decimals - The token's decimals; default 18.
 * @returns For example `"3333"` for `3333n * 10n ** 18n`, or `"1666.5"`.
 *
 * @example
 * ```ts
 * const cost = await mintabear.bears.costToReach(7n, 3);
 * label.textContent = `${formatMntd(cost)} $MNTD to level 3`;
 * ```
 */
export function formatMntd(amount: bigint, decimals: number = DEFAULT_MNTD_DECIMALS): string {
  return formatUnits(amount, decimals);
}

/**
 * A decimal $MNTD amount a holder typed, in base units.
 *
 * @param text - For example `"1666"` or `"1666.5"`.
 * @param decimals - The token's decimals; default 18.
 * @returns Base units.
 * @throws {ClientRefusal} `INVALID_ARGUMENT` if `text` is not a non-negative decimal number.
 */
export function parseMntd(text: string, decimals: number = DEFAULT_MNTD_DECIMALS): bigint {
  const trimmed = text.trim();
  if (!/^\d+(\.\d+)?$/.test(trimmed)) {
    throw new ClientRefusal("INVALID_ARGUMENT", { reason: `"${text}" is not an amount of $MNTD.` });
  }
  return parseUnits(trimmed, decimals);
}
