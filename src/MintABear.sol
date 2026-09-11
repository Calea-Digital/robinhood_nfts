// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721SeaDrop} from "seadrop/ERC721SeaDrop.sol";
import {LibERC6551} from "solady/accounts/LibERC6551.sol";
import {IBearRenderer} from "./interfaces/IBearRenderer.sol";

/**
 * @title  MintABear
 * @notice A 4,444-supply collection where every bear owns an ERC-6551 account.
 * @dev    Extends OpenSea's ERC721SeaDrop, which already implements ICreatorToken — so this
 *         is an ERC-721C contract, with its transfer validator left unset (free transfers,
 *         no gas overhead). The SeaDrop mint path and `getMintStats` are untouched, per
 *         OpenSea's integration guidance.
 *
 *         Two behaviours are added on top:
 *
 *         1. A per-bear transfer counter. Activation stores a level alongside the counter
 *            value it was set at; when the counter moves, that level is void. The reset is
 *            therefore a consequence of the transfer rather than an action that has to
 *            succeed, so it can neither be skipped nor block the transfer itself.
 *
 *         2. A standing refusal to send a bear into any bear's account. Recorded at mint,
 *            when the account address is already known, so the rule holds even for accounts
 *            that have never been deployed.
 */
contract MintABear is ERC721SeaDrop {
    /// @notice Salt used for every bear's account. Fixed so each address is deterministic.
    bytes32 public constant ACCOUNT_SALT = bytes32(0);

    /// @notice The account implementation every bear's account is a clone of.
    address public immutable ACCOUNT_IMPLEMENTATION;

    /// @notice Contract that builds the metadata document. Replaceable; holds no user state.
    IBearRenderer public renderer;

    /// @notice How many times each bear has changed hands. Never incremented on mint.
    mapping(uint256 => uint64) public transferNonce;

    /// @notice Addresses known to be the account of one of this collection's bears.
    mapping(address => bool) public isBearAccount;

    /// @notice Emitted when the metadata renderer is replaced.
    event RendererUpdated(address indexed previousRenderer, address indexed newRenderer);

    /// @notice A bear may never be owned by any bear's account, at any depth.
    error TransferToBearAccount();

    /// @notice The renderer address may not be zero.
    error RendererIsZeroAddress();

    /**
     * @param name_           Collection name. Permanent.
     * @param symbol_         Collection symbol. Permanent.
     * @param allowedSeaDrop_ SeaDrop contracts permitted to mint. Canonical SeaDrop on
     *                        Robinhood Chain is 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5.
     * @param accountImplementation_ The BearAccount implementation.
     * @param renderer_       Initial renderer. Launches as the placeholder; replaced at reveal.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address[] memory allowedSeaDrop_,
        address accountImplementation_,
        address renderer_
    ) ERC721SeaDrop(name_, symbol_, allowedSeaDrop_) {
        if (renderer_ == address(0)) revert RendererIsZeroAddress();
        ACCOUNT_IMPLEMENTATION = accountImplementation_;
        renderer = IBearRenderer(renderer_);
    }

    /**
     * @notice The address of a bear's account, whether or not it has been deployed.
     * @dev    Assets sent to this address before deployment are safe; `deployAccount` can be
     *         called at any time to bring the account into existence.
     */
    function accountOf(uint256 tokenId) public view returns (address) {
        return LibERC6551.account(ACCOUNT_IMPLEMENTATION, ACCOUNT_SALT, block.chainid, address(this), tokenId);
    }

    /**
     * @notice Deploys a bear's account. Callable by anyone, at any time.
     * @dev    Accounts are created on demand rather than at mint, because most never hold
     *         anything. The registry call is idempotent, so repeat calls are harmless.
     */
    function deployAccount(uint256 tokenId) external returns (address) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
        return LibERC6551.createAccount(ACCOUNT_IMPLEMENTATION, ACCOUNT_SALT, block.chainid, address(this), tokenId);
    }

    /**
     * @notice Replaces the metadata renderer.
     * @dev    The reveal is performed by pointing at the real renderer once artwork exists.
     */
    function setRenderer(address newRenderer) external onlyOwner {
        if (newRenderer == address(0)) revert RendererIsZeroAddress();
        emit RendererUpdated(address(renderer), newRenderer);
        renderer = IBearRenderer(newRenderer);
    }

    /// @inheritdoc ERC721SeaDrop
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
        return renderer.render(tokenId);
    }

    /**
     * @dev Records new bears' account addresses on mint, advances the transfer counter on
     *      every move, and refuses any destination that is a bear's account.
     */
    function _beforeTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity)
        internal
        virtual
        override
    {
        unchecked {
            if (from == address(0)) {
                // Record before checking `to`, so minting a bear into its own account is
                // caught by the same rule as every other case.
                for (uint256 i; i < quantity; ++i) {
                    isBearAccount[accountOf(startTokenId + i)] = true;
                }
            } else {
                for (uint256 i; i < quantity; ++i) {
                    ++transferNonce[startTokenId + i];
                }
            }
        }

        if (isBearAccount[to]) revert TransferToBearAccount();

        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }
}
