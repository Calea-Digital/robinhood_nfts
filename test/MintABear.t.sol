// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest} from "./BaseTest.t.sol";
import {MintABear} from "../src/MintABear.sol";
import {BearAccount} from "../src/BearAccount.sol";
import {MockRenderer} from "./mocks/MockRenderer.sol";

contract MintABearTest is BaseTest {
    function test_startTokenId_isOne() public {
        /* Scenario:
           Given a fresh collection
           When the first bear is minted
           Then it is numbered 1, not 0 */
        _mint(alice, 1);
        assertEq(bears.ownerOf(1), alice);
        vm.expectRevert();
        bears.ownerOf(0);
    }

    function test_mint_recordsBearAccount() public {
        /* Scenario:
           Given a bear that has just been minted
           When its canonical account address is queried
           Then that address is recorded as a bear account */
        _mint(alice, 1);
        assertTrue(bears.isBearAccount(bears.accountOf(1)));
    }

    function test_mint_doesNotAdvanceTransferNonce() public {
        /* Scenario:
           Given a freshly minted bear
           When its transfer counter is read
           Then it is still zero, because minting is not a transfer */
        _mint(alice, 1);
        assertEq(bears.transferNonce(1), 0);
    }

    function test_transfer_advancesTransferNonce() public {
        /* Scenario:
           Given a bear owned by alice
           When alice transfers it to bob
           Then the transfer counter advances by exactly one */
        _mint(alice, 1);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertEq(bears.transferNonce(1), 1);
    }

    function test_transfer_toDeployedBearAccount_reverts() public {
        /* Scenario:
           Given two bears, with the second one's account deployed
           When the first bear is sent into the second bear's account
           Then the transfer is refused */
        _mint(alice, 2);
        address account2 = bears.deployAccount(2);

        vm.prank(alice);
        vm.expectRevert(MintABear.TransferToBearAccount.selector);
        bears.transferFrom(alice, account2, 1);
    }

    function test_transfer_toUndeployedBearAccount_reverts() public {
        /* Scenario:
           Given two bears where the second one's account has never been deployed
           When the first bear is sent to that undeployed address
           Then the transfer is still refused, because the address was recorded at mint */
        _mint(alice, 2);
        address account2 = bears.accountOf(2);
        assertEq(account2.code.length, 0, "account should not be deployed");

        vm.prank(alice);
        vm.expectRevert(MintABear.TransferToBearAccount.selector);
        bears.transferFrom(alice, account2, 1);
    }

    function test_transfer_toOwnAccount_reverts() public {
        /* Scenario:
           Given a bear
           When it is sent into its own account
           Then the transfer is refused, which is the cycle the specification names */
        _mint(alice, 1);
        address ownAccount = bears.accountOf(1);

        vm.prank(alice);
        vm.expectRevert(MintABear.TransferToBearAccount.selector);
        bears.transferFrom(alice, ownAccount, 1);
    }

    function test_mint_toBearAccount_reverts() public {
        /* Scenario:
           Given an existing bear
           When a new bear is minted directly into that bear's account
           Then the mint is refused, so the rule holds on the mint path too */
        _mint(alice, 1);
        address account1 = bears.accountOf(1);

        vm.prank(seaDrop);
        vm.expectRevert(MintABear.TransferToBearAccount.selector);
        bears.mintSeaDrop(account1, 1);
    }

    function test_deployAccount_matchesPredictedAddress() public {
        /* Scenario:
           Given a minted bear
           When its account is deployed
           Then it appears at exactly the address accountOf predicted */
        _mint(alice, 1);
        address predicted = bears.accountOf(1);
        address deployed = bears.deployAccount(1);
        assertEq(deployed, predicted);
        assertGt(deployed.code.length, 0);
    }

    function test_deployAccount_isIdempotent() public {
        /* Scenario:
           Given a bear whose account is already deployed
           When deployAccount is called again
           Then it returns the same address without reverting */
        _mint(alice, 1);
        address first = bears.deployAccount(1);
        address second = bears.deployAccount(1);
        assertEq(first, second);
    }

    function test_tokenURI_delegatesToRenderer() public {
        /* Scenario:
           Given a renderer that returns an identifiable value
           When tokenURI is read
           Then the token returns exactly what the renderer returned */
        _mint(alice, 1);
        MockRenderer mock = new MockRenderer("RENDERED");
        bears.setRenderer(address(mock));
        assertEq(bears.tokenURI(1), "RENDERED");
    }

    function test_tokenURI_nonexistent_reverts() public {
        /* Scenario:
           Given a bear that was never minted
           When its tokenURI is read
           Then it reverts rather than rendering nothing */
        vm.expectRevert();
        bears.tokenURI(1);
    }

    function test_setRenderer_byNonOwner_reverts() public {
        /* Scenario:
           Given a wallet that does not own the contract
           When it tries to replace the renderer
           Then the call is refused */
        MockRenderer mock = new MockRenderer("X");
        vm.prank(alice);
        vm.expectRevert();
        bears.setRenderer(address(mock));
    }

    function test_constructor_zeroAccountImplementation_reverts() public {
        /* Scenario:
           Given a deployment that forgets the account implementation
           When the collection is constructed
           Then it is refused, because every bear's account address derives from it */
        address[] memory allowed = new address[](1);
        allowed[0] = seaDrop;

        vm.expectRevert(MintABear.AccountImplementationIsZeroAddress.selector);
        new MintABear("MintABear", "BEAR", allowed, address(0), address(renderer));
    }

    function test_constructor_zeroRenderer_reverts() public {
        /* Scenario:
           Given a deployment that forgets the renderer
           When the collection is constructed
           Then it is refused, so tokenURI can never point at nothing */
        address[] memory allowed = new address[](1);
        allowed[0] = seaDrop;

        vm.expectRevert(MintABear.RendererIsZeroAddress.selector);
        new MintABear("MintABear", "BEAR", allowed, address(accountImpl), address(0));
    }

    function test_constructor_recordsBothAddresses() public {
        /* Scenario:
           Given a valid deployment
           When the stored addresses are read
           Then both are exactly what was passed in */
        assertEq(bears.ACCOUNT_IMPLEMENTATION(), address(accountImpl));
        assertEq(address(bears.renderer()), address(renderer));
    }

    function test_setRenderer_zeroAddress_reverts() public {
        /* Scenario:
           Given the contract owner
           When they try to set the renderer to the zero address
           Then the call is refused, so tokenURI can never point at nothing */
        vm.expectRevert(MintABear.RendererIsZeroAddress.selector);
        bears.setRenderer(address(0));
    }

    function test_maxSupply_isEnforced() public {
        /* Scenario:
           Given a collection capped at 4,444
           When a mint would exceed the cap
           Then it reverts */
        _mint(alice, MAX_SUPPLY);
        vm.prank(seaDrop);
        vm.expectRevert();
        bears.mintSeaDrop(alice, 1);
        assertEq(bears.totalSupply(), MAX_SUPPLY);
    }

    function test_transferValidator_defaultsToUnset() public {
        /* Scenario:
           Given a freshly deployed collection
           When the transfer validator is read
           Then it is unset, so transfers are free and cost no extra gas */
        assertEq(bears.getTransferValidator(), address(0));
    }
}

contract MintABearBranchTest is BaseTest {
    function test_deployAccount_forNonexistentBear_reverts() public {
        /* Scenario:
           Given a bear that was never minted
           When someone tries to deploy its account
           Then the call is refused, naming the bear rather than a URI query */
        vm.expectRevert(MintABear.BearDoesNotExist.selector);
        bears.deployAccount(1);
    }

    function test_transfer_toOrdinaryAddress_succeeds() public {
        /* Scenario:
           Given a bear and a destination that is not a bear account
           When it is transferred
           Then it succeeds, confirming the guard does not block normal transfers */
        _mint(alice, 1);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertEq(bears.ownerOf(1), bob);
    }

    function test_batchMint_recordsEveryAccount() public {
        /* Scenario:
           Given a batch mint of several bears
           When each bear's account address is checked
           Then every one of them is recorded, not just the first */
        _mint(alice, 5);
        for (uint256 id = 1; id <= 5; ++id) {
            assertTrue(bears.isBearAccount(bears.accountOf(id)), "account not recorded");
        }
    }
}

/// @dev `ERC721SeaDrop` exposes a public, non-virtual `burn`. It cannot be overridden, so it
///      is refused in the transfer hook. Removing that refusal makes every test here fail.
contract MintABearBurnGuardTest is BaseTest {
    function test_burn_byOwner_reverts() public {
        /* Scenario:
           Given a bear owned by alice
           When alice calls the inherited SeaDrop burn
           Then it is refused with BurnDisabled */
        _mint(alice, 1);
        vm.prank(alice);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.burn(1);
    }

    function test_burn_byApprovedOperator_reverts() public {
        /* Scenario:
           Given alice approved an operator for all her bears
           When the operator calls burn
           Then it is refused, so an approval cannot destroy a holder's bear */
        _mint(alice, 1);
        vm.prank(alice);
        bears.setApprovalForAll(operator, true);

        vm.prank(operator);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.burn(1);
    }

    function test_burn_leavesSupplyAndOwnershipIntact() public {
        /* Scenario:
           Given a bear that someone has tried to burn
           When supply and ownership are read
           Then nothing moved, so the id can never be orphaned */
        _mint(alice, 1);
        vm.prank(alice);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.burn(1);

        assertEq(bears.totalSupply(), 1, "supply unchanged");
        assertEq(bears.ownerOf(1), alice, "owner unchanged");
        assertEq(bears.transferNonce(1), 0, "counter unchanged");
    }

    function test_burn_cannotStrandAccountAssets() public {
        /* Scenario:
           Given a bear whose account holds ETH
           When a burn is attempted and refused
           Then the account still resolves its owner and the funds remain reachable */
        _mint(alice, 1);
        address payable account = payable(bears.deployAccount(1));
        vm.deal(account, 5 ether);

        vm.prank(alice);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.burn(1);

        assertEq(BearAccount(account).owner(), alice, "account still owned");

        vm.prank(alice);
        BearAccount(account).execute(bob, 5 ether, "", 0);
        assertEq(bob.balance, 5 ether, "funds still reachable");
    }
}

/// @dev Accounts are recorded as each bear mints, which leaves every not-yet-minted bear's
///      account address unguarded until it mints. `recordAccounts` closes that window.
contract MintABearAccountRecordingTest is BaseTest {
    /// @dev Mirrors `MintABear.AccountsRecorded`; solc 0.8.17 cannot qualify an event by
    ///      contract name in an `emit`, which `expectEmit` needs.
    event AccountsRecorded(uint256 fromTokenId, uint256 toTokenId);

    function test_preMintWindow_isClosedByRecordAccounts() public {
        /* Scenario:
           Given bear 1 is minted and bear 100 is not
           When bear 1 is sent to bear 100's future account address
           Then it is refused, because the range was pre-recorded */
        bears.recordAccounts(1, MAX_SUPPLY);
        _mint(alice, 1);

        address future = bears.accountOf(100);
        vm.prank(alice);
        vm.expectRevert(MintABear.TransferToBearAccount.selector);
        bears.transferFrom(alice, future, 1);
    }

    function test_withoutRecording_preMintWindowIsOpen() public {
        /* Scenario:
           Given no range has been pre-recorded
           When bear 1 is sent to bear 100's future account address
           Then it succeeds — this is the window recordAccounts exists to close */
        _mint(alice, 1);

        address future = bears.accountOf(100);
        vm.prank(alice);
        bears.transferFrom(alice, future, 1);
        assertEq(bears.ownerOf(1), future, "documents the untreated behaviour");
    }

    function test_recordAccounts_marksTheWholeRange() public {
        /* Scenario:
           Given a recorded range of ids
           When each account address is checked
           Then all of them are marked, none outside the range */
        bears.recordAccounts(10, 20);
        for (uint256 id = 10; id <= 20; ++id) {
            assertTrue(bears.isBearAccount(bears.accountOf(id)), "inside range not marked");
        }
        assertFalse(bears.isBearAccount(bears.accountOf(9)), "below range marked");
        assertFalse(bears.isBearAccount(bears.accountOf(21)), "above range marked");
    }

    function test_recordAccounts_isPermissionless() public {
        /* Scenario:
           Given a caller who is not the owner
           When they record a range
           Then it succeeds, because the only addresses it can mark are ones derived here */
        vm.prank(bob);
        bears.recordAccounts(1, 5);
        assertTrue(bears.isBearAccount(bears.accountOf(3)));
    }

    function test_recordAccounts_isIdempotent() public {
        /* Scenario:
           Given a range that has already been recorded
           When it is recorded again
           Then the call succeeds and nothing changes */
        bears.recordAccounts(1, 5);
        bears.recordAccounts(1, 5);
        assertTrue(bears.isBearAccount(bears.accountOf(1)));
    }

    function test_recordAccounts_emitsTheRange() public {
        /* Scenario:
           Given a recording call
           When the logs are read
           Then the range is emitted, so coverage can be verified from events */
        vm.expectEmit(false, false, false, true);
        emit AccountsRecorded(1, 5);
        bears.recordAccounts(1, 5);
    }

    function test_recordAccounts_rejectsZeroStart() public {
        /* Scenario:
           Given a range starting at token id 0, which never exists
           When it is recorded
           Then it is refused */
        vm.expectRevert(MintABear.InvalidTokenRange.selector);
        bears.recordAccounts(0, 5);
    }

    function test_recordAccounts_rejectsInvertedRange() public {
        /* Scenario:
           Given a range whose end precedes its start
           When it is recorded
           Then it is refused */
        vm.expectRevert(MintABear.InvalidTokenRange.selector);
        bears.recordAccounts(5, 4);
    }

    function test_recordAccounts_rejectsBeyondHardCap() public {
        /* Scenario:
           Given a range that runs past the hard cap
           When it is recorded
           Then it is refused, so the mapping only ever holds real bear accounts */
        uint256 cap = bears.MAX_BEARS();
        vm.expectRevert(MintABear.InvalidTokenRange.selector);
        bears.recordAccounts(1, cap + 1);
    }

    function test_recordAccounts_worksBeforeMaxSupplyIsSet() public {
        /* Scenario:
           Given a freshly deployed collection whose maxSupply is still zero
           When the full range is recorded
           Then it succeeds, because the bound is the constant and not the setting */
        address[] memory allowed = new address[](1);
        allowed[0] = seaDrop;
        MintABear fresh = new MintABear("MintABear", "BEAR", allowed, address(accountImpl), address(renderer));

        assertEq(fresh.maxSupply(), 0, "maxSupply unset");
        fresh.recordAccounts(1, fresh.MAX_BEARS());
        assertTrue(fresh.isBearAccount(fresh.accountOf(4444)));
    }

    function test_recordAccounts_doesNotBlockNormalMintingOrTransfer() public {
        /* Scenario:
           Given the entire supply has been pre-recorded
           When bears are minted and transferred to ordinary addresses
           Then both still work, so the guard has not over-reached */
        bears.recordAccounts(1, MAX_SUPPLY);

        _mint(alice, 3);
        assertEq(bears.ownerOf(1), alice);

        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertEq(bears.ownerOf(1), bob);
        assertEq(bears.transferNonce(1), 1);
    }

    function test_recordAccounts_fullSupplyInBatches() public {
        /* Scenario:
           Given the full 4,444 supply
           When it is recorded in four batches, as it will be on deploy day
           Then every account address is marked */
        bears.recordAccounts(1, 1111);
        bears.recordAccounts(1112, 2222);
        bears.recordAccounts(2223, 3333);
        bears.recordAccounts(3334, MAX_SUPPLY);

        assertTrue(bears.isBearAccount(bears.accountOf(1)));
        assertTrue(bears.isBearAccount(bears.accountOf(2222)));
        assertTrue(bears.isBearAccount(bears.accountOf(MAX_SUPPLY)));
    }
}

/// @dev `maxSupply` is an owner setting on the SeaDrop base, raisable at any time and by
///      OpenSea Studio through `multiConfigure`. `MAX_BEARS` is the constant that makes the
///      stated 4,444 true regardless of how it is configured.
contract MintABearSupplyCapTest is BaseTest {
    function test_maxBears_isTheStatedSupply() public {
        /* Scenario:
           Given the collection
           When the hard cap is read
           Then it is 4,444, and it is a constant */
        assertEq(bears.MAX_BEARS(), 4444);
    }

    function test_mint_exactlyToTheCap_succeeds() public {
        /* Scenario:
           Given an empty collection
           When the full supply is minted
           Then it succeeds and the last bear is 4,444 */
        _mint(alice, MAX_SUPPLY);
        assertEq(bears.totalSupply(), 4444);
        assertEq(bears.ownerOf(4444), alice);
    }

    function test_mint_pastTheCap_reverts_evenWhenMaxSupplyIsRaised() public {
        /* Scenario:
           Given an owner who raises maxSupply past the stated supply
           When they try to mint the 4,445th bear
           Then the hard cap refuses it */
        bears.setMaxSupply(10_000);
        _mint(alice, MAX_SUPPLY);

        vm.prank(seaDrop);
        vm.expectRevert(MintABear.ExceedsMaxBears.selector);
        bears.mintSeaDrop(alice, 1);
    }

    function test_mint_batchStraddlingTheCap_reverts() public {
        /* Scenario:
           Given a batch that would start below the cap and end above it
           When it is minted
           Then the whole batch is refused rather than partly filled */
        bears.setMaxSupply(10_000);
        _mint(alice, MAX_SUPPLY - 2);

        vm.prank(seaDrop);
        vm.expectRevert(MintABear.ExceedsMaxBears.selector);
        bears.mintSeaDrop(alice, 3);

        assertEq(bears.totalSupply(), MAX_SUPPLY - 2, "nothing minted");
    }

    function test_maxSupplyRemainsRaisable_butMeaningless() public {
        /* Scenario:
           Given the owner raises maxSupply
           When the setting is read back
           Then it changed, which is why the hard cap and not this value is the guarantee */
        bears.setMaxSupply(10_000);
        assertEq(bears.maxSupply(), 10_000);
        assertEq(bears.MAX_BEARS(), 4444);
    }
}
