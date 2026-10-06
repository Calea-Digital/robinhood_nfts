// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721SeaDrop} from "seadrop/ERC721SeaDrop.sol";

/**
 * @title  MintABear
 * @notice A 4,444-supply ERC-721 collection minted through SeaDrop.
 * @dev    Extends `ERC721SeaDrop`, which implements ICreatorToken (ERC-721C). Adds to it:
 *         - `transferNonce`, a per-token counter advanced on every non-mint transfer, with
 *           `TransferNonceAdvanced` emitted alongside `Transfer`;
 *         - `MAX_BEARS`, a constant supply ceiling checked on every mint;
 *         - refusal of `burn` and of any transfer to the zero address (`BurnDisabled`);
 *         - refusal of `renounceOwnership` (`RenounceDisabled`).
 */
contract MintABear is ERC721SeaDrop {
    /// @notice Maximum number of tokens that can ever be minted. Checked on every mint,
    ///         independently of the owner-set `maxSupply`.
    uint256 public constant MAX_BEARS = 4444;

    /// @notice Number of non-mint transfers of each token.
    mapping(uint256 => uint64) public transferNonce;

    /// @notice Emitted with every non-mint `Transfer`, carrying the token's new `transferNonce`.
    event TransferNonceAdvanced(uint256 indexed tokenId, uint64 nonce);

    /// @notice `burn` and transfers to the zero address are refused for every caller.
    error BurnDisabled();

    /// @notice The mint would take the collection past `MAX_BEARS`.
    error ExceedsMaxBears();

    /// @notice `renounceOwnership` is refused for every caller.
    error RenounceDisabled();

    /**
     * @param name_           Collection name.
     * @param symbol_         Collection symbol.
     * @param allowedSeaDrop_ SeaDrop contracts permitted to mint.
     */
    constructor(string memory name_, string memory symbol_, address[] memory allowedSeaDrop_)
        ERC721SeaDrop(name_, symbol_, allowedSeaDrop_)
    {}

    /// @notice Whether `tokenId` has been minted. Tokens cannot be burned, so this never
    ///         returns to false. Never reverts.
    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }

    /**
     * @notice Always reverts with `RenounceDisabled`. Ownership moves only by `transferOwnership`
     *         and `acceptOwnership`.
     */
    function renounceOwnership() public virtual override {
        revert RenounceDisabled();
    }

    /**
     * @notice Transfers `tokenId` from `from` to `to`. Reverts with `BurnDisabled` when `to` is
     *         the zero address. `safeTransferFrom` routes through this function.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        if (to == address(0)) revert BurnDisabled();
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @dev Refuses a transfer to the zero address (this is what refuses `burn`, which is not
     *      virtual). On mint, refuses ids past `MAX_BEARS`; otherwise advances `transferNonce`
     *      and emits `TransferNonceAdvanced` for each token moved.
     */
    function _beforeTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity)
        internal
        virtual
        override
    {
        if (to == address(0)) revert BurnDisabled();

        if (from == address(0)) {
            // Checked arithmetic: this bounds supply.
            if (startTokenId + quantity - 1 > MAX_BEARS) revert ExceedsMaxBears();
        } else {
            unchecked {
                for (uint256 i; i < quantity; ++i) {
                    uint256 tokenId = startTokenId + i;
                    emit TransferNonceAdvanced(tokenId, ++transferNonce[tokenId]);
                }
            }
        }

        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }
}
