// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest} from "./BaseTest.t.sol";
import {Activation} from "../src/Activation.sol";

contract ActivationTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 1);
        _fund(alice, 500_000);
        _fund(bob, 500_000);
    }

    // ---------------------------------------------------------------- levels

    function test_burn_belowFirstThreshold_staysLevelZero() public {
        /* Scenario:
           Given an unactivated bear
           When its owner burns less than the first threshold
           Then the amount is banked but the level is still 0 */
        vm.prank(alice);
        activation.burn(1, 3_000 * UNIT);

        assertEq(activation.levelOf(1), 0);
        assertEq(activation.cumulativeOf(1), 3_000 * UNIT);
    }

    function test_burn_exactThreshold_reachesThatLevel() public {
        /* Scenario:
           Given an unactivated bear
           When its owner burns exactly the first threshold
           Then it reaches level 1 */
        vm.prank(alice);
        activation.burn(1, 5_000 * UNIT);
        assertEq(activation.levelOf(1), 1);
    }

    function test_burn_accumulatesAcrossCalls() public {
        /* Scenario:
           Given a bear part-way to a level
           When its owner burns again
           Then the amounts add up and the level follows the running total */
        vm.startPrank(alice);
        activation.burn(1, 3_000 * UNIT);
        assertEq(activation.levelOf(1), 0);
        activation.burn(1, 2_000 * UNIT);
        vm.stopPrank();

        assertEq(activation.levelOf(1), 1);
        assertEq(activation.cumulativeOf(1), 5_000 * UNIT);
    }

    function test_burn_spanningSeveralThresholds_jumpsToHighestCleared() public {
        /* Scenario:
           Given an unactivated bear
           When its owner burns the full level 5 amount in one call
           Then it reaches level 5 directly */
        vm.prank(alice);
        activation.burn(1, 250_000 * UNIT);
        assertEq(activation.levelOf(1), 5);
    }

    function test_burn_everyThresholdBoundary() public {
        /* Scenario:
           Given the configured thresholds
           When the cumulative total sits one unit below, exactly on, and one unit above each
           Then the level reported is the highest threshold actually cleared */
        uint128[5] memory t = [
            uint128(5_000) * UNIT,
            uint128(15_000) * UNIT,
            uint128(40_000) * UNIT,
            uint128(100_000) * UNIT,
            uint128(250_000) * UNIT
        ];

        for (uint8 i = 0; i < 5; ++i) {
            uint256 tokenId = i + 2;
            _mint(alice, 1);
            vm.prank(alice);
            activation.burn(tokenId, t[i] - 1);
            assertEq(activation.levelOf(tokenId), i, "one below should not clear");

            vm.prank(alice);
            activation.burn(tokenId, 1);
            assertEq(activation.levelOf(tokenId), i + 1, "exactly on should clear");
        }
    }

    function test_burn_atMaxLevel_reverts() public {
        /* Scenario:
           Given a bear already at level 5
           When its owner tries to burn more
           Then the call is refused rather than destroying tokens for no benefit */
        vm.startPrank(alice);
        activation.burn(1, 250_000 * UNIT);
        vm.expectRevert(Activation.AlreadyAtMaxLevel.selector);
        activation.burn(1, 1);
        vm.stopPrank();
    }

    function test_burn_reducesTokenSupply() public {
        /* Scenario:
           Given a funded owner
           When they activate
           Then the burned amount leaves total supply permanently */
        uint256 before = mntd.totalSupply();
        vm.prank(alice);
        activation.burn(1, 5_000 * UNIT);
        assertEq(mntd.totalSupply(), before - 5_000 * UNIT);
    }

    // ---------------------------------------------------------------- access

    function test_burn_byUnrelatedCaller_reverts() public {
        /* Scenario:
           Given a bear owned by alice
           When bob tries to activate it
           Then the call is refused */
        vm.prank(bob);
        vm.expectRevert(Activation.NotBearOwner.selector);
        activation.burn(1, 5_000 * UNIT);
    }

    function test_burn_byApprovedOperator_reverts() public {
        /* Scenario:
           Given an operator approved to transfer alice's bear
           When that operator tries to activate it
           Then the call is refused, because transfer approval must not let a marketplace
                spend the owner's MNTD */
        vm.prank(alice);
        bears.setApprovalForAll(operator, true);
        _fund(operator, 100_000);

        vm.prank(operator);
        vm.expectRevert(Activation.NotBearOwner.selector);
        activation.burn(1, 5_000 * UNIT);
    }

    function test_burn_zeroAmount_reverts() public {
        /* Scenario:
           Given a bear owner
           When they burn nothing
           Then the call is refused */
        vm.prank(alice);
        vm.expectRevert(Activation.ZeroAmount.selector);
        activation.burn(1, 0);
    }

    function test_burn_whenPaused_reverts() public {
        /* Scenario:
           Given activation is paused
           When an owner tries to burn
           Then the call is refused */
        activation.setPaused(true);
        vm.prank(alice);
        vm.expectRevert(Activation.ContractPaused.selector);
        activation.burn(1, 5_000 * UNIT);
    }

    // ---------------------------------------------------------------- reset

    function test_transfer_resetsLevelAndCumulative() public {
        /* Scenario:
           Given a bear at level 5
           When it is sold
           Then the buyer sees level 0 and nothing banked */
        vm.prank(alice);
        activation.burn(1, 250_000 * UNIT);
        assertEq(activation.levelOf(1), 5);

        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);

        assertEq(activation.levelOf(1), 0);
        assertEq(activation.cumulativeOf(1), 0);
    }

    function test_transfer_preservesLifetimeBurned() public {
        /* Scenario:
           Given a bear that has been activated
           When it changes hands
           Then the lifetime total is untouched, because it is a permanent record */
        vm.prank(alice);
        activation.burn(1, 5_000 * UNIT);

        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);

        assertEq(activation.lifetimeBurned(1), 5_000 * UNIT);
    }

    function test_burn_afterTransfer_startsFromZero() public {
        /* Scenario:
           Given a bear sold at level 1
           When the new owner burns the first threshold again
           Then they reach level 1, having paid in full themselves */
        vm.prank(alice);
        activation.burn(1, 5_000 * UNIT);

        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);

        vm.prank(bob);
        activation.burn(1, 5_000 * UNIT);

        assertEq(activation.levelOf(1), 1);
        assertEq(activation.cumulativeOf(1), 5_000 * UNIT);
        assertEq(activation.lifetimeBurned(1), 10_000 * UNIT);
    }

    function test_transfer_thereAndBack_doesNotRestoreLevel() public {
        /* Scenario:
           Given a bear that is sold and later reacquired by its original owner
           When the level is read
           Then it is still zero, because the counter moved twice */
        vm.prank(alice);
        activation.burn(1, 5_000 * UNIT);

        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        vm.prank(bob);
        bears.transferFrom(bob, alice, 1);

        assertEq(activation.levelOf(1), 0);
    }

    // ---------------------------------------------------------------- linking

    function test_linkBear_recordsNomination() public {
        /* Scenario:
           Given a bear owner
           When they nominate it
           Then the link reports that bear and its level */
        vm.startPrank(alice);
        activation.burn(1, 5_000 * UNIT);
        activation.linkBear(1);
        vm.stopPrank();

        (uint256 tokenId, uint8 level) = activation.linkOf(alice);
        assertEq(tokenId, 1);
        assertEq(level, 1);
    }

    function test_linkBear_byNonOwner_reverts() public {
        /* Scenario:
           Given a bear owned by alice
           When bob tries to nominate it
           Then the call is refused */
        vm.prank(bob);
        vm.expectRevert(Activation.NotBearOwner.selector);
        activation.linkBear(1);
    }

    function test_transfer_voidsPreviousOwnersLink() public {
        /* Scenario:
           Given alice has nominated her bear
           When she sells it
           Then her link reads empty, so she cannot keep the boost on a bear she sold */
        vm.startPrank(alice);
        activation.burn(1, 5_000 * UNIT);
        activation.linkBear(1);
        vm.stopPrank();

        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);

        (uint256 tokenId, uint8 level) = activation.linkOf(alice);
        assertEq(tokenId, 0);
        assertEq(level, 0);
    }

    function test_unlinkBear_clearsNomination() public {
        /* Scenario:
           Given a nominated bear
           When the owner unlinks
           Then the link reads empty and the bear has not moved */
        vm.startPrank(alice);
        activation.linkBear(1);
        activation.unlinkBear();
        vm.stopPrank();

        (uint256 tokenId,) = activation.linkOf(alice);
        assertEq(tokenId, 0);
        assertEq(bears.ownerOf(1), alice);
    }

    function test_linkBear_replacesPreviousNomination() public {
        /* Scenario:
           Given a wallet that has nominated one bear
           When it nominates another
           Then only the newer nomination stands, one per wallet */
        _mint(alice, 1);
        vm.startPrank(alice);
        activation.linkBear(1);
        activation.linkBear(2);
        vm.stopPrank();

        (uint256 tokenId,) = activation.linkOf(alice);
        assertEq(tokenId, 2);
    }

    // ---------------------------------------------------------------- views

    function test_costToReach_returnsRemainder() public {
        /* Scenario:
           Given a bear part-way to level 1
           When the cost to reach level 1 is queried
           Then it returns exactly what is still missing */
        vm.prank(alice);
        activation.burn(1, 2_000 * UNIT);
        assertEq(activation.costToReach(1, 1), 3_000 * UNIT);
    }

    function test_costToReach_alreadyReached_returnsZero() public {
        /* Scenario:
           Given a bear already past a level
           When the cost to reach it is queried
           Then it returns zero */
        vm.prank(alice);
        activation.burn(1, 5_000 * UNIT);
        assertEq(activation.costToReach(1, 1), 0);
    }

    function test_thresholds_areScaledByDecimals() public {
        /* Scenario:
           Given thresholds supplied in whole tokens
           When they are read back
           Then they are scaled by the token's decimals */
        assertEq(activation.THRESHOLD_1(), 5_000 * UNIT);
        assertEq(activation.THRESHOLD_5(), 250_000 * UNIT);
        assertEq(activation.thresholdFor(0), 0);
    }

    function test_constructor_rejectsNonAscendingThresholds() public {
        /* Scenario:
           Given thresholds that do not ascend
           When the contract is deployed
           Then construction fails rather than shipping an unusable tier table */
        uint128[5] memory bad = [uint128(5_000), uint128(5_000), uint128(40_000), uint128(100_000), uint128(250_000)];
        vm.expectRevert(Activation.ThresholdsNotAscending.selector);
        new Activation(address(bears), address(mntd), bad);
    }
}

contract ActivationBranchTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 1);
        _fund(alice, 500_000);
    }

    function test_thresholdFor_everyLevel() public {
        /* Scenario:
           Given the configured tier table
           When each level's threshold is queried
           Then every level returns its configured amount */
        assertEq(activation.thresholdFor(1), 5_000 * UNIT);
        assertEq(activation.thresholdFor(2), 15_000 * UNIT);
        assertEq(activation.thresholdFor(3), 40_000 * UNIT);
        assertEq(activation.thresholdFor(4), 100_000 * UNIT);
        assertEq(activation.thresholdFor(5), 250_000 * UNIT);
    }

    function test_thresholdFor_aboveMaxLevel_reverts() public {
        /* Scenario:
           Given a level that does not exist
           When its threshold is queried
           Then the call reverts rather than returning a misleading zero */
        vm.expectRevert(Activation.AlreadyAtMaxLevel.selector);
        activation.thresholdFor(6);
    }

    function test_linkOf_withNoNomination_readsEmpty() public {
        /* Scenario:
           Given a wallet that has never nominated a bear
           When its link is read
           Then it reports nothing */
        (uint256 tokenId, uint8 level) = activation.linkOf(bob);
        assertEq(tokenId, 0);
        assertEq(level, 0);
    }

    function test_linkBear_whenPaused_reverts() public {
        /* Scenario:
           Given linking is paused
           When an owner tries to nominate a bear
           Then the call is refused */
        activation.setPaused(true);
        vm.prank(alice);
        vm.expectRevert(Activation.ContractPaused.selector);
        activation.linkBear(1);
    }

    function test_setPaused_byNonOwner_reverts() public {
        /* Scenario:
           Given a wallet that does not own the contract
           When it tries to pause
           Then the call is refused */
        vm.prank(alice);
        vm.expectRevert();
        activation.setPaused(true);
    }

    function test_setPaused_togglesBackOn() public {
        /* Scenario:
           Given a paused contract
           When the owner unpauses
           Then burning works again */
        activation.setPaused(true);
        activation.setPaused(false);
        vm.prank(alice);
        activation.burn(1, 5_000 * UNIT);
        assertEq(activation.levelOf(1), 1);
    }

    function test_constructor_rejectsZeroFirstThreshold() public {
        /* Scenario:
           Given a first threshold of zero
           When the contract is deployed
           Then construction fails, because level 1 would be free */
        uint128[5] memory bad = [uint128(0), uint128(15_000), uint128(40_000), uint128(100_000), uint128(250_000)];
        vm.expectRevert(Activation.ThresholdsNotAscending.selector);
        new Activation(address(bears), address(mntd), bad);
    }

    function test_unlinkBear_withNoNomination_isHarmless() public {
        /* Scenario:
           Given a wallet with no nomination
           When it unlinks anyway
           Then nothing happens and nothing reverts */
        vm.prank(bob);
        activation.unlinkBear();
        (uint256 tokenId,) = activation.linkOf(bob);
        assertEq(tokenId, 0);
    }
}
