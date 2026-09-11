// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest} from "./BaseTest.t.sol";
import {MintABear} from "../src/MintABear.sol";
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
           Then the call is refused */
        vm.expectRevert();
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
