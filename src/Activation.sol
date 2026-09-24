// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "solady/auth/Ownable.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {IMintABear} from "./interfaces/IMintABear.sol";

/// @dev The two functions of $MNTD `Activation` calls: `decimals` once, in the constructor, and
///      OpenZeppelin `ERC20Burnable.burnFrom` in `burn`.
interface IBurnableMNTD {
    function decimals() external view returns (uint8);
    function burnFrom(address account, uint256 amount) external;
}

/**
 * @title  Activation
 * @notice The record of $MNTD burned into each bear: its level, its royalty weight and its
 *         owner's Status link. A transfer resets all three.
 * @dev    One token, one collection. $MNTD — native to Robinhood Chain — is fixed in the
 *         constructor, and the only thing done with it is burning the caller's own balance in
 *         `burn`. Recording and burning are two steps of one transaction, the record first: a
 *         token that calls back during `burnFrom` meets `nonReentrant`, and any revert undoes
 *         both. $MNTD is outside this codebase, so its `burnFrom` is untrusted: it must revert on
 *         failure (CQ-2). A different token address means a new `Activation`.
 *
 *         It reads `MintABear` — `ownerOf`, `transferNonce`, `exists` — and `MintABear` never
 *         calls it. The reset works through the token's per-bear transfer counter: a record is
 *         stored with the counter value it was made at, and reads as zero once the counter has
 *         moved. Nothing executes at reset time, so a reset can be neither skipped nor made to
 *         block a transfer; indexers key it on the token's `TransferNonceAdvanced`.
 *
 *         Levels are derived from a running total, so reaching level 5 in one burn and in
 *         twenty is the same thing. Thresholds (given in whole $MNTD, stored in base units) and
 *         weights (basis 100) are constructor arguments with no setter; the owner can only pause,
 *         and can hand ownership over but never renounce it.
 *
 *         Slither reports `locked-ether` because Solady's ownership functions are `payable`
 *         (a gas saving). Anyone can call `requestOwnershipHandover` and
 *         `cancelOwnershipHandover`, so anyone could lock their own ETH by attaching value to
 *         them; nothing here withdraws it, and nothing else accepts ETH.
 */
contract Activation is Ownable, ReentrancyGuard {
    /// @notice Cumulative burn, in $MNTD base units, at which each level is reached.
    uint128 public immutable THRESHOLD_1;
    uint128 public immutable THRESHOLD_2;
    uint128 public immutable THRESHOLD_3;
    uint128 public immutable THRESHOLD_4;
    uint128 public immutable THRESHOLD_5;

    /// @dev Royalty weight of each level 0–5, basis 100.
    uint16 internal immutable WEIGHT_0;
    uint16 internal immutable WEIGHT_1;
    uint16 internal immutable WEIGHT_2;
    uint16 internal immutable WEIGHT_3;
    uint16 internal immutable WEIGHT_4;
    uint16 internal immutable WEIGHT_5;

    /// @notice The collection this contract tracks.
    IMintABear public immutable BEARS;

    /// @notice The token burned for levels.
    IBurnableMNTD public immutable MNTD;

    /// @notice $MNTD's decimals, read at construction; the thresholds were scaled by them.
    uint8 public immutable DECIMALS;

    /// @notice One row of `snapshot`.
    struct BearState {
        address owner;
        uint8 level;
        uint16 weight;
    }

    /// @dev A bear's cumulative burn and the transfer count it was recorded at. One slot.
    struct Record {
        uint128 cumulative;
        uint64 nonce;
    }

    mapping(uint256 => Record) private _records;

    /// @notice Every amount ever burned for a bear, across all owners. Never reset.
    mapping(uint256 => uint256) public lifetimeBurned;

    /// @dev Wallet's nominated bear, and the transfer count it was nominated at.
    mapping(address => uint256) private _linkedBear;
    mapping(address => uint64) private _linkedAtNonce;

    /// @notice When true, `burn` and `linkBear` are suspended. Never affects a transfer.
    bool public paused;

    /// @notice $MNTD was burned for a bear. `cumulative` is the bear's total for its current owner.
    event BearActivated(
        uint256 indexed tokenId,
        address indexed burner,
        uint8 previousLevel,
        uint8 newLevel,
        uint256 amount,
        uint256 cumulative
    );
    event BearLinked(address indexed wallet, uint256 indexed tokenId);
    event BearUnlinked(address indexed wallet, uint256 indexed tokenId);
    event PausedSet(bool paused);

    /// @notice `burn` and `linkBear` are suspended.
    error ContractPaused();

    /// @notice A burn must be of a positive amount.
    error ZeroAmount();

    /// @notice The caller does not own the bear.
    error NotBearOwner();

    /// @notice The bear is already at level 5.
    error AlreadyAtMaxLevel();

    /// @notice The amount exceeds what the bear needs to reach level 5.
    error Overshoot();

    /// @notice The five thresholds must be positive and strictly ascending.
    error ThresholdsNotAscending();

    /// @notice The six weights must be strictly ascending.
    error WeightsNotAscending();

    /// @notice The collection and the token cannot be the zero address.
    error ZeroAddress();

    /// @notice Levels run 0 to 5.
    error InvalidLevel();

    /// @notice Ownership can be handed over, never renounced.
    error RenounceDisabled();

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    function _requireNotPaused() internal view {
        if (paused) revert ContractPaused();
    }

    /**
     * @param bears_          The MintABear collection.
     * @param mntd_           $MNTD on Robinhood Chain. Final: a different token means a new
     *                        `Activation`.
     * @param thresholdsWhole The five cumulative thresholds in whole $MNTD, positive and strictly
     *                        ascending (1,666 / 3,333 / 8,333 / 16,666 / 41,666); scaled here by
     *                        the token's `decimals` into base units.
     * @param weights_        The six royalty weights of levels 0–5, basis 100, strictly ascending
     *                        (100 / 110 / 125 / 145 / 170 / 200).
     */
    constructor(address bears_, address mntd_, uint128[5] memory thresholdsWhole, uint16[6] memory weights_) {
        if (bears_ == address(0) || mntd_ == address(0)) revert ZeroAddress();
        if (thresholdsWhole[0] == 0) revert ThresholdsNotAscending();
        for (uint256 i = 1; i < 5; ++i) {
            if (thresholdsWhole[i] <= thresholdsWhole[i - 1]) revert ThresholdsNotAscending();
        }
        for (uint256 i = 1; i < 6; ++i) {
            if (weights_[i] <= weights_[i - 1]) revert WeightsNotAscending();
        }

        _initializeOwner(msg.sender);
        BEARS = IMintABear(bears_);
        MNTD = IBurnableMNTD(mntd_);

        uint8 decimals_ = IBurnableMNTD(mntd_).decimals();
        DECIMALS = decimals_;
        uint256 unit = 10 ** uint256(decimals_);
        THRESHOLD_1 = SafeCastLib.toUint128(uint256(thresholdsWhole[0]) * unit);
        THRESHOLD_2 = SafeCastLib.toUint128(uint256(thresholdsWhole[1]) * unit);
        THRESHOLD_3 = SafeCastLib.toUint128(uint256(thresholdsWhole[2]) * unit);
        THRESHOLD_4 = SafeCastLib.toUint128(uint256(thresholdsWhole[3]) * unit);
        THRESHOLD_5 = SafeCastLib.toUint128(uint256(thresholdsWhole[4]) * unit);

        WEIGHT_0 = weights_[0];
        WEIGHT_1 = weights_[1];
        WEIGHT_2 = weights_[2];
        WEIGHT_3 = weights_[3];
        WEIGHT_4 = weights_[4];
        WEIGHT_5 = weights_[5];
    }

    /**
     * @notice Burns `amount` of the caller's $MNTD for `tokenId` and records it.
     * @dev    The caller must own the bear; the approval is on this contract. Reverts, in this
     *         order, with `ContractPaused`, `ZeroAmount`, `NotBearOwner`, `AlreadyAtMaxLevel` or
     *         `Overshoot` (above `costToReach(tokenId, 5)`); size a burn with
     *         `costToReach(tokenId, targetLevel)`. An id never minted reverts in the collection's
     *         `ownerOf` with `OwnerQueryForNonexistentToken`, where `NotBearOwner` would be. The
     *         record is written and `BearActivated` emitted before `burnFrom`, and the token's own
     *         reverts (allowance, balance) undo the whole call. Non-reentrant: a `burn` from
     *         inside `burnFrom` reverts.
     * @param  tokenId The bear.
     * @param  amount  Base units of $MNTD to burn.
     */
    function burn(uint256 tokenId, uint128 amount) external nonReentrant {
        _requireNotPaused();
        if (amount == 0) revert ZeroAmount();
        if (BEARS.ownerOf(tokenId) != msg.sender) revert NotBearOwner();

        uint64 nonce = BEARS.transferNonce(tokenId);
        Record storage record = _records[tokenId];
        uint128 cumulative = record.nonce == nonce ? record.cumulative : 0;
        if (cumulative >= THRESHOLD_5) revert AlreadyAtMaxLevel();
        if (amount > THRESHOLD_5 - cumulative) revert Overshoot();

        uint128 newCumulative = cumulative + amount;
        record.cumulative = newCumulative;
        record.nonce = nonce;
        lifetimeBurned[tokenId] += amount;

        emit BearActivated(tokenId, msg.sender, _levelFor(cumulative), _levelFor(newCumulative), amount, newCumulative);
        MNTD.burnFrom(msg.sender, amount);
    }

    /**
     * @notice Nominates a bear to carry this wallet's Status multiplier. One per wallet; a new
     *         nomination replaces the previous one.
     * @dev    Owner of the bear only (`NotBearOwner`; an id never minted reverts in the
     *         collection's `ownerOf` with `OwnerQueryForNonexistentToken`). The nomination is void
     *         once the bear moves, so a previous owner cannot keep the boost after selling.
     */
    function linkBear(uint256 tokenId) external whenNotPaused {
        if (BEARS.ownerOf(tokenId) != msg.sender) revert NotBearOwner();
        _linkedBear[msg.sender] = tokenId;
        _linkedAtNonce[msg.sender] = BEARS.transferNonce(tokenId);
        emit BearLinked(msg.sender, tokenId);
    }

    /**
     * @notice Removes this wallet's nomination without moving the bear.
     * @dev    Works while paused. A wallet with no nomination is left alone rather than
     *         reverting, so the portal can call this unconditionally, and no event is emitted:
     *         an indexer never sees an unlink that did not follow a link.
     */
    function unlinkBear() external {
        uint256 tokenId = _linkedBear[msg.sender];
        if (tokenId == 0) return;
        delete _linkedBear[msg.sender];
        delete _linkedAtNonce[msg.sender];
        emit BearUnlinked(msg.sender, tokenId);
    }

    /// @notice The $MNTD burned for a bear under its current owner. Zero after a transfer.
    function cumulativeOf(uint256 tokenId) public view returns (uint128) {
        Record memory record = _records[tokenId];
        return record.nonce == BEARS.transferNonce(tokenId) ? record.cumulative : 0;
    }

    /// @notice A bear's current level, 0 to 5. Zero after a transfer.
    function levelOf(uint256 tokenId) public view returns (uint8) {
        return _levelFor(cumulativeOf(tokenId));
    }

    /// @notice A bear's current royalty weight, basis 100: the weight of its level.
    function weightOf(uint256 tokenId) external view returns (uint16) {
        return weightFor(levelOf(tokenId));
    }

    /**
     * @notice The bear carrying a wallet's Status multiplier.
     * @return tokenId The nominated bear, or zero if there is none or it has moved since.
     * @return level   That bear's level, or zero.
     */
    function linkOf(address wallet) external view returns (uint256 tokenId, uint8 level) {
        tokenId = _linkedBear[wallet];
        if (tokenId == 0) return (0, 0);
        if (_linkedAtNonce[wallet] != BEARS.transferNonce(tokenId)) return (0, 0);
        return (tokenId, levelOf(tokenId));
    }

    /**
     * @notice Owner, level and weight for each id, for MINT's royalty split at a closing block.
     * @dev    An id that does not exist reads as zeroes. A wallet's weight is the sum over its
     *         bears; the eligible total excludes bears held by `0x…dEaD`, summed off-chain. The
     *         loop's calls go only to the immutable collection, and are views.
     */
    function snapshot(uint256[] calldata ids) external view returns (BearState[] memory rows) {
        rows = new BearState[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            uint256 id = ids[i];
            if (!BEARS.exists(id)) continue;
            uint8 level = levelOf(id);
            rows[i] = BearState({owner: BEARS.ownerOf(id), level: level, weight: weightFor(level)});
        }
    }

    /**
     * @notice How much more $MNTD a bear needs to reach a level.
     * @dev    The portal sizes each burn with this, and `burn` refuses any amount above
     *         `costToReach(tokenId, 5)`.
     * @return The remaining base units, or zero if the level is already reached.
     */
    function costToReach(uint256 tokenId, uint8 targetLevel) external view returns (uint128) {
        uint128 target = thresholdFor(targetLevel);
        uint128 cumulative = cumulativeOf(tokenId);
        return cumulative >= target ? 0 : target - cumulative;
    }

    /// @notice The cumulative burn a level requires, in base units. Level 0 costs nothing.
    function thresholdFor(uint8 level) public view returns (uint128) {
        if (level == 0) return 0;
        if (level == 1) return THRESHOLD_1;
        if (level == 2) return THRESHOLD_2;
        if (level == 3) return THRESHOLD_3;
        if (level == 4) return THRESHOLD_4;
        if (level == 5) return THRESHOLD_5;
        revert InvalidLevel();
    }

    /// @notice The royalty weight of a level, basis 100.
    function weightFor(uint8 level) public view returns (uint16) {
        if (level == 0) return WEIGHT_0;
        if (level == 1) return WEIGHT_1;
        if (level == 2) return WEIGHT_2;
        if (level == 3) return WEIGHT_3;
        if (level == 4) return WEIGHT_4;
        if (level == 5) return WEIGHT_5;
        revert InvalidLevel();
    }

    /// @notice Suspends or resumes `burn` and `linkBear`. Transfers are never affected.
    function setPaused(bool paused_) external onlyOwner {
        paused = paused_;
        emit PausedSet(paused_);
    }

    /// @notice Refused for every caller, the owner included, so the pause can always be set and
    ///         lifted.
    function renounceOwnership() public payable override {
        revert RenounceDisabled();
    }

    function _levelFor(uint128 cumulative) internal view returns (uint8) {
        if (cumulative >= THRESHOLD_5) return 5;
        if (cumulative >= THRESHOLD_4) return 4;
        if (cumulative >= THRESHOLD_3) return 3;
        if (cumulative >= THRESHOLD_2) return 2;
        if (cumulative >= THRESHOLD_1) return 1;
        return 0;
    }
}
