import { encodeAbiParameters, encodePacked, keccak256, type Address, type Hex } from "viem";

/**
 * SeaDrop's `MintParams`: the allowlist stage a leaf commits to. Every field is part of the leaf,
 * so a proof works only with the exact values Studio configured for the stage.
 */
export interface MintParams {
  mintPrice: bigint;
  maxTotalMintableByWallet: bigint;
  startTime: bigint;
  endTime: bigint;
  dropStageIndex: bigint;
  maxTokenSupplyForStage: bigint;
  feeBps: bigint;
  restrictFeeRecipients: boolean;
}

/** A stage's parameters without the per-wallet limit, which each row sets to its allocations. */
export type StageParams = Omit<MintParams, "maxTotalMintableByWallet">;

/** A whitelist row: a wallet and the allocations it claimed (`WhitelistClaim.claimants`). */
export interface AllowListRow {
  wallet: Address;
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

/** The leaf SeaDrop verifies for `minter` minting under `params`: `keccak256(abi.encode(minter, params))`. */
export function allowListLeaf(minter: Address, params: MintParams): Hex {
  return keccak256(encodeAbiParameters(mintParamsAbi, [minter, params]));
}

/** The `MintParams` a row mints under: the stage with the row's allocations as the per-wallet limit. */
export function rowMintParams(stage: StageParams, allocations: number | bigint): MintParams {
  return { ...stage, maxTotalMintableByWallet: BigInt(allocations) };
}

function sortedCopy(leaves: readonly Hex[]): Hex[] {
  if (leaves.length === 0) throw new Error("EmptyTree: a tree needs at least one leaf");
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
 * The root over `leaves`, in any order. The construction is `script/lib/AllowListTree.sol`'s and
 * merkletreejs 0.2.32's with `hashLeaves`, `sortLeaves` and `sortPairs` — the one SeaDrop's
 * reference tests use: leaves ascending, each pair hashed smaller-first, an odd last node carried
 * up a level unchanged.
 */
export function allowListRoot(leaves: readonly Hex[]): Hex {
  let level = sortedCopy(leaves);
  while (level.length > 1) level = parents(level);
  return level[0]!;
}

/** The proof of `leaf` among `leaves`, as `mintAllowList` takes it. Throws if the leaf is absent. */
export function allowListProof(leaves: readonly Hex[], leaf: Hex): Hex[] {
  let level = sortedCopy(leaves);
  let index = level.findIndex((l) => l.toLowerCase() === leaf.toLowerCase());
  if (index < 0) throw new Error(`LeafNotFound: ${leaf}`);
  const path: Hex[] = [];
  while (level.length > 1) {
    const sibling = level[index ^ 1];
    if (sibling !== undefined) path.push(sibling);
    level = parents(level);
    index >>= 1;
  }
  return path;
}

/** An allowlist built from whitelist rows for one stage: the root Studio sets and each wallet's proof. */
export interface AllowList {
  root: Hex;
  leaves: Hex[];
  /** The mint params and proof `wallet` passes to `mintAllowList`, or `undefined` if not listed. */
  entry(wallet: Address): { mintParams: MintParams; proof: Hex[] } | undefined;
}

/**
 * Builds the allowlist for `rows` under `stage`, as `script/WhitelistExport.s.sol` does: each
 * row's leaf is its wallet under the stage with `maxTotalMintableByWallet` set to its allocations.
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
