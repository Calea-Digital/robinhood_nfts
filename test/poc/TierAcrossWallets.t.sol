// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {WhitelistClaimBase} from "../WhitelistClaim.t.sol";
import {WhitelistClaim} from "../../src/WhitelistClaim.sol";

/**
 * @title  TierAcrossWalletsRegression
 * @notice Kept from the tranche-1 review of 2026-09-24 (MNT-22, M-1), where this case passed as
 *         an exploit. It is retained inverted: it asserts the refusal that now stops it.
 *
 * @dev    The finding. WL-1 grants allocations by the account's wagering: $50 unlocks
 *         allocation 1, $100 allocation 2. The voucher's `allocationIndex` was checked against the
 *         wallet's claims, so a voucher for allocation 1 was valid for every wallet the holder
 *         selected. A signer that keeps no state issues one per selected wallet, and an account at
 *         $50 held two of the 1,000 spots over two wallets — the account cap of two could not tell
 *         whether the second was earned.
 *
 *         The fix. `allocationIndex` is the account's allocation number and must equal
 *         `accountClaims(account) + 1` (WL-3), so the account's allocation 1 is spent by its first
 *         claim whichever wallet makes it.
 */
contract TierAcrossWalletsRegression is WhitelistClaimBase {
    function test_regression_fiftyDollarAccountCannotTakeTwoSpots() public {
        /* Scenario:
           Given an account at $50, for which the signer issued an allocation-1 voucher for each of
             two wallets
           When both wallets claim
           Then the first succeeds and the second reverts with WrongAllocation, so the account
             holds one spot */
        WhitelistClaim.Claim memory forAlice = _voucher(alice, 1, ACCOUNT_A);
        WhitelistClaim.Claim memory forBob = _voucher(bob, 1, ACCOUNT_A);
        bytes memory sigAlice = _sign(signerKey, forAlice);
        bytes memory sigBob = _sign(signerKey, forBob);

        vm.prank(alice);
        wl.claim(forAlice, sigAlice);

        vm.prank(bob);
        vm.expectRevert(WhitelistClaim.WrongAllocation.selector);
        wl.claim(forBob, sigBob);

        assertEq(wl.accountClaims(ACCOUNT_A), 1, "one spot for the $50 tier");
        assertEq(wl.claimsOf(bob), 0);
        assertEq(wl.spotsLeft(), 999);
    }
}
