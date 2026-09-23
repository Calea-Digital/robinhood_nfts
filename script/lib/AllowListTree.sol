// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LibSort} from "solady/utils/LibSort.sol";
import {MintParams} from "seadrop/lib/SeaDropStructs.sol";

/**
 * @title  AllowListTree
 * @notice A SeaDrop allowlist Merkle tree built from whitelist rows: the root Studio sets on SeaDrop
 *         for the whitelist stage, and each wallet's proof for `mintAllowList`.
 * @dev    SeaDrop checks `MerkleProof.verify(proof, root, keccak256(abi.encode(minter, mintParams)))`
 *         with OpenZeppelin's sorted-pair hashing. The shape follows SeaDrop's own reference tests,
 *         merkletreejs 0.2.32 with `hashLeaves`, `sortLeaves` and `sortPairs`: leaves in ascending
 *         order, each pair hashed smaller-first, and an odd last node carried up a level unchanged.
 *         A different construction over the same leaves gives a different root, so that Studio
 *         builds its tree this way is what the testnet rehearsal settles.
 */
library AllowListTree {
    /// @notice A tree needs at least one leaf.
    error EmptyTree();

    /// @notice The leaf is not in the tree.
    error LeafNotFound(bytes32 leaf);

    /// @notice The allowlist leaf SeaDrop verifies for `minter` minting under `params`.
    function leaf(address minter, MintParams memory params) internal pure returns (bytes32) {
        return keccak256(abi.encode(minter, params));
    }

    /// @notice The root over `leaves`, in any order.
    function root(bytes32[] memory leaves) internal pure returns (bytes32) {
        bytes32[] memory level = _sortedCopy(leaves);
        while (level.length > 1) {
            level = _parents(level);
        }
        return level[0];
    }

    /// @notice The proof for `target` among `leaves`, as `mintAllowList` takes it.
    function proof(bytes32[] memory leaves, bytes32 target) internal pure returns (bytes32[] memory path) {
        bytes32[] memory level = _sortedCopy(leaves);
        uint256 index = type(uint256).max;
        for (uint256 i; i < level.length; ++i) {
            if (level[i] == target) {
                index = i;
                break;
            }
        }
        if (index == type(uint256).max) revert LeafNotFound(target);

        bytes32[] memory buffer = new bytes32[](256);
        uint256 depth;
        while (level.length > 1) {
            uint256 sibling = index ^ 1;
            if (sibling < level.length) buffer[depth++] = level[sibling];
            level = _parents(level);
            index >>= 1;
        }
        path = new bytes32[](depth);
        for (uint256 i; i < depth; ++i) {
            path[i] = buffer[i];
        }
    }

    function _sortedCopy(bytes32[] memory leaves) private pure returns (bytes32[] memory sorted) {
        if (leaves.length == 0) revert EmptyTree();
        sorted = new bytes32[](leaves.length);
        for (uint256 i; i < leaves.length; ++i) {
            sorted[i] = leaves[i];
        }
        LibSort.sort(sorted);
    }

    function _parents(bytes32[] memory level) private pure returns (bytes32[] memory up) {
        up = new bytes32[]((level.length + 1) / 2);
        for (uint256 i; i < level.length; i += 2) {
            if (i + 1 == level.length) {
                up[i / 2] = level[i];
            } else {
                (bytes32 a, bytes32 b) = level[i] < level[i + 1] ? (level[i], level[i + 1]) : (level[i + 1], level[i]);
                up[i / 2] = keccak256(abi.encodePacked(a, b));
            }
        }
    }
}
