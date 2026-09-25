import { describe, expect, it } from "vitest";
import { createRequire } from "node:module";
import { getAddress, keccak256 as viemKeccak, toHex, type Address, type Hex } from "viem";

import { allowListLeaf, allowListProof, allowListRoot, buildAllowList, rowMintParams, type StageParams } from "../src/index.js";

// merkletreejs 0.2.32 with ethers v5's keccak256: the library and options SeaDrop's reference tests
// build allowlists with (lib/seadrop/test/SeaDrop-mintAllowList.spec.ts), as
// test/fixtures/merkletreejs-vector.js uses them. CommonJS, so loaded through require.
const require = createRequire(import.meta.url);
const { MerkleTree } = require("merkletreejs") as typeof import("merkletreejs");
const { keccak256: ethersKeccak } = require("ethers/lib/utils") as { keccak256: (data: Uint8Array | string) => string };

/** AllowListTreeTest._stage() in test/WhitelistExport.t.sol. */
const STAGE: StageParams = {
  mintPrice: 0n,
  startTime: 1_793_145_599n,
  endTime: 1_793_231_999n,
  dropStageIndex: 1n,
  maxTokenSupplyForStage: 4444n,
  feeBps: 0n,
  restrictFeeRecipients: false,
};

/** AllowListTreeTest._vectorRows(), in the same order. */
const VECTOR_ROWS = [
  { wallet: "0x1111111111111111111111111111111111111111", allocations: 2 },
  { wallet: "0x2222222222222222222222222222222222222222", allocations: 1 },
  { wallet: "0x3333333333333333333333333333333333333333", allocations: 1 },
  { wallet: "0x4444444444444444444444444444444444444444", allocations: 2 },
  { wallet: "0x5555555555555555555555555555555555555555", allocations: 1 },
] as const satisfies readonly { wallet: Address; allocations: number }[];

/** The constants pinned in AllowListTreeTest. */
const VECTOR_ROOT = "0x8cabae64e27037f2c74f33c05a4ceeed39b40d86c4dd9f866aa87fe7ee3627e7";
const VECTOR_LEAF0 = "0x53efe867013727e3689231b2edb0a63025e9634bbf513e19f77dfabdb4f80a39";
const VECTOR_PROOF0 = [
  "0x0864690c4cbd1e2b49c2db6498363c3462f0f9a0b5b79314c3055ca020c5eeb1",
  "0x15d735c8f8236876b0ecba70c984be63b40f9003b6d68a208f25dc466d913857",
  "0xe159d9efea745add5d4acf1787c45222eb52d7ebd7c7d80340bae0b043628776",
];
const VECTOR_PROOF2 = ["0x309e51cece4ba52cf32a9606b56a3e769d668d2cdee1aa9414f7d6ae0113d464"];

/** The same tree built by merkletreejs over leaves this library computed. */
function merkletreejs(leaves: readonly Hex[]) {
  const tree = new MerkleTree(
    leaves.map((leaf) => Buffer.from(leaf.slice(2), "hex")),
    ethersKeccak,
    { hashLeaves: false, sortLeaves: true, sortPairs: true },
  );
  return {
    root: tree.getHexRoot(),
    proof: (leaf: Hex) => tree.getHexProof(Buffer.from(leaf.slice(2), "hex")),
  };
}

/** A fixed list of `n` distinct wallets with 1 or 2 allocations. */
function fixedRows(n: number) {
  return Array.from({ length: n }, (_, i) => ({
    wallet: getAddress(viemKeccak(toHex(`wallet-${i}`)).slice(0, 42)),
    allocations: (i % 2) + 1,
  }));
}

describe("allowlist tree", () => {
  it("builds the root, leaf and proofs AllowListTree.sol pins", () => {
    /* Scenario:
       Given the five vector rows and stage of AllowListTreeTest
       When the library builds the allowlist
       Then its root, first leaf and the proofs of leaves 0 and 2 equal the Solidity test's constants */
    const list = buildAllowList(VECTOR_ROWS, STAGE);
    expect(list.root).toBe(VECTOR_ROOT);
    expect(list.leaves[0]).toBe(VECTOR_LEAF0);
    expect(allowListProof(list.leaves, list.leaves[0]!)).toEqual(VECTOR_PROOF0);
    expect(allowListProof(list.leaves, list.leaves[2]!)).toEqual(VECTOR_PROOF2);
    expect(list.entry(VECTOR_ROWS[0].wallet)?.proof).toEqual(VECTOR_PROOF0);
  });

  it("equals merkletreejs 0.2.32 over the vector, built from the raw rows", () => {
    /* Scenario:
       Given the vector rows encoded as test/fixtures/merkletreejs-vector.js encodes them
       When merkletreejs hashes, sorts and builds the tree
       Then its root and proofs equal the library's */
    const list = buildAllowList(VECTOR_ROWS, STAGE);
    const elements = VECTOR_ROWS.map((row) => {
      const p = rowMintParams(STAGE, row.allocations);
      const words = [
        BigInt(row.wallet),
        p.mintPrice,
        p.maxTotalMintableByWallet,
        p.startTime,
        p.endTime,
        p.dropStageIndex,
        p.maxTokenSupplyForStage,
        p.feeBps,
        p.restrictFeeRecipients ? 1n : 0n,
      ];
      return Buffer.concat(words.map((w) => Buffer.from(w.toString(16).padStart(64, "0"), "hex")));
    });
    const tree = new MerkleTree(elements, ethersKeccak, { hashLeaves: true, sortLeaves: true, sortPairs: true });
    expect(tree.getHexRoot()).toBe(list.root);
    for (const [i, element] of elements.entries()) {
      expect(ethersKeccak(element)).toBe(list.leaves[i]);
      expect(tree.getHexProof(ethersKeccak(element))).toEqual(allowListProof(list.leaves, list.leaves[i]!));
    }
  });

  it.each([1, 2, 3, 7, 8, 9, 64, 100, 1000])("equals merkletreejs for %i rows", (n) => {
    /* Scenario:
       Given a fixed list of n rows, odd and even sizes and powers of two among them
       When both the library and merkletreejs build the tree
       Then the roots are equal and every proof is equal */
    const list = buildAllowList(fixedRows(n), STAGE);
    const reference = merkletreejs(list.leaves);
    expect(list.root).toBe(reference.root);
    const step = Math.max(1, Math.floor(n / 25));
    for (let i = 0; i < n; i += step) {
      expect(allowListProof(list.leaves, list.leaves[i]!)).toEqual(reference.proof(list.leaves[i]!));
    }
  });

  it("gives the same root whatever the row order", () => {
    /* Scenario:
       Given the vector rows reversed
       When the allowlist is built
       Then the root is the vector root */
    expect(buildAllowList([...VECTOR_ROWS].reverse(), STAGE).root).toBe(VECTOR_ROOT);
  });

  it("commits each row to its allocations as the per-wallet limit", () => {
    /* Scenario:
       Given a wallet listed with two allocations
       When its leaf is computed with a per-wallet limit of one instead
       Then the leaf differs, so a proof works only with the row's own allocations */
    const wallet = VECTOR_ROWS[0].wallet;
    expect(allowListLeaf(wallet, rowMintParams(STAGE, 2))).toBe(VECTOR_LEAF0);
    expect(allowListLeaf(wallet, rowMintParams(STAGE, 1))).not.toBe(VECTOR_LEAF0);
    expect(buildAllowList(VECTOR_ROWS, STAGE).entry(wallet)?.mintParams.maxTotalMintableByWallet).toBe(2n);
  });

  it("answers the leaf itself as the root of one leaf, and refuses no leaves or an absent leaf", () => {
    /* Scenario:
       Given a single leaf, then no leaves, then a leaf not in the tree
       When the root or a proof is asked for
       Then the one leaf is its own root with an empty proof; no leaves throw EMPTY_ALLOWLIST and an absent leaf NOT_ON_ALLOWLIST */
    const list = buildAllowList([VECTOR_ROWS[0]], STAGE);
    expect(list.root).toBe(VECTOR_LEAF0);
    expect(allowListProof(list.leaves, VECTOR_LEAF0)).toEqual([]);
    expect(() => allowListRoot([])).toThrow(expect.objectContaining({ code: "EMPTY_ALLOWLIST" }));
    expect(() => allowListProof(list.leaves, VECTOR_ROOT)).toThrow(expect.objectContaining({ code: "NOT_ON_ALLOWLIST" }));
    expect(list.entry("0x9999999999999999999999999999999999999999")).toBeUndefined();
  });
});
