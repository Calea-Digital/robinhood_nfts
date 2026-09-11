// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC6551} from "solady/accounts/ERC6551.sol";

/**
 * @title  BearAccount
 * @notice The wallet a bear owns. Control follows ownership of the bear.
 * @dev    Built on Solady's ERC6551, which supplies the properties this product needs:
 *         the chain id is cached in the deployed bytecode so ownership still resolves after
 *         a fork; ownership cycles are detected at arbitrary depth on receipt, not just one
 *         level; execution is restricted to plain calls, so there is no delegatecall surface;
 *         and signature validation is domain-bound, so a signature cannot be replayed against
 *         the same address on another chain.
 *
 *         Deliberately immutable: there is no upgrade path, and no administrative route into
 *         a holder's assets. The trade-off is accepted — a defect here could not be patched —
 *         because the contract's job is narrow enough to review exhaustively, and an upgrade
 *         switch over 4,444 asset-holding wallets is exactly the centralisation this product
 *         is meant to avoid.
 */
contract BearAccount is ERC6551 {
    /// @dev Domain separator inputs for ERC-1271 signature validation.
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        return ("MintABear", "1");
    }
}
