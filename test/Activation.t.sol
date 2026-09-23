// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {VmSafe} from "forge-std/Vm.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {BaseTest} from "./BaseTest.t.sol";
import {Activation} from "../src/Activation.sol";
import {IMintABear} from "../src/interfaces/IMintABear.sol";

/// @dev ACT-1. `Activation` holds no token and reads only the collection.
contract ActivationTokenAgnosticTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 2);
    }

    function test_activation_knowsNoToken_andReadsOnlyTheCollection() public {
        /* Scenario: ACT-1 — Activation knows no token
           When Activation's code and constructor are inspected
           Then it holds no $MNTD reference and moves no tokens
           And it reads only MintABear's ownerOf, transferNonce and exists */
        vm.startStateDiffRecording();
        Activation fresh = new Activation(address(bears), _thresholds(), _weights());
        fresh.setCrediter(crediter);
        vm.prank(crediter);
        fresh.credit(1, alice, 3_333 * UNIT, 0, bytes32(uint256(1)));
        vm.startPrank(alice);
        fresh.linkBear(1);
        fresh.unlinkBear();
        vm.stopPrank();
        uint256[] memory ids = new uint256[](3);
        (ids[0], ids[1], ids[2]) = (1, 2, 4445);
        fresh.snapshot(ids);
        fresh.weightOf(1);
        fresh.costToReach(1, 5);
        fresh.linkOf(alice);
        fresh.lifetimeBurned(1);
        VmSafe.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();

        uint256 reads;
        for (uint256 i; i < accesses.length; ++i) {
            VmSafe.AccountAccess memory a = accesses[i];
            if (a.accessor != address(fresh) || a.kind == VmSafe.AccountAccessKind.Resume) continue;
            assertEq(a.account, address(bears), "Activation calls nothing but the collection");
            assertTrue(a.kind == VmSafe.AccountAccessKind.StaticCall, "and only reads it");
            assertEq(a.value, 0, "and sends no value");
            bytes4 selector = bytes4(a.data);
            assertTrue(
                selector == IMintABear.ownerOf.selector || selector == IMintABear.transferNonce.selector
                    || selector == IMintABear.exists.selector,
                "through ownerOf, transferNonce and exists only"
            );
            ++reads;
        }
        assertGt(reads, 0);

        (bool hasToken,) = address(fresh).staticcall(abi.encodeWithSignature("MNTD()"));
        assertFalse(hasToken, "no token reference");
        (bool hasBurn,) = address(fresh).staticcall(abi.encodeWithSignature("burn(uint256,uint128)", 1, 1));
        assertFalse(hasBurn, "no burn entry point");
    }
}

/// @dev `credit`: who may call it, what it refuses, and what it records.
contract ActivationCreditTest is BaseTest {
    event BearActivated(
        uint256 indexed tokenId,
        address indexed burner,
        uint8 previousLevel,
        uint8 newLevel,
        uint256 amount,
        uint256 cumulative,
        bytes32 indexed ref
    );

    function setUp() public override {
        super.setUp();
        _mint(alice, 1);
    }

    function _creditAs(address caller, address burner, uint128 amount, uint64 nonce, bytes32 ref) internal {
        vm.prank(caller);
        activation.credit(1, burner, amount, nonce, ref);
    }

    function test_credit_recordsTheBurn_andEmitsBearActivated() public {
        /* Scenario:
           Given the crediter and a bear its burner owns at the current counter
           When 3,333 $MNTD is credited under a fresh ref
           Then cumulative and lifetimeBurned read 3,333, the level is 2 and BearActivated carries
             the burner, both levels, the amount, the cumulative and the ref */
        vm.expectEmit(true, true, true, true, address(activation));
        emit BearActivated(1, alice, 0, 2, 3_333 * UNIT, 3_333 * UNIT, bytes32(uint256(7)));
        _creditAs(crediter, alice, 3_333 * UNIT, 0, bytes32(uint256(7)));

        assertEq(activation.cumulativeOf(1), 3_333 * UNIT);
        assertEq(activation.lifetimeBurned(1), 3_333 * UNIT);
        assertEq(activation.levelOf(1), 2);
    }

    function test_credit_accumulatesAcrossCredits() public {
        /* Scenario:
           Given a bear credited 1,000 and then 666
           When its level is read
           Then the credits add up to 1,666 and the bear stands at level 1 */
        _credit(1, 1_000);
        assertEq(activation.levelOf(1), 0);
        _credit(1, 666);
        assertEq(activation.cumulativeOf(1), 1_666 * UNIT);
        assertEq(activation.levelOf(1), 1);
    }

    function test_credit_everyThresholdBoundary() public {
        /* Scenario:
           Given a bear one base unit short of each threshold
           When that last unit is credited
           Then the level rises by exactly one at each threshold */
        uint128[5] memory t = _thresholds();
        uint128 banked;
        for (uint8 k; k < 5; ++k) {
            _creditAs(crediter, alice, t[k] - 1 - banked, 0, keccak256(abi.encode("short", k)));
            assertEq(activation.levelOf(1), k, "one unit short");
            _creditAs(crediter, alice, 1, 0, keccak256(abi.encode("unit", k)));
            assertEq(activation.levelOf(1), k + 1, "at the threshold");
            banked = t[k];
        }
    }

    function test_credit_spanningSeveralThresholds_jumpsToTheHighestCleared() public {
        /* Scenario:
           Given an unactivated bear
           When one credit clears three thresholds
           Then the level is 3 and BearActivated reports 0 to 3 */
        vm.expectEmit(true, true, true, true, address(activation));
        emit BearActivated(1, alice, 0, 3, 9_000 * UNIT, 9_000 * UNIT, bytes32(uint256(1)));
        _credit(1, 9_000);
        assertEq(activation.levelOf(1), 3);
    }

    function test_credit_pastLevelFive_isRecorded() public {
        /* Scenario:
           Given a bear at level 5
           When the crediter credits more
           Then Activation records it: refusing amounts past level 5 is the adapter's job (ACT-8) */
        _credit(1, 41_666);
        _credit(1, 1);
        assertEq(activation.levelOf(1), 5);
        assertEq(activation.cumulativeOf(1), 41_667 * UNIT);
    }

    function test_credit_byAnyoneButTheCrediter_reverts() public {
        /* Scenario:
           Given a valid credit
           When the owner, the bear's holder or any other address sends it
           Then it reverts with NotCrediter */
        vm.expectRevert(Activation.NotCrediter.selector);
        _creditAs(address(this), alice, UNIT, 0, bytes32(uint256(1)));
        vm.expectRevert(Activation.NotCrediter.selector);
        _creditAs(alice, alice, UNIT, 0, bytes32(uint256(1)));
    }

    function test_credit_whenPaused_reverts() public {
        /* Scenario:
           Given the owner has paused
           When the crediter credits
           Then it reverts with ContractPaused */
        activation.setPaused(true);
        vm.expectRevert(Activation.ContractPaused.selector);
        _creditAs(crediter, alice, UNIT, 0, bytes32(uint256(1)));
    }

    function test_credit_zeroAmount_reverts() public {
        /* Scenario:
           Given a credit of zero
           When the crediter sends it
           Then it reverts with ZeroAmount */
        vm.expectRevert(Activation.ZeroAmount.selector);
        _creditAs(crediter, alice, 0, 0, bytes32(uint256(1)));
    }

    function test_credit_forABurnerWhoDoesNotOwnTheBear_reverts() public {
        /* Scenario:
           Given a bear owned by alice, and bob approved to move it
           When the crediter credits a burn by bob, or by an unrelated wallet
           Then it reverts with NotBearOwner: an operator cannot spend an owner's burn */
        vm.prank(alice);
        bears.setApprovalForAll(bob, true);
        vm.expectRevert(Activation.NotBearOwner.selector);
        _creditAs(crediter, bob, UNIT, 0, bytes32(uint256(1)));
        vm.expectRevert(Activation.NotBearOwner.selector);
        _creditAs(crediter, operator, UNIT, 0, bytes32(uint256(1)));
    }

    function test_credit_withAStaleNonce_reverts() public {
        /* Scenario:
           Given a bear that went away and came back to its burner after the counter was read
           When the crediter credits with the counter value it read
           Then it reverts with StaleNonce: the burner did not hold the bear throughout */
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        vm.prank(bob);
        bears.transferFrom(bob, alice, 1);
        vm.expectRevert(Activation.StaleNonce.selector);
        _creditAs(crediter, alice, UNIT, 0, bytes32(uint256(1)));
    }

    function test_credit_withAUsedRef_reverts() public {
        /* Scenario:
           Given a ref already credited
           When the crediter credits again under it
           Then it reverts with RefAlreadyUsed and nothing is recorded twice */
        _creditAs(crediter, alice, UNIT, 0, bytes32(uint256(9)));
        vm.expectRevert(Activation.RefAlreadyUsed.selector);
        _creditAs(crediter, alice, UNIT, 0, bytes32(uint256(9)));
        assertEq(activation.lifetimeBurned(1), UNIT);
    }

    function test_credit_checksRunInTheSpecifiedOrder() public {
        /* Scenario:
           Given a credit that fails several checks at once
           When it is sent
           Then the first failing check in the order NotCrediter, ContractPaused, ZeroAmount,
             NotBearOwner, StaleNonce, RefAlreadyUsed names the revert */
        _creditAs(crediter, alice, UNIT, 0, bytes32(uint256(1)));
        activation.setPaused(true);

        vm.expectRevert(Activation.NotCrediter.selector);
        _creditAs(bob, bob, 0, 5, bytes32(uint256(1)));
        vm.expectRevert(Activation.ContractPaused.selector);
        _creditAs(crediter, bob, 0, 5, bytes32(uint256(1)));

        activation.setPaused(false);
        vm.expectRevert(Activation.ZeroAmount.selector);
        _creditAs(crediter, bob, 0, 5, bytes32(uint256(1)));
        vm.expectRevert(Activation.NotBearOwner.selector);
        _creditAs(crediter, bob, UNIT, 5, bytes32(uint256(1)));
        vm.expectRevert(Activation.StaleNonce.selector);
        _creditAs(crediter, alice, UNIT, 5, bytes32(uint256(1)));
    }
}

/// @dev The reset: a transfer voids the record without any call into `Activation`.
contract ActivationResetTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 1);
    }

    function test_transfer_resetsCumulativeLevelAndWeight() public {
        /* Scenario:
           Given a bear at level 5
           When it is sold
           Then the buyer sees cumulative 0, level 0 and the level-0 weight */
        _credit(1, 41_666);
        assertEq(activation.levelOf(1), 5);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertEq(activation.cumulativeOf(1), 0);
        assertEq(activation.levelOf(1), 0);
        assertEq(activation.weightOf(1), 100);
    }

    function test_transfer_preservesLifetimeBurned() public {
        /* Scenario:
           Given a credited bear
           When it changes hands
           Then lifetimeBurned is unchanged */
        _credit(1, 1_666);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertEq(activation.lifetimeBurned(1), 1_666 * UNIT);
    }

    function test_credit_afterTransfer_startsFromZero() public {
        /* Scenario:
           Given a bear sold at level 1
           When the new owner's burn of the first threshold is credited
           Then they stand at level 1 with their own cumulative, and lifetime holds both */
        _credit(1, 1_666);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        _credit(1, 1_666);
        assertEq(activation.levelOf(1), 1);
        assertEq(activation.cumulativeOf(1), 1_666 * UNIT);
        assertEq(activation.lifetimeBurned(1), 3_332 * UNIT);
    }

    function test_transfer_thereAndBack_doesNotRestoreTheLevel() public {
        /* Scenario:
           Given a bear sold and bought back by its original owner
           When its level is read
           Then it is still zero, because the counter moved twice */
        _credit(1, 1_666);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        vm.prank(bob);
        bears.transferFrom(bob, alice, 1);
        assertEq(activation.levelOf(1), 0);
    }
}

/// @dev The Status link.
contract ActivationLinkTest is BaseTest {
    event BearLinked(address indexed wallet, uint256 indexed tokenId);
    event BearUnlinked(address indexed wallet, uint256 indexed tokenId);

    function setUp() public override {
        super.setUp();
        _mint(alice, 2);
    }

    function test_linkBear_recordsTheNomination() public {
        /* Scenario:
           Given a bear owner at level 1
           When they nominate it
           Then BearLinked is emitted and the link reports that bear and its level */
        _credit(1, 1_666);
        vm.expectEmit(true, true, true, true, address(activation));
        emit BearLinked(alice, 1);
        vm.prank(alice);
        activation.linkBear(1);
        (uint256 tokenId, uint8 level) = activation.linkOf(alice);
        assertEq(tokenId, 1);
        assertEq(level, 1);
    }

    function test_linkBear_byNonOwner_reverts() public {
        /* Scenario:
           Given a bear owned by alice
           When bob tries to nominate it
           Then it reverts with NotBearOwner */
        vm.prank(bob);
        vm.expectRevert(Activation.NotBearOwner.selector);
        activation.linkBear(1);
    }

    function test_linkBear_whenPaused_reverts() public {
        /* Scenario:
           Given the owner has paused
           When a holder nominates a bear
           Then it reverts with ContractPaused */
        activation.setPaused(true);
        vm.prank(alice);
        vm.expectRevert(Activation.ContractPaused.selector);
        activation.linkBear(1);
    }

    function test_linkBear_replacesThePreviousNomination() public {
        /* Scenario:
           Given a wallet that has nominated one bear
           When it nominates another
           Then only the newer nomination stands */
        vm.startPrank(alice);
        activation.linkBear(1);
        activation.linkBear(2);
        vm.stopPrank();
        (uint256 tokenId,) = activation.linkOf(alice);
        assertEq(tokenId, 2);
    }

    function test_transfer_voidsThePreviousOwnersLink() public {
        /* Scenario:
           Given alice has nominated her bear
           When she sells it
           Then her link reads (0, 0) */
        _credit(1, 1_666);
        vm.startPrank(alice);
        activation.linkBear(1);
        bears.transferFrom(alice, bob, 1);
        vm.stopPrank();
        (uint256 tokenId, uint8 level) = activation.linkOf(alice);
        assertEq(tokenId, 0);
        assertEq(level, 0);
    }

    function test_unlinkBear_clearsTheNomination() public {
        /* Scenario:
           Given a nominated bear
           When the owner unlinks
           Then BearUnlinked is emitted, the link reads empty and the bear has not moved */
        vm.startPrank(alice);
        activation.linkBear(1);
        vm.expectEmit(true, true, true, true, address(activation));
        emit BearUnlinked(alice, 1);
        activation.unlinkBear();
        vm.stopPrank();
        (uint256 tokenId,) = activation.linkOf(alice);
        assertEq(tokenId, 0);
        assertEq(bears.ownerOf(1), alice);
    }

    function test_unlinkBear_withNoNomination_isHarmlessAndSilent() public {
        /* Scenario:
           Given a wallet with no nomination
           When it unlinks anyway
           Then nothing reverts and no event is emitted */
        vm.recordLogs();
        vm.prank(bob);
        activation.unlinkBear();
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function test_unlinkBear_whilePaused_succeeds() public {
        /* Scenario:
           Given a nominated bear and a pause
           When the owner unlinks
           Then it succeeds: the pause closes links, not unlinks */
        vm.prank(alice);
        activation.linkBear(1);
        activation.setPaused(true);
        vm.prank(alice);
        activation.unlinkBear();
        (uint256 tokenId,) = activation.linkOf(alice);
        assertEq(tokenId, 0);
    }

    function test_linkOf_withNoNomination_readsEmpty() public view {
        /* Scenario:
           Given a wallet that never nominated a bear
           When its link is read
           Then it reads (0, 0) */
        (uint256 tokenId, uint8 level) = activation.linkOf(bob);
        assertEq(tokenId, 0);
        assertEq(level, 0);
    }
}

/// @dev Thresholds, weights, `costToReach` and `snapshot`.
contract ActivationViewsTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 2);
    }

    function test_thresholdFor_everyLevel() public view {
        /* Scenario:
           Given the specified thresholds in base units
           When each level's threshold is read
           Then level 0 costs nothing and levels 1-5 return the constructor's values, unscaled */
        uint128[5] memory t = _thresholds();
        assertEq(activation.thresholdFor(0), 0);
        for (uint8 k; k < 5; ++k) {
            assertEq(activation.thresholdFor(k + 1), t[k]);
        }
        assertEq(activation.THRESHOLD_1(), 1_666 * UNIT);
        assertEq(activation.THRESHOLD_5(), 41_666 * UNIT);
    }

    function test_weightFor_everyLevel() public view {
        /* Scenario:
           Given the specified weights
           When each level's weight is read
           Then levels 0-5 return 100, 110, 125, 145, 170, 200 */
        uint16[6] memory w = _weights();
        for (uint8 k; k < 6; ++k) {
            assertEq(activation.weightFor(k), w[k]);
        }
    }

    function test_weightOf_followsTheLevel() public {
        /* Scenario:
           Given an unactivated bear and a bear credited to level 3
           When their weights are read
           Then they are 100 and 145 */
        _credit(2, 8_333);
        assertEq(activation.weightOf(1), 100);
        assertEq(activation.weightOf(2), 145);
    }

    function test_levelReads_aboveMaxLevel_revertWithInvalidLevel() public {
        /* Scenario:
           Given a level that does not exist
           When its threshold, weight or cost is read
           Then each reverts with InvalidLevel */
        vm.expectRevert(Activation.InvalidLevel.selector);
        activation.thresholdFor(6);
        vm.expectRevert(Activation.InvalidLevel.selector);
        activation.weightFor(6);
        vm.expectRevert(Activation.InvalidLevel.selector);
        activation.costToReach(1, 6);
    }

    function test_costToReach_returnsTheRemainderOrZero() public {
        /* Scenario:
           Given a bear credited 1,000
           When the cost to level 1, level 5 and level 0 is read
           Then it returns 666, 40,666 and 0 */
        _credit(1, 1_000);
        assertEq(activation.costToReach(1, 1), 666 * UNIT);
        assertEq(activation.costToReach(1, 5), 40_666 * UNIT);
        assertEq(activation.costToReach(1, 0), 0);
    }

    function test_snapshot_answersForAnyIds() public {
        /* Scenario:
           Given bear 1 unactivated, bear 2 at level 2 and no bear 4445
           When snapshot([1, 2, 4445]) is read
           Then it returns owner, level and weight for 1 and 2 and zeroes for 4445 */
        _credit(2, 3_333);
        uint256[] memory ids = new uint256[](3);
        (ids[0], ids[1], ids[2]) = (1, 2, 4445);
        Activation.BearState[] memory rows = activation.snapshot(ids);
        assertEq(rows.length, 3);
        assertEq(rows[0].owner, alice);
        assertEq(rows[0].level, 0);
        assertEq(rows[0].weight, 100);
        assertEq(rows[1].owner, alice);
        assertEq(rows[1].level, 2);
        assertEq(rows[1].weight, 125);
        assertEq(rows[2].owner, address(0));
        assertEq(rows[2].level, 0);
        assertEq(rows[2].weight, 0);
    }
}

/// @dev Constructor guards: thresholds and weights are immutable, so each input is checked.
contract ActivationConstructionTest is BaseTest {
    function test_constructor_rejectsZeroBears() public {
        /* Scenario:
           Given a deployment without the collection address
           When Activation is constructed
           Then it reverts with ZeroAddress */
        vm.expectRevert(Activation.ZeroAddress.selector);
        new Activation(address(0), _thresholds(), _weights());
    }

    function test_constructor_rejectsBadThresholds() public {
        /* Scenario:
           Given a zero first threshold, or thresholds not strictly ascending
           When Activation is constructed
           Then it reverts with ThresholdsNotAscending */
        uint128[5] memory t = _thresholds();
        t[0] = 0;
        vm.expectRevert(Activation.ThresholdsNotAscending.selector);
        new Activation(address(bears), t, _weights());

        t = _thresholds();
        t[3] = t[2];
        vm.expectRevert(Activation.ThresholdsNotAscending.selector);
        new Activation(address(bears), t, _weights());
    }

    function test_constructor_rejectsWeightsNotAscending() public {
        /* Scenario:
           Given weights where a level weighs no more than the one below
           When Activation is constructed
           Then it reverts with WeightsNotAscending */
        uint16[6] memory w = _weights();
        w[4] = w[3];
        vm.expectRevert(Activation.WeightsNotAscending.selector);
        new Activation(address(bears), _thresholds(), w);
    }

    function test_constructor_setsTheCollection_andNoCrediter() public view {
        /* Scenario:
           Given a fresh Activation
           When BEARS, crediter, paused and owner are read
           Then BEARS is the collection; the deployer owns it; no credit is possible until
             setCrediter is called (the fixture calls it) */
        assertEq(address(activation.BEARS()), address(bears));
        assertEq(activation.owner(), address(this));
        assertFalse(activation.paused());
    }
}

/// @dev The owner's powers: `setCrediter`, `setPaused`, ownership, and the renounce guard.
contract ActivationOwnershipTest is BaseTest {
    event CrediterSet(address indexed previous, address indexed current);
    event PausedSet(bool paused);

    function setUp() public override {
        super.setUp();
        _mint(alice, 1);
    }

    function test_setCrediter_byOwner_movesTheRole() public {
        /* Scenario:
           Given a crediter
           When the owner sets another
           Then CrediterSet carries both, the new one credits and the old one cannot */
        address next = makeAddr("nextCrediter");
        vm.expectEmit(true, true, true, true, address(activation));
        emit CrediterSet(crediter, next);
        activation.setCrediter(next);
        assertEq(activation.crediter(), next);

        vm.prank(crediter);
        vm.expectRevert(Activation.NotCrediter.selector);
        activation.credit(1, alice, UNIT, 0, bytes32(uint256(1)));

        vm.prank(next);
        activation.credit(1, alice, UNIT, 0, bytes32(uint256(1)));
        assertEq(activation.lifetimeBurned(1), UNIT);
    }

    function test_setCrediterAndSetPaused_byNonOwner_revert() public {
        /* Scenario:
           Given a wallet that does not own Activation
           When it calls setCrediter or setPaused
           Then both revert with Unauthorized */
        vm.startPrank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        activation.setCrediter(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        activation.setPaused(true);
        vm.stopPrank();
    }

    function test_setPaused_togglesAndEmits() public {
        /* Scenario:
           Given a running Activation
           When the owner pauses and unpauses
           Then PausedSet is emitted each time and credits work again afterwards */
        vm.expectEmit(true, true, true, true, address(activation));
        emit PausedSet(true);
        activation.setPaused(true);
        vm.expectEmit(true, true, true, true, address(activation));
        emit PausedSet(false);
        activation.setPaused(false);
        _credit(1, 1_666);
        assertEq(activation.levelOf(1), 1);
    }

    function test_renounce_whilePaused_reverts() public {
        /* Scenario:
           Given Activation is paused
           When the owner renounces
           Then it reverts with CannotRenounceWhilePaused, so a pause can always be lifted */
        activation.setPaused(true);
        vm.expectRevert(Activation.CannotRenounceWhilePaused.selector);
        activation.renounceOwnership();
    }

    function test_renounce_whileUnpaused_succeeds() public {
        /* Scenario:
           Given Activation running
           When the owner renounces
           Then it succeeds and the crediter still credits */
        activation.renounceOwnership();
        assertEq(activation.owner(), address(0));
        _credit(1, 1_666);
        assertEq(activation.levelOf(1), 1);
    }

    function test_renounce_byNonOwner_reverts() public {
        /* Scenario:
           Given a wallet that does not own Activation
           When it renounces
           Then it reverts with Unauthorized */
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        activation.renounceOwnership();
    }
}
