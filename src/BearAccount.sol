// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC6551} from "solady/accounts/ERC6551.sol";

/**
 * @title  BearAccount
 * @notice The wallet a bear owns. Control follows ownership of the bear.
 * @dev    Built on Solady's ERC6551, which supplies the properties this product needs:
 *         the chain id is cached in the deployed bytecode so ownership still resolves after
 *         a fork; ownership cycles are detected at arbitrary depth on *safe* receipt;
 *         execution is restricted to plain calls, so there is no delegatecall surface; and
 *         signature validation is domain-bound, so a signature cannot be replayed against
 *         the same address on another chain.
 *
 *         Two inherited behaviours worth knowing before integrating:
 *
 *         The cycle check runs from `onERC721Received`, so it only sees NFTs that arrive by
 *         `safeTransferFrom`. A plain `transferFrom` skips it. Bears specifically cannot
 *         reach an account by either route — `MintABear` refuses the destination outright —
 *         but an NFT from another collection can, and a cycle through one would not be
 *         caught here.
 *
 *         `supportsInterface` advertises ERC-165, ERC-6551 and ERC-6551 Executable, and does
 *         not advertise the ERC-721 or ERC-1155 receiver interfaces, although receipt of
 *         both works. Anything that gates a deposit on ERC-165 will refuse to send here.
 *
 *         Deliberately immutable: there is no upgrade path, and no administrative route into
 *         a holder's assets. Solady's `ERC6551` does inherit `UUPSUpgradeable`, but its
 *         `onlyViaERC6551Proxy` guard refuses any upgrade when the calling proxy hardcodes
 *         the implementation in its own bytecode — which is exactly what the canonical
 *         ERC-6551 registry deploys. `test_upgrade_isRefused` pins that. The trade-off is accepted — a defect here could not be patched —
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
