/**
 * The whitelist stage's allowlist: the Merkle tree Studio loads into SeaDrop, and each wallet's
 * proof for `mintAllowList`.
 *
 * The tree is built exactly as `script/lib/AllowListTree.sol` and merkletreejs 0.2.32 build it
 * (`hashLeaves`, `sortLeaves`, `sortPairs` — SeaDrop's reference construction): each leaf is
 * `keccak256(abi.encode(wallet, MintParams))` with `maxTotalMintableByWallet` set to the wallet's
 * allocations; leaves ascending; each pair hashed smaller-first; an odd last node carried up.
 *
 * You rarely need these directly: `mintabear.whitelist.allowList(stage)` reads the claimants and
 * builds the list, and `mintabear.mint.allowList(...)` takes the proof from it.
 *
 * @module
 */
import { encodeAbiParameters, encodePacked, keccak256, type Address, type Hex } from "viem";

import { ClientRefusal } from "./errors.js";

/**
 * SeaDrop's `MintParams`: the stage a leaf commits to. Every field is part of the leaf, so a proof
 * works only with the exact values Studio configured for the stage.
 */
export interface MintParams {
  /** Price per bear, in wei. */
  mintPrice: bigint;
  /** Most bears one wallet may mint across all stages (for a whitelist row: its allocations). */
  maxTotalMintableByWallet: bigint;
  /** Stage start, Unix seconds. */
  startTime: bigint;
  /** Stage end, Unix seconds. */
  endTime: bigint;
  /** Studio's index of the stage. */
  dropStageIndex: bigint;
  /** Most bears the stage may mint in total. */
  maxTokenSupplyForStage: bigint;
  /** OpenSea's fee, in basis points. */
  feeBps: bigint;
  /** Whether only allowed fee recipients may be named. */
  restrictFeeRecipients: boolean;
}

/** A stage's parameters without the per-wallet limit, which each row sets to its allocations. */
export type StageParams = Omit<MintParams, "maxTotalMintableByWallet">;

/** A whitelist row: a wallet and the allocations it claimed (`WhitelistClaim.claimants`). */
export interface AllowListRow {
  wallet: Address;
  /** 1 or 2. */
  allocations: number | bigint;
}

const mintParamsAbi = [
  { type: "address" },
  {
    type: "tuple",
    components: [
      { name: "mintPrice", type: "uint256" },
      { name: "maxTotalMintableByWallet", type: "uint256" },
      { name: "startTime", type: "uint256" },
      { name: "endTime", type: "uint256" },
      { name: "dropStageIndex", type: "uint256" },
      { name: "maxTokenSupplyForStage", type: "uint256" },
      { name: "feeBps", type: "uint256" },
      { name: "restrictFeeRecipients", type: "bool" },
    ],
  },
] as const;

/**
 * The leaf SeaDrop verifies for `minter` minting under `params`.
 *
 * @param minter - The wallet that mints (for a smart wallet, the smart account).
 * @param params - The stage with the wallet's allocations as `maxTotalMintableByWallet`.
 * @returns `keccak256(abi.encode(minter, params))`.
 */
export function allowListLeaf(minter: Address, params: MintParams): Hex {
  return keccak256(encodeAbiParameters(mintParamsAbi, [minter, params]));
}

/**
 * The `MintParams` a row mints under.
 *
 * @param stage - The stage as Studio configured it.
 * @param allocations - The row's allocations (1 or 2).
 * @returns The stage with `maxTotalMintableByWallet` set to `allocations`.
 */
export function rowMintParams(stage: StageParams, allocations: number | bigint): MintParams {
  return { ...stage, maxTotalMintableByWallet: BigInt(allocations) };
}

function sortedCopy(leaves: readonly Hex[]): Hex[] {
  if (leaves.length === 0) throw new ClientRefusal("EMPTY_ALLOWLIST");
  return [...leaves].sort((a, b) => (BigInt(a) < BigInt(b) ? -1 : BigInt(a) > BigInt(b) ? 1 : 0));
}

function parents(level: readonly Hex[]): Hex[] {
  const up: Hex[] = [];
  for (let i = 0; i < level.length; i += 2) {
    const a = level[i]!;
    const b = level[i + 1];
    if (b === undefined) {
      up.push(a);
    } else {
      const [lo, hi] = BigInt(a) < BigInt(b) ? [a, b] : [b, a];
      up.push(keccak256(encodePacked(["bytes32", "bytes32"], [lo, hi])));
    }
  }
  return up;
}

/**
 * The Merkle root over `leaves`, in any order.
 *
 * @param leaves - Leaves from {@link allowListLeaf}.
 * @returns The root Studio sets on SeaDrop.
 * @throws {ClientRefusal} `EMPTY_ALLOWLIST` for no leaves.
 */
export function allowListRoot(leaves: readonly Hex[]): Hex {
  let level = sortedCopy(leaves);
  while (level.length > 1) level = parents(level);
  return level[0]!;
}

/**
 * The proof of `leaf` among `leaves`, as `mintAllowList` takes it.
 *
 * @param leaves - Every leaf of the tree.
 * @param leaf - The wallet's leaf.
 * @returns The sibling hashes from the leaf up; empty for a one-leaf tree.
 * @throws {ClientRefusal} `NOT_ON_ALLOWLIST` if `leaf` is not in the tree; `EMPTY_ALLOWLIST` for no leaves.
 */
export function allowListProof(leaves: readonly Hex[], leaf: Hex): Hex[] {
  let level = sortedCopy(leaves);
  let index = level.findIndex((l) => l.toLowerCase() === leaf.toLowerCase());
  if (index < 0) throw new ClientRefusal("NOT_ON_ALLOWLIST", { leaf });
  const path: Hex[] = [];
  while (level.length > 1) {
    const sibling = level[index ^ 1];
    if (sibling !== undefined) path.push(sibling);
    level = parents(level);
    index >>= 1;
  }
  return path;
}

/** An allowlist for one stage: the root and each wallet's entry. */
export interface AllowList {
  /** The Merkle root. */
  root: Hex;
  /** Every row's leaf, in row order. */
  leaves: Hex[];
  /**
   * The mint params and proof `wallet` passes to `mintAllowList`, or `undefined` when the wallet
   * is not listed.
   */
  entry(wallet: Address): { mintParams: MintParams; proof: Hex[] } | undefined;
}

/**
 * Builds the allowlist for `rows` under `stage`, as `script/WhitelistExport.s.sol` does.
 *
 * @param rows - The whitelist rows (`readClaimants`, or `mintabear.whitelist.claimants()`).
 * @param stage - The whitelist stage exactly as Studio configured it.
 * @returns The root and an `entry(wallet)` lookup.
 * @throws {ClientRefusal} `EMPTY_ALLOWLIST` for no rows.
 *
 * @example
 * ```ts
 * const list = buildAllowList(await readClaimants(client, registry), stage);
 * const entry = list.entry(wallet);        // undefined: not whitelisted
 * if (entry) await mintabear.mint.allowList({ quantity: 1n, ...entry });
 * ```
 */
export function buildAllowList(rows: readonly AllowListRow[], stage: StageParams): AllowList {
  const leaves = rows.map((row) => allowListLeaf(row.wallet, rowMintParams(stage, row.allocations)));
  const root = allowListRoot(leaves);
  return {
    root,
    leaves,
    entry(wallet) {
      const i = rows.findIndex((row) => row.wallet.toLowerCase() === wallet.toLowerCase());
      if (i < 0) return undefined;
      const row = rows[i]!;
      return { mintParams: rowMintParams(stage, row.allocations), proof: allowListProof(leaves, leaves[i]!) };
    },
  };
}
