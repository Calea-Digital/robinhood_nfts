import { getAddress, zeroAddress, type Address } from "viem";

import { DEAD_ADDRESS, MAX_BEARS } from "../constants.js";

/** One bear at the closing block: its owner and its royalty weight (basis 100). */
export interface BearRow {
  tokenId: bigint;
  owner: Address;
  weight: number | bigint;
}

export interface SplitOptions {
  /** Rounding carried in from the previous distribution, added to this one's funding. */
  carriedIn?: bigint;
  /** Owners excluded from the eligible total. Default: the dead address alone. */
  exclude?: readonly Address[];
}

export interface Allocation {
  wallet: Address;
  /** The sum of the wallet's bears' weights. */
  weight: bigint;
  /** Bears the wallet holds at the closing block. */
  bears: number;
  /** `floor(distributable × weight / eligibleWeight)`. */
  amount: bigint;
}

export interface SplitResult {
  /** `funding + carriedIn`. */
  distributable: bigint;
  /** Total weight of the bears counted: every owned bear except the excluded owners'. */
  eligibleWeight: bigint;
  /** Weight of the bears held by excluded owners (the dead address). */
  excludedWeight: bigint;
  /** One row per eligible wallet, ascending by address. */
  allocations: Allocation[];
  /** `distributable − Σ amount`: fewer base units than there are wallets, carried to the next distribution. */
  carried: bigint;
}

/**
 * The reference royalty split (ACT-10, DEL-6). Each wallet's weight is the sum over its bears; the
 * eligible total excludes bears held by `0x…dEaD`; contract-held bears keep their weight (whether
 * to pay a contract is MINT's policy). Each wallet gets `floor(distributable × weight / total)` and
 * the remainder is carried, so allocations plus carried rounding equal the funding exactly.
 *
 * Rows must be ids in 1..4,444, each once, each with an owner: an id never minted has none, and
 * counting it (`weightOf` answers 100 for it) would pay a phantom bear.
 */
export function computeSplit(rows: readonly BearRow[], funding: bigint, options: SplitOptions = {}): SplitResult {
  if (funding < 0n || (options.carriedIn ?? 0n) < 0n) throw new Error("funding and carriedIn must not be negative");
  const excluded = new Set((options.exclude ?? [DEAD_ADDRESS]).map((a) => a.toLowerCase()));
  const seen = new Set<bigint>();
  const byWallet = new Map<Address, { weight: bigint; bears: number }>();
  let eligibleWeight = 0n;
  let excludedWeight = 0n;

  for (const row of rows) {
    if (row.tokenId < 1n || row.tokenId > BigInt(MAX_BEARS)) throw new Error(`token id ${row.tokenId} is outside 1..${MAX_BEARS}`);
    if (seen.has(row.tokenId)) throw new Error(`token id ${row.tokenId} appears twice`);
    seen.add(row.tokenId);
    if (row.owner.toLowerCase() === zeroAddress) throw new Error(`token id ${row.tokenId} has no owner: drop ids never minted`);
    const weight = BigInt(row.weight);
    if (excluded.has(row.owner.toLowerCase())) {
      excludedWeight += weight;
      continue;
    }
    const wallet = getAddress(row.owner);
    const entry = byWallet.get(wallet) ?? { weight: 0n, bears: 0 };
    entry.weight += weight;
    entry.bears += 1;
    byWallet.set(wallet, entry);
    eligibleWeight += weight;
  }

  const distributable = funding + (options.carriedIn ?? 0n);
  const allocations: Allocation[] = [...byWallet.entries()]
    .sort(([x], [y]) => (BigInt(x) < BigInt(y) ? -1 : 1))
    .map(([wallet, { weight, bears }]) => ({
      wallet,
      weight,
      bears,
      amount: eligibleWeight === 0n ? 0n : (distributable * weight) / eligibleWeight,
    }));
  const paid = allocations.reduce((sum, a) => sum + a.amount, 0n);
  return { distributable, eligibleWeight, excludedWeight, allocations, carried: distributable - paid };
}
