// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title  IMintABear
 * @notice The slice of the token that Activation depends on.
 * @dev    Activation reads the token; the token never calls Activation. That direction is
 *         deliberate — it means no defect in Activation can block a transfer, and no
 *         defect can silently skip a reset.
 */
interface IMintABear {
    /// @notice Returns the current owner of a bear. Reverts for an id that was never minted.
    function ownerOf(uint256 tokenId) external view returns (address);

    /// @notice Whether a bear with this id has been minted. Never reverts.
    function exists(uint256 tokenId) external view returns (bool);

    /**
     * @notice Counts how many times a bear has changed hands.
     * @dev    Incremented on every transfer and never on mint. State keyed to a stale value
     *         of this counter is void, which is how activation and Status links reset.
     */
    function transferNonce(uint256 tokenId) external view returns (uint64);
}
