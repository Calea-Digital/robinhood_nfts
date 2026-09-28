// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {WhitelistImport} from "../src/WhitelistImport.sol";

/// @dev Shared fixture: a list owned by MINT's admin, open until `CLOSE_AT`.
abstract contract WhitelistImportBase is Test {
    WhitelistImport internal wl;

    address internal admin = makeAddr("mintAdmin");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint40 internal constant NOW = 1_790_640_000; // 2026-09-29 00:00 UTC
    uint40 internal constant CLOSE_AT = 1_792_972_799; // 2026-10-25 23:59:59 UTC

    event AllocationsAdded(address indexed wallet, uint8 count, uint8 total);
    event AllocationsRemoved(address indexed wallet, uint8 count);
    event CloseSet(uint40 closeAt);

    function setUp() public virtual {
        vm.warp(NOW);
        wl = new WhitelistImport(admin, CLOSE_AT);
    }

    function _one(address wallet, uint8 count) internal pure returns (address[] memory w, uint8[] memory c) {
        w = new address[](1);
        c = new uint8[](1);
        w[0] = wallet;
        c[0] = count;
    }

    function _two(address a, uint8 ca, address b, uint8 cb)
        internal
        pure
        returns (address[] memory w, uint8[] memory c)
    {
        w = new address[](2);
        c = new uint8[](2);
        (w[0], w[1], c[0], c[1]) = (a, b, ca, cb);
    }

    function _add(address wallet, uint8 count) internal {
        (address[] memory w, uint8[] memory c) = _one(wallet, count);
        vm.prank(admin);
        wl.addAllocations(w, c);
    }

    function _remove(address wallet) internal {
        address[] memory w = new address[](1);
        w[0] = wallet;
        vm.prank(admin);
        wl.removeAllocations(w);
    }

    function _expectAddRevert(address[] memory w, uint8[] memory c, bytes4 err) internal {
        vm.prank(admin);
        vm.expectRevert(err);
        wl.addAllocations(w, c);
    }

    function _wallet(uint256 i) internal pure returns (address) {
        return vm.addr(0x10000 + i);
    }

    /// @dev Every row of the list, read in pages of `page`.
    function _rows(uint256 page) internal view returns (WhitelistImport.Claimant[] memory all) {
        uint256 n = _total() - wl.spotsLeft(); // an upper bound on rows
        all = new WhitelistImport.Claimant[](n);
        uint256 count;
        for (uint256 offset;; offset += page) {
            WhitelistImport.Claimant[] memory rows = wl.claimants(offset, page);
            for (uint256 i; i < rows.length; ++i) {
                all[count++] = rows[i];
            }
            if (rows.length < page) break;
        }
        assembly {
            mstore(all, count)
        }
    }

    function _total() internal view returns (uint256) {
        return wl.TOTAL_SPOTS();
    }

    /// @dev The list is dense, each wallet once, allocations equal to `claimsOf`, and totals match.
    function _assertConsistent() internal view {
        WhitelistImport.Claimant[] memory rows = _rows(7);
        uint256 sum;
        for (uint256 i; i < rows.length; ++i) {
            assertGt(rows[i].allocations, 0, "no empty row");
            assertEq(rows[i].allocations, wl.claimsOf(rows[i].wallet), "row == claimsOf");
            for (uint256 j; j < i; ++j) {
                assertTrue(rows[i].wallet != rows[j].wallet, "each wallet once");
            }
            sum += rows[i].allocations;
        }
        assertEq(sum, _total() - wl.spotsLeft(), "rows total the spots taken");
    }
}

/// @dev WL-7. The freeze, the owner's writes and their refusals, the reads.
contract WhitelistImportFreezeTest is WhitelistImportBase {
    function test_import_freezesAtTheClose() public {
        /* Scenario: WL-7 — The owner's import freezes at the close
           Given a WhitelistImport whose closeAt has not passed
           When the owner adds allocations for wallets A (2) and B (1), and closeAt then passes
           Then claimsOf(A) reads 2, claimsOf(B) reads 1 and spotsLeft reads 997
           And any later addAllocations, removeAllocations or setCloseAt reverts with ListFrozen */
        (address[] memory w, uint8[] memory c) = _two(alice, 2, bob, 1);
        vm.prank(admin);
        wl.addAllocations(w, c);

        vm.warp(uint256(CLOSE_AT) + 1);
        assertTrue(wl.frozen());
        assertEq(wl.claimsOf(alice), 2);
        assertEq(wl.claimsOf(bob), 1);
        assertEq(wl.spotsLeft(), 997);

        (w, c) = _one(carol, 1);
        _expectAddRevert(w, c, WhitelistImport.ListFrozen.selector);

        address[] memory gone = new address[](1);
        gone[0] = bob;
        vm.prank(admin);
        vm.expectRevert(WhitelistImport.ListFrozen.selector);
        wl.removeAllocations(gone);

        vm.prank(admin);
        vm.expectRevert(WhitelistImport.ListFrozen.selector);
        wl.setCloseAt(uint40(block.timestamp + 1 days));

        assertEq(wl.claimsOf(bob), 1, "nothing changed after the freeze");
    }

    function test_frozen_isFalseAtTheClose_andTrueAfterIt() public {
        /* Scenario:
           Given the list open until closeAt
           When the time is exactly closeAt, then one second later
           Then frozen reads false and a write succeeds at closeAt; from closeAt + 1 frozen reads true */
        assertFalse(wl.frozen());
        vm.warp(CLOSE_AT);
        assertFalse(wl.frozen());
        _add(alice, 1);
        assertEq(wl.claimsOf(alice), 1);
        vm.warp(uint256(CLOSE_AT) + 1);
        assertTrue(wl.frozen());
    }
}

contract WhitelistImportAddTest is WhitelistImportBase {
    function test_add_notOwner_reverts() public {
        /* Scenario:
           Given a caller that is not the owner
           When it adds allocations
           Then it reverts with Unauthorized */
        (address[] memory w, uint8[] memory c) = _one(alice, 1);
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        wl.addAllocations(w, c);
    }

    function test_add_lengthMismatch_reverts() public {
        /* Scenario:
           Given two wallets and one count
           When the owner adds them
           Then it reverts with LengthMismatch */
        address[] memory w = new address[](2);
        (w[0], w[1]) = (alice, bob);
        uint8[] memory c = new uint8[](1);
        c[0] = 1;
        _expectAddRevert(w, c, WhitelistImport.LengthMismatch.selector);
    }

    function test_add_zeroWallet_reverts() public {
        /* Scenario:
           Given a row naming the zero address
           When the owner adds it
           Then it reverts with ZeroWallet */
        (address[] memory w, uint8[] memory c) = _one(address(0), 1);
        _expectAddRevert(w, c, WhitelistImport.ZeroWallet.selector);
    }

    function test_add_zeroCount_reverts() public {
        /* Scenario:
           Given a row with a count of zero
           When the owner adds it
           Then it reverts with ZeroCount */
        (address[] memory w, uint8[] memory c) = _one(alice, 0);
        _expectAddRevert(w, c, WhitelistImport.ZeroCount.selector);
    }

    function test_add_aboveTheWalletLimit_reverts() public {
        /* Scenario:
           Given a wallet given 3 at once, a wallet at 2 given 1 more, a wallet at 2 given 255, and one
             wallet named twice with 2 then 1
           When the owner adds each
           Then each reverts with WalletLimit, never an overflow panic */
        (address[] memory w, uint8[] memory c) = _one(alice, 3);
        _expectAddRevert(w, c, WhitelistImport.WalletLimit.selector);

        _add(bob, 2);
        (w, c) = _one(bob, 1);
        _expectAddRevert(w, c, WhitelistImport.WalletLimit.selector);
        (w, c) = _one(bob, 255);
        _expectAddRevert(w, c, WhitelistImport.WalletLimit.selector);

        (w, c) = _two(carol, 2, carol, 1);
        _expectAddRevert(w, c, WhitelistImport.WalletLimit.selector);
        assertEq(wl.claimsOf(carol), 0);
    }

    function test_add_pastTheTotal_revertsSoldOut() public {
        /* Scenario:
           Given 500 wallets of 2 filling the list
           When the owner adds one more allocation
           Then it reverts with SoldOut and spotsLeft reads 0 */
        address[] memory w = new address[](500);
        uint8[] memory c = new uint8[](500);
        for (uint256 i; i < 500; ++i) {
            (w[i], c[i]) = (_wallet(i), 2);
        }
        vm.prank(admin);
        wl.addAllocations(w, c);
        assertEq(wl.spotsLeft(), 0);

        (address[] memory one, uint8[] memory c1) = _one(alice, 1);
        _expectAddRevert(one, c1, WhitelistImport.SoldOut.selector);
        _assertConsistent();
    }

    function test_add_badRowRevertsTheWholeBatch() public {
        /* Scenario:
           Given a batch whose second row names the zero address
           When the owner adds it
           Then it reverts and the first row's wallet holds nothing, and spotsLeft reads 1,000 */
        (address[] memory w, uint8[] memory c) = _two(alice, 2, address(0), 1);
        _expectAddRevert(w, c, WhitelistImport.ZeroWallet.selector);
        assertEq(wl.claimsOf(alice), 0);
        assertEq(wl.spotsLeft(), 1000);
        assertEq(wl.claimants(0, 10).length, 0);
    }

    function test_add_firstFailingCheckNamesTheRevert() public {
        /* Scenario:
           Given writes that fail several checks at once
           When the owner or another caller sends them
           Then Unauthorized comes before ListFrozen, ListFrozen before LengthMismatch, and within a
             row ZeroWallet before ZeroCount before WalletLimit */
        address[] memory w = new address[](1);
        uint8[] memory c = new uint8[](0);
        vm.warp(uint256(CLOSE_AT) + 1);
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        wl.addAllocations(w, c);
        _expectAddRevert(w, c, WhitelistImport.ListFrozen.selector);

        vm.warp(NOW);
        _expectAddRevert(w, c, WhitelistImport.LengthMismatch.selector);
        (w, c) = _one(address(0), 0);
        _expectAddRevert(w, c, WhitelistImport.ZeroWallet.selector);
        (w, c) = _one(alice, 0);
        _expectAddRevert(w, c, WhitelistImport.ZeroCount.selector);
    }

    function test_add_emitsPerWallet_andListsEachWalletOnce() public {
        /* Scenario:
           Given alice at 1
           When the owner gives alice 1 more and bob 2
           Then AllocationsAdded carries each wallet's count and new total, alice is listed once,
             and spotsLeft reads 996 */
        _add(alice, 1);
        (address[] memory w, uint8[] memory c) = _two(alice, 1, bob, 2);
        vm.expectEmit(true, true, true, true, address(wl));
        emit AllocationsAdded(alice, 1, 2);
        vm.expectEmit(true, true, true, true, address(wl));
        emit AllocationsAdded(bob, 2, 2);
        vm.prank(admin);
        wl.addAllocations(w, c);

        WhitelistImport.Claimant[] memory rows = wl.claimants(0, 10);
        assertEq(rows.length, 2);
        assertEq(rows[0].wallet, alice);
        assertEq(rows[0].allocations, 2);
        assertEq(rows[1].wallet, bob);
        assertEq(rows[1].allocations, 2);
        assertEq(wl.spotsLeft(), 996);
    }

    function test_add_emptyBatch_changesNothing() public {
        /* Scenario:
           Given an empty batch
           When the owner adds it
           Then it succeeds and spotsLeft reads 1,000 */
        vm.prank(admin);
        wl.addAllocations(new address[](0), new uint8[](0));
        assertEq(wl.spotsLeft(), 1000);
    }
}

contract WhitelistImportRemoveTest is WhitelistImportBase {
    function test_remove_notOwner_reverts() public {
        /* Scenario:
           Given alice listed and a caller that is not the owner
           When it removes alice
           Then it reverts with Unauthorized */
        _add(alice, 1);
        address[] memory w = new address[](1);
        w[0] = alice;
        vm.prank(bob);
        vm.expectRevert(Ownable.Unauthorized.selector);
        wl.removeAllocations(w);
    }

    function test_remove_notListed_reverts_andADuplicateRevertsTheCall() public {
        /* Scenario:
           Given bob not listed, and alice listed
           When the owner removes bob, then alice named twice
           Then each reverts with NotListed and alice keeps her allocation */
        address[] memory w = new address[](1);
        w[0] = bob;
        vm.prank(admin);
        vm.expectRevert(WhitelistImport.NotListed.selector);
        wl.removeAllocations(w);

        _add(alice, 2);
        w = new address[](2);
        (w[0], w[1]) = (alice, alice);
        vm.prank(admin);
        vm.expectRevert(WhitelistImport.NotListed.selector);
        wl.removeAllocations(w);
        assertEq(wl.claimsOf(alice), 2);
    }

    function test_remove_zeroesTheWallet_andKeepsTheListDense() public {
        /* Scenario:
           Given alice (2), bob (1) and carol (2) listed in that order
           When the owner removes alice
           Then claimsOf(alice) reads 0, spotsLeft rises by 2, AllocationsRemoved is emitted, and carol
             moves into the first row */
        _add(alice, 2);
        _add(bob, 1);
        _add(carol, 2);

        address[] memory w = new address[](1);
        w[0] = alice;
        vm.expectEmit(true, true, true, true, address(wl));
        emit AllocationsRemoved(alice, 2);
        vm.prank(admin);
        wl.removeAllocations(w);

        assertEq(wl.claimsOf(alice), 0);
        assertEq(wl.spotsLeft(), 997);
        WhitelistImport.Claimant[] memory rows = wl.claimants(0, 10);
        assertEq(rows.length, 2);
        assertEq(rows[0].wallet, carol);
        assertEq(rows[1].wallet, bob);
        _assertConsistent();
    }

    function test_remove_lastAndOnlyRows_andReAdd() public {
        /* Scenario:
           Given alice and bob listed
           When the owner removes bob (the last row), then alice (the only row), then adds alice again
           Then the list reads empty in between and alice is listed once at the end */
        _add(alice, 1);
        _add(bob, 2);
        _remove(bob);
        _assertConsistent();
        _remove(alice);
        assertEq(wl.claimants(0, 10).length, 0);
        assertEq(wl.spotsLeft(), 1000);

        _add(alice, 2);
        WhitelistImport.Claimant[] memory rows = wl.claimants(0, 10);
        assertEq(rows.length, 1);
        assertEq(rows[0].wallet, alice);
        assertEq(rows[0].allocations, 2);
        _assertConsistent();
    }

    function test_remove_manyInOneBatch_staysConsistent() public {
        /* Scenario:
           Given ten wallets listed
           When the owner removes the first, a middle and the last one in one batch
           Then seven rows remain, each once, totalling the spots taken */
        for (uint256 i; i < 10; ++i) {
            _add(_wallet(i), uint8(1 + (i % 2)));
        }
        address[] memory w = new address[](3);
        (w[0], w[1], w[2]) = (_wallet(0), _wallet(5), _wallet(9));
        vm.prank(admin);
        wl.removeAllocations(w);
        assertEq(wl.claimants(0, 20).length, 7);
        _assertConsistent();
    }
}

contract WhitelistImportCloseTest is WhitelistImportBase {
    function test_setCloseAt_notOwner_reverts() public {
        /* Scenario:
           Given a caller that is not the owner
           When it sets the close
           Then it reverts with Unauthorized */
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        wl.setCloseAt(CLOSE_AT + 1);
    }

    function test_setCloseAt_inThePast_reverts() public {
        /* Scenario:
           Given the current time
           When the owner sets a close one second ago
           Then it reverts with InvalidWindow */
        vm.prank(admin);
        vm.expectRevert(WhitelistImport.InvalidWindow.selector);
        wl.setCloseAt(uint40(block.timestamp - 1));
    }

    function test_setCloseAt_extends_andFreezesEarly() public {
        /* Scenario:
           Given the list open until closeAt
           When the owner moves the close a day later, and later sets it to the current timestamp
           Then CloseSet is emitted each time, writes succeed until the new close, and the list is
             frozen from the next second */
        vm.expectEmit(true, true, true, true, address(wl));
        emit CloseSet(CLOSE_AT + 1 days);
        vm.prank(admin);
        wl.setCloseAt(CLOSE_AT + 1 days);
        assertEq(wl.closeAt(), CLOSE_AT + 1 days);

        vm.warp(uint256(CLOSE_AT) + 1);
        _add(alice, 1);
        assertEq(wl.claimsOf(alice), 1);

        vm.prank(admin);
        wl.setCloseAt(uint40(block.timestamp));
        assertFalse(wl.frozen());
        vm.warp(block.timestamp + 1);
        assertTrue(wl.frozen());
    }
}

contract WhitelistImportOwnershipTest is WhitelistImportBase {
    function test_constructor_refusesZeroOwner_andAPastClose() public {
        /* Scenario:
           Given the zero address as owner, or a close in the past
           When the list is deployed
           Then it reverts with NewOwnerIsZeroAddress, or InvalidWindow */
        vm.expectRevert(Ownable.NewOwnerIsZeroAddress.selector);
        new WhitelistImport(address(0), CLOSE_AT);
        vm.expectRevert(WhitelistImport.InvalidWindow.selector);
        new WhitelistImport(admin, NOW - 1);
    }

    function test_constructor_setsOwnerCloseAndEmits() public {
        /* Scenario:
           Given MINT's admin and a close
           When the list is deployed
           Then owner and closeAt are the constructor's, CloseSet is emitted and spotsLeft reads 1,000 */
        vm.expectEmit(true, true, true, true);
        emit CloseSet(CLOSE_AT);
        WhitelistImport fresh = new WhitelistImport(admin, CLOSE_AT);
        assertEq(fresh.owner(), admin);
        assertEq(fresh.closeAt(), CLOSE_AT);
        assertEq(fresh.spotsLeft(), 1000);
        assertEq(fresh.TOTAL_SPOTS(), 1000);
        assertEq(fresh.MAX_PER_WALLET(), 2);
    }

    function test_transferOwnership_movesTheWrites() public {
        /* Scenario:
           Given the admin hands ownership to a new owner
           When each writes
           Then the new owner's writes succeed and the previous owner's revert with Unauthorized */
        address next = makeAddr("nextAdmin");
        vm.prank(admin);
        wl.transferOwnership(next);

        (address[] memory w, uint8[] memory c) = _one(alice, 1);
        vm.prank(admin);
        vm.expectRevert(Ownable.Unauthorized.selector);
        wl.addAllocations(w, c);

        vm.prank(next);
        wl.addAllocations(w, c);
        vm.prank(next);
        wl.setCloseAt(CLOSE_AT);
        w[0] = alice;
        vm.prank(next);
        wl.removeAllocations(w);
        assertEq(wl.claimsOf(alice), 0);
    }

    function test_renounceOwnership_reverts() public {
        /* Scenario:
           Given the owner and another caller
           When either renounces ownership
           Then it reverts with RenounceDisabled and the admin still owns the list */
        vm.prank(admin);
        vm.expectRevert(WhitelistImport.RenounceDisabled.selector);
        wl.renounceOwnership();
        vm.prank(alice);
        vm.expectRevert(WhitelistImport.RenounceDisabled.selector);
        wl.renounceOwnership();
        assertEq(wl.owner(), admin);
    }
}

contract WhitelistImportReadsTest is WhitelistImportBase {
    function test_claimants_emptyShortAndPastTheEnd() public {
        /* Scenario:
           Given an empty list, then three wallets listed
           When claimants is read empty, with a page running past the end, and from past the end
           Then it returns no rows, a short page, and an empty page rather than reverting */
        assertEq(wl.claimants(0, 10).length, 0);
        _add(alice, 1);
        _add(bob, 2);
        _add(carol, 1);
        assertEq(wl.claimants(1, 10).length, 2);
        assertEq(wl.claimants(0, 2).length, 2);
        assertEq(wl.claimants(3, 10).length, 0);
        assertEq(wl.claimants(99, 10).length, 0);
        _assertConsistent();
    }
}
