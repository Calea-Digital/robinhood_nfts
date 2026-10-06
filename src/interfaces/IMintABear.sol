// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title  IMintABear
 * @notice The reads of MintABear that Activation uses. MintABear never calls Activation.
 */
interface IMintABear {
    /// @notice The current owner of `tokenId`. Reverts for an id that was never minted.
    function ownerOf(uint256 tokenId) external view returns (address);

    /// @notice Whether `tokenId` has been minted. Never reverts.
    function exists(uint256 tokenId) external view returns (bool);

    /**
     * @notice Number of non-mint transfers of `tokenId`.
     * @dev    Activation treats a record made at an earlier value as void.
     */
    function transferNonce(uint256 tokenId) external view returns (uint64);
}
