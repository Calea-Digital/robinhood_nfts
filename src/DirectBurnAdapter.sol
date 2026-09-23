// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Activation} from "./Activation.sol";
import {IMintABear} from "./interfaces/IMintABear.sol";

/// @dev The one function of $MNTD the adapter relies on: OpenZeppelin `ERC20Burnable.burnFrom`.
interface IBurnableMNTD {
    function burnFrom(address account, uint256 amount) external;
}

/**
 * @title  DirectBurnAdapter
 * @notice The same-chain burn route: a holder burns $MNTD for their bear here, and the burn is
 *         credited to `Activation` in the same transaction.
 * @dev    The holder approves this contract on $MNTD once, then calls `burn(tokenId, amount)`.
 *         It is `Activation`'s one crediter. It has no owner and no settings: a new token address
 *         means a new adapter and one `Activation.setCrediter` call.
 *
 *         The credit is recorded before `burnFrom` is called. $MNTD is outside this codebase, so
 *         its `burnFrom` is treated as untrusted: any revert in it undoes the credit, and a
 *         call back into `burn` from inside it sees the cumulative already raised, so the
 *         overshoot guard still holds and each nested credit needs its own successful burn.
 *         Transferring the bear from inside `burnFrom` voids the caller's own record. The event
 *         is emitted before `burnFrom` too, so nested burns log in call order and a failed burn
 *         takes its event with it. While
 *         `Activation` is paused, `credit` reverts, so no $MNTD is burned.
 */
contract DirectBurnAdapter {
    /// @notice The token burned.
    IBurnableMNTD public immutable MNTD;

    /// @notice The level record credited.
    Activation public immutable ACTIVATION;

    /// @dev The collection `ACTIVATION` reads, taken from it at construction.
    IMintABear internal immutable BEARS;

    /// @notice Burns made through this adapter; the latest is also the latest `ref`.
    uint256 public burnCount;

    /// @notice `burner` burned `amount` of $MNTD for `tokenId`; `ref` is this adapter's burn number.
    event BurnedForBear(bytes32 indexed ref, uint256 indexed tokenId, address indexed burner, uint256 amount);

    /// @notice The caller does not own the bear.
    error NotOwner();

    /// @notice The bear is already at level 5.
    error AlreadyAtMaxLevel();

    /// @notice The amount is more than the bear needs to reach level 5.
    error Overshoot();

    /// @notice Neither the token nor `Activation` can be the zero address.
    error ZeroAddress();

    /**
     * @param mntd_       The $MNTD token on Robinhood Chain, exposing `burnFrom(address, uint256)`.
     * @param activation_ The `Activation` contract this adapter credits.
     */
    constructor(address mntd_, address activation_) {
        if (mntd_ == address(0) || activation_ == address(0)) revert ZeroAddress();
        MNTD = IBurnableMNTD(mntd_);
        ACTIVATION = Activation(activation_);
        BEARS = Activation(activation_).BEARS();
    }

    /**
     * @notice Burns `amount` of the caller's $MNTD for `tokenId` and credits it.
     * @dev    Reverts with `NotOwner` unless the caller owns the bear, `AlreadyAtMaxLevel` at
     *         level 5, and `Overshoot` when `amount` exceeds `costToReach(tokenId, 5)`; size a
     *         burn with `costToReach(tokenId, targetLevel)`. `Activation`'s own reverts (pause,
     *         zero amount) and the token's (allowance, balance) undo the whole call.
     * @param  tokenId The bear.
     * @param  amount  Base units of $MNTD to burn.
     */
    function burn(uint256 tokenId, uint128 amount) external {
        if (BEARS.ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (ACTIVATION.levelOf(tokenId) == 5) revert AlreadyAtMaxLevel();
        if (amount > ACTIVATION.costToReach(tokenId, 5)) revert Overshoot();

        bytes32 ref = bytes32(++burnCount);
        ACTIVATION.credit(tokenId, msg.sender, amount, BEARS.transferNonce(tokenId), ref);
        emit BurnedForBear(ref, tokenId, msg.sender, amount);
        MNTD.burnFrom(msg.sender, amount);
    }
}
