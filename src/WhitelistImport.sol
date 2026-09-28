// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "solady/auth/Ownable.sol";

/**
 * @title  WhitelistImport
 * @notice The owner-imported register of MintABear's whitelist: up to 1,000 allocations that MINT's
 *         admin writes from a CSV, frozen for good once `closeAt` has passed. It is the variant of
 *         `WhitelistClaim` for a whitelist MINT decides alone (WL-7); MINT deploys one of the two.
 *         The whitelist stage's allowlist in OpenSea Studio is exported from `claimants`, exactly
 *         as from `WhitelistClaim`, so anyone can recompute it from the chain and check it.
 * @dev    There is no voucher, no signer and no per-account cap. Until `closeAt` the owner can add
 *         allocations, remove a wallet and move the close; after it nothing can change, and
 *         `claimsOf(wallet)` is the wallet's eligibility for the whitelist stage. The reads share
 *         their names and types with `WhitelistClaim`, so the export, the Studio compare and the
 *         client's allowlist tree read either registry.
 *
 *         Every write is all or nothing: one bad row reverts the whole batch, so a failed import
 *         leaves no partial state and is retried once the CSV is fixed.
 *
 *         Slither reports `locked-ether` because Solady's ownership functions are `payable`
 *         (a gas saving). Anyone can call `requestOwnershipHandover` and
 *         `cancelOwnershipHandover`, so anyone could lock their own ETH by attaching value to
 *         them; nothing here withdraws it, and nothing else accepts ETH.
 */
contract WhitelistImport is Ownable {
    /// @notice Whitelist allocations in the campaign. Each is the right to mint one bear in the
    ///         whitelist stage.
    uint16 public constant TOTAL_SPOTS = 1000;

    /// @notice Allocations one wallet can hold.
    uint8 public constant MAX_PER_WALLET = 2;

    /// @notice One row of the export: a wallet and the allocations it holds.
    struct Claimant {
        address wallet;
        uint8 allocations;
    }

    /// @notice Last timestamp at which the owner can write the list; after it the list is frozen.
    /// @dev    `closeAt` and the spot counter share one storage slot (5 + 2 bytes).
    uint40 public closeAt;

    /// @dev Allocations written so far.
    uint16 private _spotsClaimed;

    /// @notice Allocations each wallet holds.
    mapping(address => uint8) public claimsOf;

    /// @dev Every wallet that holds an allocation, once each. Removal moves the last row into the
    ///      gap, so the list stays dense and the order of rows carries no meaning.
    address[] private _claimants;

    /// @dev A listed wallet's position in `_claimants`, plus one; zero for a wallet not listed.
    mapping(address => uint256) private _position;

    /// @notice `count` allocations were added to `wallet`, which now holds `total`.
    event AllocationsAdded(address indexed wallet, uint8 count, uint8 total);

    /// @notice `wallet`'s `count` allocations were removed, and it left the list.
    event AllocationsRemoved(address indexed wallet, uint8 count);

    /// @notice The close, after which the list is frozen, was set.
    event CloseSet(uint40 closeAt);

    /// @notice `closeAt` has passed: the list is frozen for good.
    error ListFrozen();

    /// @notice `wallets` and `counts` differ in length.
    error LengthMismatch();

    /// @notice A row names the zero address.
    error ZeroWallet();

    /// @notice A row adds no allocations.
    error ZeroCount();

    /// @notice A wallet would hold more than `MAX_PER_WALLET` allocations.
    error WalletLimit();

    /// @notice The list would hold more than `TOTAL_SPOTS` allocations.
    error SoldOut();

    /// @notice A wallet to remove holds no allocations.
    error NotListed();

    /// @notice A close in the past.
    error InvalidWindow();

    /// @notice Ownership can be handed over, never renounced.
    error RenounceDisabled();

    /**
     * @param owner_   MINT's admin: writes the list and moves the close. Not the zero address.
     * @param closeAt_ Last timestamp at which the list can be written; not in the past, and at
     *                 least 48 hours before the whitelist stage opens.
     */
    constructor(address owner_, uint40 closeAt_) {
        // Solady's `_initializeOwner` accepts the zero address; an ownerless list could never be
        // written, so it is refused as `transferOwnership` refuses it.
        if (owner_ == address(0)) revert NewOwnerIsZeroAddress();
        _initializeOwner(owner_);
        _setCloseAt(closeAt_);
    }

    /**
     * @notice Gives each wallet `counts[i]` more allocations.
     * @dev    Refused whole, in this order: `ListFrozen`, `LengthMismatch`; then for each row in
     *         turn `ZeroWallet`, `ZeroCount`, `WalletLimit` (counting the rows before it, so a
     *         wallet named twice is capped on its total), and `SoldOut` on the running total.
     * @param  wallets The wallets, one per row of the CSV.
     * @param  counts  The allocations each row adds.
     */
    function addAllocations(address[] calldata wallets, uint8[] calldata counts) external onlyOwner {
        _requireOpen();
        if (wallets.length != counts.length) revert LengthMismatch();
        uint16 claimed = _spotsClaimed;
        for (uint256 i; i < wallets.length; ++i) {
            address wallet = wallets[i];
            uint8 count = counts[i];
            if (wallet == address(0)) revert ZeroWallet();
            if (count == 0) revert ZeroCount();
            uint8 held = claimsOf[wallet];
            // `held ≤ MAX_PER_WALLET` and `claimed ≤ TOTAL_SPOTS` always, so neither subtraction
            // underflows, and comparing against the room left never overflows a narrow type.
            if (count > MAX_PER_WALLET - held) revert WalletLimit();
            if (count > TOTAL_SPOTS - claimed) revert SoldOut();
            claimed += count;
            if (held == 0) {
                _claimants.push(wallet);
                _position[wallet] = _claimants.length;
            }
            uint8 total = held + count;
            claimsOf[wallet] = total;
            emit AllocationsAdded(wallet, count, total);
        }
        _spotsClaimed = claimed;
    }

    /**
     * @notice Sets each wallet's allocations to zero and drops it from the list.
     * @dev    Refused whole with `ListFrozen`, or `NotListed` for a wallet holding none (a wallet
     *         named twice is not listed the second time).
     * @param  wallets The wallets to remove.
     */
    function removeAllocations(address[] calldata wallets) external onlyOwner {
        _requireOpen();
        uint16 claimed = _spotsClaimed;
        for (uint256 i; i < wallets.length; ++i) {
            address wallet = wallets[i];
            uint8 count = claimsOf[wallet];
            if (count == 0) revert NotListed();
            claimed -= count;
            delete claimsOf[wallet];
            uint256 slot = _position[wallet] - 1;
            address last = _claimants[_claimants.length - 1];
            _claimants[slot] = last;
            _position[last] = slot + 1;
            _claimants.pop();
            delete _position[wallet];
            emit AllocationsRemoved(wallet, count);
        }
        _spotsClaimed = claimed;
    }

    /**
     * @notice Moves the close: extends the import, or freezes the list early.
     * @param  closeAt_ The new close; not in the past.
     */
    function setCloseAt(uint40 closeAt_) external onlyOwner {
        _requireOpen();
        _setCloseAt(closeAt_);
    }

    /// @notice Refused for every caller, the owner included, so the list always has a writer until
    ///         it freezes.
    function renounceOwnership() public payable override {
        revert RenounceDisabled();
    }

    /// @notice Whether `closeAt` has passed, after which nothing can change the list.
    function frozen() public view returns (bool) {
        return block.timestamp > closeAt;
    }

    /// @notice Allocations still unwritten — "spots left — X / 1,000".
    function spotsLeft() external view returns (uint256) {
        return TOTAL_SPOTS - _spotsClaimed;
    }

    /**
     * @notice A page of the list, for the export to the Studio allowlist: each listed wallet once,
     *         with the allocations it holds.
     * @dev    A page past the end is short or empty; the export reads pages until one comes back
     *         shorter than `limit`.
     * @param  offset Index of the first row.
     * @param  limit  Most rows to return.
     */
    function claimants(uint256 offset, uint256 limit) external view returns (Claimant[] memory rows) {
        uint256 total = _claimants.length;
        uint256 end = offset >= total ? offset : (limit > total - offset ? total : offset + limit);
        rows = new Claimant[](end - offset);
        for (uint256 i; i < rows.length; ++i) {
            address wallet = _claimants[offset + i];
            rows[i] = Claimant({wallet: wallet, allocations: claimsOf[wallet]});
        }
    }

    function _requireOpen() private view {
        if (frozen()) revert ListFrozen();
    }

    function _setCloseAt(uint40 closeAt_) private {
        if (closeAt_ < block.timestamp) revert InvalidWindow();
        closeAt = closeAt_;
        emit CloseSet(closeAt_);
    }
}
