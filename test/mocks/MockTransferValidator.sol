// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ITransferValidator721} from "seadrop/interfaces/ITransferValidator.sol";

/**
 * @dev Deterministic stand-in for Limit Break's transfer validator V3 in its zero-state policy
 *      (COL-7): security level 0 and list 0 — a transfer the holder initiates always passes,
 *      an operator passes only if it is on the whitelist (OpenSea's SignedZone and the Payment
 *      Processor marketplaces on the real list), and there is no receiver constraint.
 *
 *      The real V3 at 0x721C002B0059009a671D00aD1700c9748146cd1B on chain 4663 is the
 *      auditor's fork obligation (Fork-2 in `test/MintABear.tree.md`).
 */
contract MockTransferValidator is ITransferValidator721 {
    /// @notice Operators allowed to move bears on a holder's behalf.
    mapping(address => bool) public whitelisted;

    /// @notice The caller is neither the holder nor a whitelisted operator.
    error OperatorNotWhitelisted(address operator);

    function setWhitelisted(address operator, bool allowed) external {
        whitelisted[operator] = allowed;
    }

    /// @inheritdoc ITransferValidator721
    function validateTransfer(address caller, address from, address, uint256) external view {
        if (caller == from) return;
        if (!whitelisted[caller]) revert OperatorNotWhitelisted(caller);
    }
}
