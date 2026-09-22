// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721SeaDrop} from "seadrop/ERC721SeaDrop.sol";
import {IBearRenderer} from "./interfaces/IBearRenderer.sol";

/**
 * @title  MintABear
 * @notice A 4,444-supply collection on Robinhood Chain, operated from OpenSea Studio.
 * @dev    Extends OpenSea's ERC721SeaDrop, which already implements ICreatorToken, so this is
 *         an ERC-721C contract. The SeaDrop mint path and `getMintStats` are untouched, per
 *         OpenSea's integration guidance.
 *
 *         Three behaviours are added on top:
 *
 *         1. A per-bear transfer counter. Activation stores a level alongside the counter
 *            value it was set at; when the counter moves, that level is void. The reset is
 *            therefore a consequence of the transfer rather than an action that has to
 *            succeed, so it can neither be skipped nor block the transfer itself.
 *
 *         2. A refusal to burn. The inherited `ERC721SeaDrop.burn` cannot be overridden, so
 *            it is neutralised in the transfer hook instead. Supply is 4,444 for good.
 *
 *         3. A hard supply ceiling of `MAX_BEARS`. The inherited `maxSupply` is an owner
 *            setting that can be raised at will; this one is a constant checked on the mint
 *            path, so 4,444 is a guarantee rather than a configuration choice.
 *
 *         The collection carries no token-bound accounts. ERC-6551 can be added later without
 *         any change here, because the canonical registry derives an account address from
 *         `(chainId, tokenContract, tokenId)` for any ERC-721.
 */
contract MintABear is ERC721SeaDrop {
    /// @notice The collection's permanent supply ceiling.
    /// @dev    `maxSupply` on the SeaDrop base is an owner setting: it starts at zero, and the
    ///         owner (or OpenSea Studio, through `multiConfigure`) can raise it at any time.
    ///         This cannot be changed by anyone, so the stated 4,444 is a property of the
    ///         code rather than of how the contract happens to be configured.
    uint256 public constant MAX_BEARS = 4444;

    /// @notice Contract that builds the metadata document. Replaceable; holds no user state.
    IBearRenderer public renderer;

    /// @notice How many times each bear has changed hands. Never incremented on mint.
    mapping(uint256 => uint64) public transferNonce;

    /// @notice Emitted when the metadata renderer is replaced.
    event RendererUpdated(address indexed previousRenderer, address indexed newRenderer);

    /// @notice The renderer address may not be zero.
    error RendererIsZeroAddress();

    /// @notice Bears cannot be burned. See `_beforeTokenTransfers`.
    error BurnDisabled();

    /// @notice The mint would take the collection past `MAX_BEARS`.
    error ExceedsMaxBears();

    /**
     * @param name_           Collection name. Permanent.
     * @param symbol_         Collection symbol. Permanent.
     * @param allowedSeaDrop_ SeaDrop contracts permitted to mint. Canonical SeaDrop on
     *                        Robinhood Chain is 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5.
     * @param renderer_       Initial renderer. Launches as the placeholder; replaced at reveal.
     */
    constructor(string memory name_, string memory symbol_, address[] memory allowedSeaDrop_, address renderer_)
        ERC721SeaDrop(name_, symbol_, allowedSeaDrop_)
    {
        if (renderer_ == address(0)) revert RendererIsZeroAddress();
        renderer = IBearRenderer(renderer_);
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
     * @dev Bounds supply on mint and advances the transfer counter on every move.
     *
     *      Also the only place a burn can be stopped. `ERC721SeaDrop` exposes a public
     *      `burn`, and declares it neither `virtual` nor internal, so it cannot be
     *      overridden — but every burn routes through this hook with `to` set to the zero
     *      address, and `to` is zero in no other case.
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
        } else {
            unchecked {
                for (uint256 i; i < quantity; ++i) {
                    ++transferNonce[startTokenId + i];
                }
            }
        }

        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }
}
