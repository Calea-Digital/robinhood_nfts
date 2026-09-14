// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest} from "./BaseTest.t.sol";
import {BearAccount} from "../src/BearAccount.sol";
import {ERC6551} from "solady/accounts/ERC6551.sol";
import {MockERC721} from "./mocks/MockERC721.sol";

/// @dev Every behaviour here comes from Solady's `ERC6551`; `BearAccount` overrides only the
///      ERC-1271 domain. These tests exist because the product requirement — "gives every Bear
///      its own onchain wallet to hold/move MNTD, ETH, NFTs" — is discharged entirely by
///      inherited code, and inherited code that nothing exercises is inherited code nobody has
///      checked against this deployment.
contract BearAccountTest is BaseTest {
    BearAccount internal account;
    MockERC721 internal outsideNft;

    function setUp() public virtual override {
        super.setUp();
        _mint(alice, 1);
        account = BearAccount(payable(bears.deployAccount(1)));
        outsideNft = new MockERC721();
    }

    /*                        OWNERSHIP                        */

    function test_owner_isTheBearsOwner() public {
        /* Scenario:
           Given a deployed bear account
           When its owner is read
           Then it is whoever holds the bear */
        assertEq(account.owner(), alice);
    }

    function test_owner_followsTheBearOnTransfer() public {
        /* Scenario:
           Given alice's bear account
           When the bear is sold to bob
           Then control of the account moves with it, with no action by either party */
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertEq(account.owner(), bob);
    }

    function test_token_returnsTheBinding() public {
        /* Scenario:
           Given a bear account
           When its binding is read
           Then it names this chain, this collection and this bear */
        (uint256 chainId, address tokenContract, uint256 tokenId) = account.token();
        assertEq(chainId, block.chainid);
        assertEq(tokenContract, address(bears));
        assertEq(tokenId, 1);
    }

    function test_isValidSigner_onlyTheOwner() public {
        /* Scenario:
           Given a bear account
           When signers are checked
           Then only the current owner is valid */
        assertEq(account.isValidSigner(alice, ""), bytes4(0x523e3260));
        assertEq(account.isValidSigner(bob, ""), bytes4(0));

        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);

        assertEq(account.isValidSigner(alice, ""), bytes4(0));
        assertEq(account.isValidSigner(bob, ""), bytes4(0x523e3260));
    }

    /*                     ASSET CUSTODY                       */

    function test_holdsAndMovesEth() public {
        /* Scenario:
           Given a bear account funded with ETH
           When its owner executes a transfer out
           Then the ETH moves */
        vm.deal(address(account), 3 ether);

        vm.prank(alice);
        account.execute(bob, 1 ether, "", 0);

        assertEq(bob.balance, 1 ether);
        assertEq(address(account).balance, 2 ether);
    }

    function test_holdsAndMovesMntd() public {
        /* Scenario:
           Given a bear account holding $MNTD
           When its owner executes a transfer out
           Then the tokens move */
        mntd.mint(address(account), 1_000 * UNIT);

        vm.prank(alice);
        account.execute(address(mntd), 0, abi.encodeWithSignature("transfer(address,uint256)", bob, 400 * UNIT), 0);

        assertEq(mntd.balanceOf(bob), 400 * UNIT);
        assertEq(mntd.balanceOf(address(account)), 600 * UNIT);
    }

    function test_holdsAndMovesOutsideNfts() public {
        /* Scenario:
           Given a bear account holding an NFT from another collection
           When its owner executes a transfer out
           Then the NFT moves */
        outsideNft.mint(address(account), 7);
        assertEq(outsideNft.ownerOf(7), address(account));

        vm.prank(alice);
        account.execute(
            address(outsideNft),
            0,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", address(account), bob, uint256(7)),
            0
        );

        assertEq(outsideNft.ownerOf(7), bob);
    }

    function test_acceptsSafeTransferredNfts() public {
        /* Scenario:
           Given an NFT sent with safeTransferFrom
           When the account's receiver callback runs
           Then it accepts, so wallets and marketplaces can deposit normally */
        outsideNft.mint(alice, 7);
        vm.prank(alice);
        outsideNft.safeTransferFrom(alice, address(account), 7);
        assertEq(outsideNft.ownerOf(7), address(account));
    }

    function test_assetsSurviveTheBearChangingHands() public {
        /* Scenario:
           Given a funded bear account
           When the bear is sold
           Then the contents go with it and the buyer, not the seller, can move them */
        vm.deal(address(account), 2 ether);
        mntd.mint(address(account), 500 * UNIT);

        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);

        vm.prank(alice);
        vm.expectRevert(ERC6551.Unauthorized.selector);
        account.execute(alice, 1 ether, "", 0);

        vm.prank(bob);
        account.execute(bob, 2 ether, "", 0);
        assertEq(bob.balance, 2 ether);
        assertEq(mntd.balanceOf(address(account)), 500 * UNIT);
    }

    /*                       EXECUTION                         */

    function test_execute_byNonOwner_reverts() public {
        /* Scenario:
           Given a bear account
           When someone who does not hold the bear tries to execute
           Then it is refused */
        vm.deal(address(account), 1 ether);
        vm.prank(bob);
        vm.expectRevert(ERC6551.Unauthorized.selector);
        account.execute(bob, 1 ether, "", 0);
    }

    function test_execute_byApprovedOperator_reverts() public {
        /* Scenario:
           Given an operator approved to transfer the bear
           When it tries to spend from the bear's wallet
           Then it is refused: approval to move the bear is not approval to spend its assets */
        vm.prank(alice);
        bears.setApprovalForAll(operator, true);

        vm.deal(address(account), 1 ether);
        vm.prank(operator);
        vm.expectRevert(ERC6551.Unauthorized.selector);
        account.execute(operator, 1 ether, "", 0);
    }

    function test_execute_delegatecall_reverts() public {
        /* Scenario:
           Given a bear account
           When an owner asks for a delegatecall
           Then it is refused, so there is no path to rewrite the account's own storage */
        vm.prank(alice);
        vm.expectRevert(ERC6551.OperationNotSupported.selector);
        account.execute(bob, 0, "", 1);
    }

    function test_execute_createOperations_revert() public {
        /* Scenario:
           Given a bear account
           When an owner asks for CREATE or CREATE2
           Then both are refused; only plain calls are supported */
        vm.startPrank(alice);
        vm.expectRevert(ERC6551.OperationNotSupported.selector);
        account.execute(bob, 0, "", 2);
        vm.expectRevert(ERC6551.OperationNotSupported.selector);
        account.execute(bob, 0, "", 3);
        vm.stopPrank();
    }

    function test_execute_bubblesUpRevert() public {
        /* Scenario:
           Given a call that will fail
           When it is executed
           Then the failure is surfaced rather than swallowed */
        vm.prank(alice);
        vm.expectRevert();
        account.execute(address(mntd), 0, abi.encodeWithSignature("transfer(address,uint256)", bob, 1), 0);
    }

    function test_executeBatch_movesSeveralAssetsAtOnce() public {
        /* Scenario:
           Given a funded bear account
           When its owner batches two calls
           Then both take effect, which is the portal's "empty my wallet" path */
        vm.deal(address(account), 1 ether);
        mntd.mint(address(account), 100 * UNIT);

        ERC6551.Call[] memory calls = new ERC6551.Call[](2);
        calls[0] = ERC6551.Call({target: bob, value: 1 ether, data: ""});
        calls[1] = ERC6551.Call({
            target: address(mntd), value: 0, data: abi.encodeWithSignature("transfer(address,uint256)", bob, 100 * UNIT)
        });

        vm.prank(alice);
        account.executeBatch(calls, 0);

        assertEq(bob.balance, 1 ether);
        assertEq(mntd.balanceOf(bob), 100 * UNIT);
    }

    function test_state_advancesOnEveryExecution() public {
        /* Scenario:
           Given a bear account
           When it executes anything
           Then state() changes, which is what ERC-6551 clients use to detect staleness */
        vm.deal(address(account), 2 ether);
        bytes32 before = account.state();

        vm.prank(alice);
        account.execute(bob, 1 ether, "", 0);

        assertTrue(account.state() != before, "state did not advance");
    }

    /*                     IMMUTABILITY                        */

    function test_upgrade_isRefused() public {
        /* Scenario:
           Given the account is a registry proxy pointing straight at the implementation
           When its owner tries to upgrade it
           Then it is refused — this is what makes "no admin path into user assets" true */
        BearAccount fresh = new BearAccount();
        vm.prank(alice);
        // `UnauthorizedCallContext()`. The registry's proxy hardcodes the implementation in
        // its own bytecode, and Solady refuses the upgrade whenever that address is the
        // implementation itself rather than a UUPS proxy's storage slot.
        vm.expectRevert(bytes4(0x9f03a026));
        account.upgradeToAndCall(address(fresh), "");
    }

    function test_unknownSelector_revertsButBurnsGas() public {
        /* Scenario:
           Given a call to a bear account with a selector it does not recognise
           When it falls through to Solady's LibZip calldata decompressor
           Then it reverts, but only after consuming a large share of the forwarded gas */
        uint256 before = gasleft();
        (bool ok,) = address(account).call{gas: 1_000_000}(abi.encodeWithSignature("noSuchFunction()"));
        uint256 used = before - gasleft();

        assertFalse(ok, "call should fail");
        assertGt(used, 50_000, "documents the gas burn; see BearAccount NatSpec");
    }

    function test_implementationItselfHasNoOwner() public {
        /* Scenario:
           Given the shared implementation contract, which is not bound to any bear
           When its owner is read
           Then it is nobody, so it cannot be driven directly */
        assertEq(accountImpl.owner(), address(0));
    }

    /*                        ERC-1271                         */

    function test_eip712Domain_isOurNameBoundToThisAccount() public {
        /* Scenario:
           Given a bear account
           When its EIP-712 domain is read
           Then it carries our name and version and is bound to this address and chain,
           so a signature cannot be replayed against another bear or another chain */
        (, string memory name, string memory version, uint256 chainId, address verifyingContract,,) =
            account.eip712Domain();

        assertEq(name, "MintABear");
        assertEq(version, "1");
        assertEq(chainId, block.chainid);
        assertEq(verifyingContract, address(account));
    }

    function test_eip712Domain_differsPerBear() public {
        /* Scenario:
           Given two bears
           When their accounts' domains are compared
           Then the verifying contract differs, so signatures do not cross between bears */
        _mint(alice, 1);
        BearAccount second = BearAccount(payable(bears.deployAccount(2)));

        (,,,, address first,,) = account.eip712Domain();
        (,,,, address other,,) = second.eip712Domain();
        assertTrue(first != other);
    }

    /*                         ERC-165                         */

    function test_supportsInterface_advertisesErc6551() public {
        /* Scenario:
           Given a bear account
           When its interfaces are queried
           Then ERC-165, ERC-6551 and ERC-6551 Executable are advertised */
        assertTrue(account.supportsInterface(0x01ffc9a7), "ERC165");
        assertTrue(account.supportsInterface(0x6faff5f1), "ERC6551");
        assertTrue(account.supportsInterface(0x51945447), "ERC6551Executable");
    }

    function test_supportsInterface_doesNotAdvertiseReceivers() public {
        /* Scenario:
           Given a bear account that does in fact accept ERC-721 and ERC-1155 tokens
           When the receiver interfaces are queried
           Then they read false — deposits still work, but any integration that gates on
           ERC-165 before sending will refuse. Pinned so the behaviour is a known quantity. */
        assertFalse(account.supportsInterface(0x150b7a02), "IERC721Receiver");
        assertFalse(account.supportsInterface(0x4e2312e0), "IERC1155Receiver");
    }
}
