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
 *         Four behaviours are added on top:
 *
 *         1. A per-bear transfer counter. Activation stores a level alongside the counter
 *            value it was set at; when the counter moves, that level is void. The reset is
 *            therefore a consequence of the transfer rather than an action that has to
 *            succeed, so it can neither be skipped nor block the transfer itself.
 *
 *         2. A standing refusal to send a bear into any bear's account. Addresses are
 *            recorded at mint and can be pre-recorded for the whole supply beforehand, so
 *            the rule holds even for accounts that have never been deployed.
 *
 *         3. A refusal to burn. The inherited `ERC721SeaDrop.burn` cannot be overridden, so
 *            it is neutralised in the transfer hook instead. A burned bear would strand its
 *            account's contents permanently.
 *
 *         4. A hard supply ceiling of `MAX_BEARS`. The inherited `maxSupply` is an owner
 *            setting that can be raised at will; this one is a constant checked on the mint
 *            path, so 4,444 is a guarantee rather than a configuration choice.
 */
contract MintABear is ERC721SeaDrop {
    /// @notice The collection's permanent supply ceiling.
    /// @dev    `maxSupply` on the SeaDrop base is an owner setting: it starts at zero, and the
    ///         owner (or OpenSea Studio, through `multiConfigure`) can raise it at any time.
    ///         This cannot be changed by anyone, so the stated 4,444 is a property of the
    ///         code rather than of how the contract happens to be configured.
    uint256 public constant MAX_BEARS = 4444;

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

    /// @notice Emitted when a range of bears' account addresses is pre-recorded.
    event AccountsRecorded(uint256 fromTokenId, uint256 toTokenId);

    /// @notice A bear may never be owned by any bear's account, at any depth.
    error TransferToBearAccount();

    /// @notice The renderer address may not be zero.
    error RendererIsZeroAddress();

    /// @notice The account implementation may not be zero: every bear's account derives
    ///         from it, and a zero implementation would fix all 4,444 addresses for good.
    error AccountImplementationIsZeroAddress();

    /// @notice Bears cannot be burned. See `_beforeTokenTransfers`.
    error BurnDisabled();

    /// @notice The queried bear has not been minted.
    error BearDoesNotExist();

    /// @notice The supplied token id range is empty, starts at zero, or exceeds `MAX_BEARS`.
    error InvalidTokenRange();

    /// @notice The mint would take the collection past `MAX_BEARS`.
    error ExceedsMaxBears();

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
        if (accountImplementation_ == address(0)) revert AccountImplementationIsZeroAddress();
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
        if (!_exists(tokenId)) revert BearDoesNotExist();
        return LibERC6551.createAccount(ACCOUNT_IMPLEMENTATION, ACCOUNT_SALT, block.chainid, address(this), tokenId);
    }

    /**
     * @notice Records the canonical account addresses for a range of bears in advance.
     * @dev    `_beforeTokenTransfers` records each bear's account as that bear is minted,
     *         which leaves a window: until bear N is minted, its account address is not yet
     *         in `isBearAccount`, so another bear can be sent there and ends up owned by a
     *         bear once N mints. Recording the whole supply before the mint opens closes it.
     *
     *         Permissionless, because the only addresses it can ever mark are ones this
     *         contract itself derives, and idempotent, so it is safely run in batches. The
     *         range is bounded by `MAX_BEARS` rather than by `maxSupply`, so it can be run
     *         immediately after deployment and never needs repeating if supply is raised.
     */
    function recordAccounts(uint256 fromTokenId, uint256 toTokenId) external {
        if (fromTokenId == 0 || toTokenId < fromTokenId || toTokenId > MAX_BEARS) {
            revert InvalidTokenRange();
        }
        unchecked {
            for (uint256 id = fromTokenId; id <= toTokenId; ++id) {
                isBearAccount[accountOf(id)] = true;
            }
        }
        emit AccountsRecorded(fromTokenId, toTokenId);
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
     *
     *      Also the only place a burn can be stopped. `ERC721SeaDrop` exposes a public
     *      `burn`, and declares it neither `virtual` nor internal, so it cannot be
     *      overridden — but every burn routes through this hook with `to` set to the zero
     *      address, and `to` is zero in no other case. Burning has to be refused because a
     *      burned bear's account keeps whatever it holds while resolving its owner through
     *      `ownerOf`, which no longer answers: the contents would be unreachable for good.
     */
    function _beforeTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity)
        internal
        virtual
        override
    {
        if (to == address(0)) revert BurnDisabled();

        if (from == address(0)) {
            // Checked arithmetic deliberately: this is the one place supply is bounded.
            if (startTokenId + quantity - 1 > MAX_BEARS) revert ExceedsMaxBears();
            // Record before checking `to`, so minting a bear into its own account is
            // caught by the same rule as every other case.
            unchecked {
                for (uint256 i; i < quantity; ++i) {
                    isBearAccount[accountOf(startTokenId + i)] = true;
                }
            }
        } else {
            unchecked {
                for (uint256 i; i < quantity; ++i) {
                    ++transferNonce[startTokenId + i];
                }
            }
        }

        if (isBearAccount[to]) revert TransferToBearAccount();

        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }
}
