// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "solady/auth/Ownable.sol";
import {IMintABear} from "./interfaces/IMintABear.sol";

/// @dev The subset of $MNTD this contract relies on.
interface IMNTD {
    function burnFrom(address account, uint256 amount) external;
    function decimals() external view returns (uint8);
}

/**
 * @title  Activation
 * @notice Burning $MNTD raises a bear's activation level; selling the bear resets it.
 * @dev    Levels are derived from a running total rather than purchased a step at a time, so
 *         a holder may burn any amount and it accumulates. Reaching level 5 in one
 *         transaction and reaching it across twenty are the same thing.
 *
 *         This contract reads the token; the token never calls it. The reset works by the
 *         token advancing a per-bear counter on transfer, while this contract stores the
 *         counter value a level was set at. A stale counter means the level reads zero.
 *         Nothing executes at reset time, so there is no path by which a reset is skipped
 *         and none by which a defect here blocks a transfer. The cost of that is one
 *         requirement from the specification that cannot be met: there is no reset event,
 *         because no code runs. Indexers derive it from the token's Transfer event.
 *
 *         Thresholds are constructor arguments with no setter. Once deployed, the price of
 *         every level is fixed for good.
 */
contract Activation is Ownable {
    /// @notice Level reached at each cumulative burn, in $MNTD base units.
    uint128 public immutable THRESHOLD_1;
    uint128 public immutable THRESHOLD_2;
    uint128 public immutable THRESHOLD_3;
    uint128 public immutable THRESHOLD_4;
    uint128 public immutable THRESHOLD_5;

    /// @notice The collection this contract tracks.
    IMintABear public immutable BEARS;

    /// @notice The token burned to activate.
    IMNTD public immutable MNTD;

    /// @dev Level and the transfer count it was recorded at. Packs into one slot.
    struct Record {
        uint128 cumulative;
        uint64 nonce;
    }

    mapping(uint256 => Record) private _records;

    /// @notice Total ever burned into a bear, across all owners. Never reset.
    mapping(uint256 => uint256) public lifetimeBurned;

    /// @dev Wallet's nominated bear, and the transfer count it was nominated at.
    mapping(address => uint256) private _linkedBear;
    mapping(address => uint64) private _linkedAtNonce;

    /// @notice When true, burning and linking are suspended. Never affects transfers.
    bool public paused;

    event BearActivated(
        uint256 indexed tokenId,
        address indexed owner,
        uint8 previousLevel,
        uint8 newLevel,
        uint256 amountBurned,
        uint256 cumulative
    );
    event BearLinked(address indexed wallet, uint256 indexed tokenId);
    event BearUnlinked(address indexed wallet, uint256 indexed tokenId);
    event PausedSet(bool paused);

    error ZeroAmount();
    error NotBearOwner();
    error AlreadyAtMaxLevel();
    error ContractPaused();
    error ThresholdsNotAscending();

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    function _requireNotPaused() internal view {
        if (paused) revert ContractPaused();
    }

    /**
     * @param bears_      The MintABear collection.
     * @param mntd_       The $MNTD token. Must already be deployed: its decimals are read here.
     * @param thresholds_ The five cumulative thresholds in whole tokens, ascending
     *                    (5_000 / 15_000 / 40_000 / 100_000 / 250_000). Scaled by the
     *                    token's decimals at construction and fixed thereafter.
     */
    constructor(address bears_, address mntd_, uint128[5] memory thresholds_) {
        _initializeOwner(msg.sender);
        BEARS = IMintABear(bears_);
        MNTD = IMNTD(mntd_);

        uint128 unit = uint128(10 ** IMNTD(mntd_).decimals());
        for (uint256 i = 1; i < 5; ++i) {
            if (thresholds_[i] <= thresholds_[i - 1]) revert ThresholdsNotAscending();
        }
        if (thresholds_[0] == 0) revert ThresholdsNotAscending();

        THRESHOLD_1 = thresholds_[0] * unit;
        THRESHOLD_2 = thresholds_[1] * unit;
        THRESHOLD_3 = thresholds_[2] * unit;
        THRESHOLD_4 = thresholds_[3] * unit;
        THRESHOLD_5 = thresholds_[4] * unit;
    }

    /**
     * @notice Burns $MNTD into a bear, raising its level if a threshold is crossed.
     * @dev    Only the current owner may call this. An operator approved to transfer the
     *         bear is deliberately not permitted to spend the owner's $MNTD.
     * @param  tokenId The bear to activate.
     * @param  amount  Base units of $MNTD to burn. Any amount is accepted and accumulates.
     */
    function burn(uint256 tokenId, uint128 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (BEARS.ownerOf(tokenId) != msg.sender) revert NotBearOwner();

        uint64 nonce = BEARS.transferNonce(tokenId);
        Record storage record = _records[tokenId];
        uint128 cumulative = record.nonce == nonce ? record.cumulative : 0;

        if (cumulative >= THRESHOLD_5) revert AlreadyAtMaxLevel();

        uint8 previousLevel = _levelFor(cumulative);
        uint128 newCumulative = cumulative + amount;
        uint8 newLevel = _levelFor(newCumulative);

        record.cumulative = newCumulative;
        record.nonce = nonce;
        lifetimeBurned[tokenId] += amount;

        MNTD.burnFrom(msg.sender, amount);

        emit BearActivated(tokenId, msg.sender, previousLevel, newLevel, amount, newCumulative);
    }

    /**
     * @notice Nominates a bear to carry this wallet's Status multiplier. One per wallet.
     * @dev    The nomination is voided automatically when the bear is transferred, so a
     *         previous owner cannot keep the boost after selling.
     */
    function linkBear(uint256 tokenId) external whenNotPaused {
        if (BEARS.ownerOf(tokenId) != msg.sender) revert NotBearOwner();
        _linkedBear[msg.sender] = tokenId;
        _linkedAtNonce[msg.sender] = BEARS.transferNonce(tokenId);
        emit BearLinked(msg.sender, tokenId);
    }

    /// @notice Removes this wallet's nomination without transferring the bear.
    function unlinkBear() external {
        uint256 tokenId = _linkedBear[msg.sender];
        delete _linkedBear[msg.sender];
        delete _linkedAtNonce[msg.sender];
        emit BearUnlinked(msg.sender, tokenId);
    }

    /// @notice The $MNTD burned into a bear by its current owner. Zero after a transfer.
    function cumulativeOf(uint256 tokenId) public view returns (uint128) {
        Record memory record = _records[tokenId];
        return record.nonce == BEARS.transferNonce(tokenId) ? record.cumulative : 0;
    }

    /// @notice A bear's current activation level, 0 to 5. Zero after a transfer.
    function levelOf(uint256 tokenId) public view returns (uint8) {
        return _levelFor(cumulativeOf(tokenId));
    }

    /**
     * @notice The bear currently carrying a wallet's Status multiplier.
     * @return tokenId The nominated bear, or zero if there is none or it has been sold.
     * @return level   That bear's activation level, or zero.
     */
    function linkOf(address wallet) external view returns (uint256 tokenId, uint8 level) {
        tokenId = _linkedBear[wallet];
        if (tokenId == 0) return (0, 0);
        if (_linkedAtNonce[wallet] != BEARS.transferNonce(tokenId)) return (0, 0);
        return (tokenId, _levelFor(cumulativeOf(tokenId)));
    }

    /**
     * @notice How much more $MNTD a bear needs to reach a level.
     * @dev    Provided so the portal can offer an exact amount rather than letting a holder
     *         overshoot into a tier they have already cleared.
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
        revert AlreadyAtMaxLevel();
    }

    /// @notice Suspends burning and linking. Transfers and bear wallets are never affected.
    function setPaused(bool paused_) external onlyOwner {
        paused = paused_;
        emit PausedSet(paused_);
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
