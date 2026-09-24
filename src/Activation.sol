// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "solady/auth/Ownable.sol";
import {IMintABear} from "./interfaces/IMintABear.sol";

/**
 * @title  Activation
 * @notice The record of $MNTD burned into each bear: its level, its royalty weight and its
 *         owner's Status link. A transfer resets all three.
 * @dev    Token-agnostic. This contract holds no reference to $MNTD and never moves a token.
 *         Burning and recording are two steps of one transaction: the crediter (the
 *         `DirectBurnAdapter` on Robinhood Chain) burns the holder's $MNTD, then calls `credit`
 *         with "this wallet burned this amount for this bear". Only the crediter can credit, and
 *         a new token address means a new adapter and one `setCrediter` call — nothing here
 *         changes.
 *
 *         It reads `MintABear` — `ownerOf`, `transferNonce`, `exists` — and `MintABear` never
 *         calls it. The reset works through the token's per-bear transfer counter: a record is
 *         stored with the counter value it was made at, and reads as zero once the counter has
 *         moved. Nothing executes at reset time, so a reset can be neither skipped nor made to
 *         block a transfer; indexers key it on the token's `TransferNonceAdvanced`.
 *
 *         Levels are derived from a running total, so reaching level 5 in one credit and in
 *         twenty is the same thing. Thresholds (base units) and weights (basis 100) are
 *         constructor arguments with no setter; the owner can only set the crediter and pause.
 *
 *         Slither reports `locked-ether` because Solady's ownership functions are `payable`
 *         (a gas saving). Anyone can call `requestOwnershipHandover` and
 *         `cancelOwnershipHandover`, so anyone could lock their own ETH by attaching value to
 *         them; nothing here withdraws it, and nothing else accepts ETH.
 */
contract Activation is Ownable {
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

    /// @notice Every amount ever credited to a bear, across all owners. Never reset.
    mapping(uint256 => uint256) public lifetimeBurned;

    /// @dev References already recorded, per crediter; each is accepted once from its crediter.
    ///      Keyed by crediter because a ref is that crediter's own burn number: a replacement
    ///      adapter counts from 1 again and must not collide with its predecessor's refs.
    mapping(address => mapping(bytes32 => bool)) private _refUsed;

    /// @dev Wallet's nominated bear, and the transfer count it was nominated at.
    mapping(address => uint256) private _linkedBear;
    mapping(address => uint64) private _linkedAtNonce;

    /// @notice The one address allowed to call `credit`.
    address public crediter;

    /// @notice When true, `credit` and `linkBear` are suspended. Never affects a transfer.
    bool public paused;

    /// @notice A credit was recorded. `cumulative` is the bear's total for its current owner.
    event BearActivated(
        uint256 indexed tokenId,
        address indexed burner,
        uint8 previousLevel,
        uint8 newLevel,
        uint256 amount,
        uint256 cumulative,
        bytes32 indexed ref
    );
    event BearLinked(address indexed wallet, uint256 indexed tokenId);
    event BearUnlinked(address indexed wallet, uint256 indexed tokenId);
    event CrediterSet(address indexed previous, address indexed current);
    event PausedSet(bool paused);

    /// @notice The caller is not the crediter.
    error NotCrediter();

    /// @notice `credit` and `linkBear` are suspended.
    error ContractPaused();

    /// @notice A credit must be of a positive amount.
    error ZeroAmount();

    /// @notice The burner, or the caller, does not own the bear.
    error NotBearOwner();

    /// @notice The bear has changed hands since the crediter read its transfer count.
    error StaleNonce();

    /// @notice This crediter has already recorded this reference.
    error RefAlreadyUsed();

    /// @notice The five thresholds must be positive and strictly ascending.
    error ThresholdsNotAscending();

    /// @notice The six weights must be strictly ascending.
    error WeightsNotAscending();

    /// @notice The collection cannot be the zero address.
    error ZeroAddress();

    /// @notice Levels run 0 to 5.
    error InvalidLevel();

    /// @notice Ownership may not be given up while credits and links are suspended.
    error CannotRenounceWhilePaused();

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    function _requireNotPaused() internal view {
        if (paused) revert ContractPaused();
    }

    /**
     * @param bears_      The MintABear collection.
     * @param thresholds_ The five cumulative thresholds in $MNTD base units, positive and
     *                    strictly ascending (1,666 / 3,333 / 8,333 / 16,666 / 41,666 whole
     *                    $MNTD, scaled by its decimals before deployment).
     * @param weights_    The six royalty weights of levels 0–5, basis 100, strictly ascending
     *                    (100 / 110 / 125 / 145 / 170 / 200).
     */
    constructor(address bears_, uint128[5] memory thresholds_, uint16[6] memory weights_) {
        if (bears_ == address(0)) revert ZeroAddress();
        if (thresholds_[0] == 0) revert ThresholdsNotAscending();
        for (uint256 i = 1; i < 5; ++i) {
            if (thresholds_[i] <= thresholds_[i - 1]) revert ThresholdsNotAscending();
        }
        for (uint256 i = 1; i < 6; ++i) {
            if (weights_[i] <= weights_[i - 1]) revert WeightsNotAscending();
        }

        _initializeOwner(msg.sender);
        BEARS = IMintABear(bears_);

        THRESHOLD_1 = thresholds_[0];
        THRESHOLD_2 = thresholds_[1];
        THRESHOLD_3 = thresholds_[2];
        THRESHOLD_4 = thresholds_[3];
        THRESHOLD_5 = thresholds_[4];

        WEIGHT_0 = weights_[0];
        WEIGHT_1 = weights_[1];
        WEIGHT_2 = weights_[2];
        WEIGHT_3 = weights_[3];
        WEIGHT_4 = weights_[4];
        WEIGHT_5 = weights_[5];
    }

    /**
     * @notice Records that `burner` burned `amount` of $MNTD for `tokenId`.
     * @dev    Crediter only. `burner` must own the bear and its transfer count must still be
     *         `nonce`: both passing means the burner has held the bear continuously since the
     *         crediter read the count, so a burn never lands on a bear that changed hands in
     *         between. Reverts, in this order, with `NotCrediter`, `ContractPaused`,
     *         `ZeroAmount`, `NotBearOwner`, `StaleNonce` or `RefAlreadyUsed`. Any positive
     *         amount is accepted and accumulates; refusing amounts past level 5 is the
     *         crediter's job.
     * @param  tokenId The bear.
     * @param  burner  The wallet whose $MNTD was burned.
     * @param  amount  Base units burned.
     * @param  nonce   The bear's `transferNonce` when the crediter read it.
     * @param  ref     The crediter's reference for this burn, accepted once per crediter.
     */
    function credit(uint256 tokenId, address burner, uint128 amount, uint64 nonce, bytes32 ref) external {
        if (msg.sender != crediter) revert NotCrediter();
        _requireNotPaused();
        if (amount == 0) revert ZeroAmount();
        if (BEARS.ownerOf(tokenId) != burner) revert NotBearOwner();
        if (BEARS.transferNonce(tokenId) != nonce) revert StaleNonce();
        if (_refUsed[msg.sender][ref]) revert RefAlreadyUsed();

        Record storage record = _records[tokenId];
        uint128 cumulative = record.nonce == nonce ? record.cumulative : 0;
        uint8 previousLevel = _levelFor(cumulative);
        uint128 newCumulative = cumulative + amount;

        record.cumulative = newCumulative;
        record.nonce = nonce;
        lifetimeBurned[tokenId] += amount;
        _refUsed[msg.sender][ref] = true;

        emit BearActivated(tokenId, burner, previousLevel, _levelFor(newCumulative), amount, newCumulative, ref);
    }

    /**
     * @notice Nominates a bear to carry this wallet's Status multiplier. One per wallet; a new
     *         nomination replaces the previous one.
     * @dev    Owner of the bear only. The nomination is void once the bear moves, so a previous
     *         owner cannot keep the boost after selling.
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

    /// @notice The $MNTD credited to a bear under its current owner. Zero after a transfer.
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
     * @dev    The portal sizes each burn with this, and the adapter refuses any amount above
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

    /// @notice Sets the one address allowed to call `credit`. The zero address, which can send
    ///         no call, leaves no crediter at all: credits stop until one is set.
    function setCrediter(address crediter_) external onlyOwner {
        emit CrediterSet(crediter, crediter_);
        crediter = crediter_;
    }

    /// @notice Suspends or resumes `credit` and `linkBear`. Transfers are never affected.
    function setPaused(bool paused_) external onlyOwner {
        paused = paused_;
        emit PausedSet(paused_);
    }

    /**
     * @notice Gives up ownership permanently.
     * @dev    Refused while paused, so a pause can always be lifted.
     */
    function renounceOwnership() public payable override onlyOwner {
        if (paused) revert CannotRenounceWhilePaused();
        super.renounceOwnership();
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
