// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest} from "../BaseTest.t.sol";
import {MintABear} from "../../src/MintABear.sol";

/**
 * @title  BurnStrandsAccountRegression
 * @notice Kept from the pre-audit review of 2026-09-14, where these cases passed as
 *         exploits. They are retained inverted: each asserts the refusal that now stops it.
 *
 * @dev    The finding. `ERC721SeaDrop` declares `function burn(uint256) external` at
 *         `lib/seadrop/src/ERC721SeaDrop.sol:154`, neither `virtual` nor internal, so
 *         `MintABear` cannot override it. It reaches `_burn(tokenId, true)`, whose
 *         `approvalCheck` admits approved operators as well as the owner.
 *
 *         The damage, as found. Every bear then owned an ERC-6551 account that resolved its
 *         controller through `ownerOf`; after a burn that call failed, the account had no
 *         owner and whatever it held was unreachable for good. Token-bound accounts are not
 *         part of the collection (COL-9), so that loss cannot occur. What an admitted burn
 *         would still do is destroy a bear and shrink the supply, which COL-8 forbids: no
 *         bear can be destroyed by anyone, its owner included, and `totalSupply` never falls.
 *
 *         The fix. Every burn routes through `_beforeTokenTransfers` with `to` set to the
 *         zero address, and no other path sets `to` to zero, so the hook refuses it.
 */
contract BurnStrandsAccountRegression is BaseTest {
    function test_regression_ownerCannotBurn() public {
        /* Scenario: COL-8 — No bear can be destroyed
           Given a bear owned by alice
           When alice calls the inherited SeaDrop burn
           Then the burn is refused and the bear is exactly as it was */
        _mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.burn(1);

        assertEq(bears.ownerOf(1), alice, "still alice's");
        assertEq(bears.transferNonce(1), 0, "counter untouched");
    }

    function test_regression_approvedOperatorCannotBurn() public {
        /* Scenario: COL-8 — No bear can be destroyed
           Given alice approved an operator for her bear
           When the operator calls burn
           Then it is refused, so an approval cannot destroy a holder's bear */
        _mint(alice, 1);

        vm.prank(alice);
        bears.setApprovalForAll(operator, true);

        vm.prank(operator);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.burn(1);

        assertEq(bears.ownerOf(1), alice, "operator could not destroy the bear");
    }

    function test_regression_supplyCannotBeReduced() public {
        /* Scenario: COL-8 — No bear can be destroyed
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
