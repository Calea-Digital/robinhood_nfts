// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title  IBurnableMNTD
 * @notice The two functions of $MNTD that Activation calls.
 */
interface IBurnableMNTD {
    /// @notice The token's decimals, read once in Activation's constructor.
    function decimals() external view returns (uint8);

    /// @notice Burns `amount` of `account`'s balance against the caller's allowance; reverts on failure.
    function burnFrom(address account, uint256 amount) external;
}
