// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "solady/auth/Ownable.sol";
import {Activation} from "../../src/Activation.sol";
import {BaseTest} from "../BaseTest.t.sol";

/**
 * @title  WrongAdminRotation
 * @notice Kept from the external security review of 2026-10-06 (MNT-147, L-01), where this case
 *         passed as a defect. It is retained inverted: it asserts the refusal that now stops it.
 *
 * @dev    The finding. `Activation` used Solady's single-step `transferOwnership`, and the deploy
 *         called it right after `setPaused(true)`. Ownership sent while paused to an address
 *         nobody controls (a typo, another network's Safe) could never lift the pause, since
 *         `setPaused` is owner-only and `renounceOwnership` reverts; after switch-on the only
 *         remedy was a new `Activation`, losing every level holders paid for.
 *
 *         The fix (ACT-12, ACT-15, OPS-2). The owner and the pause are set in the constructor, and
 *         `transferOwnership` reverts with `TwoStepHandoverOnly`: ownership moves only to an
 *         address that has called `requestOwnershipHandover`.
 */
contract WrongAdminRotation is BaseTest {
    function test_regression_rotationToAnUnrequestedAddress_isRefused_andThePauseCanStillBeLifted() public {
        /* Scenario:
           Given Activation paused, with a level recorded for a bear
           When the owner sends ownership to an address that never asked for it, by either route
           Then both revert, the owner is unchanged, the owner can unpause and the level stands */
        _mint(alice, 1);
        _burnFor(1, 3_333);
        activation.setPaused(true);
        address wrong = makeAddr("wrong");

        vm.expectRevert(Activation.TwoStepHandoverOnly.selector);
        activation.transferOwnership(wrong);
        vm.expectRevert(Ownable.NoHandoverRequest.selector);
        activation.completeOwnershipHandover(wrong);

        assertEq(activation.owner(), address(this));
        activation.setPaused(false);
        assertFalse(activation.paused());
        assertEq(activation.levelOf(1), 2);
    }
}
