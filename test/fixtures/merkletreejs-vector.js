// Generates the vector pinned in test/WhitelistExport.t.sol (AllowListTreeTest): the allowlist root
// and two proofs that merkletreejs 0.2.32 builds for five whitelist rows, with the construction
// SeaDrop's own reference tests use (lib/seadrop/test/SeaDrop-mintAllowList.spec.ts:
// hashLeaves, sortLeaves, sortPairs; keccak256 from ethers v5; the leaf is the minter and the
// MintParams fields, each left-padded to 32 bytes — abi.encode(minter, mintParams)).
//
//   npm install merkletreejs@0.2.32 ethers@5
//   node test/fixtures/merkletreejs-vector.js
//
// Expected output: the constants in AllowListTreeTest — VECTOR_ROOT, leaves[0], the three-node
// proof of leaves[0] and the one-node proof of leaves[2] (the odd leaf carried up).

const { MerkleTree } = require("merkletreejs");
const { keccak256 } = require("ethers/lib/utils");
const { BigNumber } = require("ethers");

const pad = (value) => Buffer.from(BigNumber.from(value).toHexString().slice(2).padStart(64, "0"), "hex");

// AllowListTreeTest._stage(); maxTotalMintableByWallet is each row's allocations.
const stage = {
  mintPrice: 0,
  startTime: 1_793_145_599,
  endTime: 1_793_231_999,
  dropStageIndex: 1,
  maxTokenSupplyForStage: 4444,
  feeBps: 0,
  restrictFeeRecipients: false,
};

// AllowListTreeTest._vectorRows(), in the same order.
const rows = [
  ["0x1111111111111111111111111111111111111111", 2],
  ["0x2222222222222222222222222222222222222222", 1],
  ["0x3333333333333333333333333333333333333333", 1],
  ["0x4444444444444444444444444444444444444444", 2],
  ["0x5555555555555555555555555555555555555555", 1],
];

const elements = rows.map(([minter, allocations]) =>
  Buffer.concat(
    [
      minter,
      stage.mintPrice,
      allocations,
      stage.startTime,
      stage.endTime,
      stage.dropStageIndex,
      stage.maxTokenSupplyForStage,
      stage.feeBps,
      stage.restrictFeeRecipients ? 1 : 0,
    ].map(pad)
  )
);

const tree = new MerkleTree(elements, keccak256, { hashLeaves: true, sortLeaves: true, sortPairs: true });
const leaves = elements.map((element) => keccak256(element));

console.log("VECTOR_ROOT", tree.getHexRoot());
console.log("leaves[0]  ", leaves[0]);
console.log("proof(leaves[0])", tree.getHexProof(leaves[0]));
console.log("proof(leaves[2])", tree.getHexProof(leaves[2]));
