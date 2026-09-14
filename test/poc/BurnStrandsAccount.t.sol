// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest} from "../BaseTest.t.sol";
import {BearAccount} from "../../src/BearAccount.sol";
import {MintABear} from "../../src/MintABear.sol";

/**
 * @title  BurnStrandsAccountRegression
 * @notice Kept from the pre-audit review of 2026-09-14, where these three cases passed as
 *         exploits. They are retained inverted: each asserts the refusal that now stops it.
 *
 * @dev    The finding. `ERC721SeaDrop` declares `function burn(uint256) external` at
 *         `lib/seadrop/src/ERC721SeaDrop.sol:154`, neither `virtual` nor internal, so
 *         `MintABear` cannot override it. It reaches `_burn(tokenId, true)`, whose
 *         `approvalCheck` admits approved operators as well as the owner.
 *
 *         The damage. A bear's account resolves its controller by calling `ownerOf` on the
 *         collection. Solady's `ERC6551.owner()` returns `address(0)` when that call fails
 *         rather than bubbling the revert, so after a burn the account has no owner, for
 *         good. Anything it held — ETH, $MNTD, NFTs — is unreachable by anyone. That
 *         contradicts `docs/HANDOVER.md`, which records "no burn function on the token" as
 *         a settled decision.
 *
 *         The fix. Every burn routes through `_beforeTokenTransfers` with `to` set to the
 *         zero address, and no other path sets `to` to zero, so the hook refuses it.
 */
contract BurnStrandsAccountRegression is BaseTest {
    function test_regression_burnCannotStrandAccountAssets() public {
        /* Scenario:
           Given a bear whose account holds ETH and $MNTD
           When its owner calls the inherited SeaDrop burn
           Then the burn is refused and the assets stay reachable */
        _mint(alice, 1);

        address payable account = payable(bears.deployAccount(1));
        vm.deal(account, 5 ether);
        mntd.mint(account, 1_000 * UNIT);

        assertEq(BearAccount(account).owner(), alice, "owner before");

        vm.prank(alice);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.burn(1);

        // Previously: owner() read address(0) here and the assets were lost for good.
        assertEq(BearAccount(account).owner(), alice, "owner after");

        vm.prank(alice);
        BearAccount(account).execute(bob, 1 ether, "", 0);
        assertEq(bob.balance, 1 ether, "assets still movable");
        assertEq(mntd.balanceOf(account), 1_000 * UNIT, "MNTD untouched");
    }

    function test_regression_approvedOperatorCannotBurn() public {
        /* Scenario:
           Given alice approved an operator for her bear
           When the operator calls burn
           Then it is refused, so an approval cannot destroy a holder's bear */
        _mint(alice, 1);
        address payable account = payable(bears.deployAccount(1));
        vm.deal(account, 5 ether);

        vm.prank(alice);
        bears.setApprovalForAll(operator, true);

        vm.prank(operator);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.burn(1);

        assertEq(BearAccount(account).owner(), alice, "operator could not strand the assets");
    }

    function test_regression_supplyCannotBeReduced() public {
        /* Scenario:
           Given one bear minted
           When a burn is attempted
           Then supply holds, so ids are never orphaned and the cap keeps its meaning */
        _mint(alice, 1);
        assertEq(bears.totalSupply(), 1);

        vm.prank(alice);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.burn(1);

        assertEq(bears.totalSupply(), 1, "supply held");
        assertEq(bears.ownerOf(1), alice, "still alice's");
    }
}
