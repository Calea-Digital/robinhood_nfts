// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LibERC6551} from "solady/accounts/LibERC6551.sol";
import {IERC721A} from "ERC721A/IERC721A.sol";
import {TwoStepOwnable} from "utility-contracts/TwoStepOwnable.sol";

import {BaseTest} from "./BaseTest.t.sol";
import {MintABear} from "../src/MintABear.sol";

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

    function test_transferValidator_defaultsToUnset() public view {
        /* Scenario:
           Given a freshly deployed collection
           When the transfer validator is read
           Then it is unset, so transfers are free and cost no extra gas */
        assertEq(bears.getTransferValidator(), address(0));
    }
}

contract MintABearBranchTest is BaseTest {
    function test_transfer_toOrdinaryAddress_succeeds() public {
        /* Scenario:
           Given a bear and an ordinary destination
           When it is transferred
           Then it succeeds */
        _mint(alice, 1);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertEq(bears.ownerOf(1), bob);
    }
}

/// @dev COL-5. Metadata is SeaDrop's stock shape: `baseURI` set through Studio, `tokenURI(id)`
///      is `baseURI` followed by `id`, and nothing about a bear's level reaches it.
contract MintABearMetadataTest is BaseTest {
    function test_tokenURI_isBaseURIPlusId() public {
        /* Scenario: COL-5 — Metadata is base URI plus id
           Given baseURI set through Studio
           When tokenURI(id) is read
           Then it returns baseURI followed by id
           And raising the bear's level changes nothing in it */
        _mint(alice, 2);
        bears.setBaseURI("ipfs://bears/");
        assertEq(bears.tokenURI(1), "ipfs://bears/1");
        assertEq(bears.tokenURI(2), "ipfs://bears/2");

        _fund(alice, 5_000);
        vm.prank(alice);
        activation.burn(1, 5_000 * UNIT);
        assertEq(activation.levelOf(1), 1, "level rose");

        assertEq(bears.tokenURI(1), "ipfs://bears/1", "metadata does not vary with level");
    }

    function test_tokenURI_withoutTrailingSlash_isTheBaseURIAlone() public {
        /* Scenario:
           Given a baseURI that does not end in a slash, SeaDrop's pre-reveal shape
           When tokenURI is read for any bear
           Then it returns the baseURI itself, without the id */
        _mint(alice, 2);
        bears.setBaseURI("ipfs://unrevealed");
        assertEq(bears.tokenURI(1), "ipfs://unrevealed");
        assertEq(bears.tokenURI(2), "ipfs://unrevealed");
    }

    function test_tokenURI_withEmptyBaseURI_isEmpty() public {
        /* Scenario:
           Given no baseURI has been set
           When tokenURI is read
           Then it returns the empty string rather than reverting */
        _mint(alice, 1);
        assertEq(bears.tokenURI(1), "");
    }

    function test_tokenURI_nonexistent_reverts() public {
        /* Scenario:
           Given a bear that was never minted
           When its tokenURI is read
           Then it reverts with URIQueryForNonexistentToken */
        bears.setBaseURI("ipfs://bears/");
        vm.expectRevert(IERC721A.URIQueryForNonexistentToken.selector);
        bears.tokenURI(1);
    }

    function test_setBaseURI_byNonOwner_reverts() public {
        /* Scenario:
           Given a wallet that does not own the contract
           When it tries to set the baseURI
           Then the call is refused with OnlyOwner */
        vm.prank(alice);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        bears.setBaseURI("ipfs://hijack/");
    }
}

/// @dev COL-9. ERC-6551 is not part of the collection: no account code, no account guard, no
///      registry call. The canonical registry can derive an account for any ERC-721 later
///      without a change here.
contract MintABearNoAccountsTest is BaseTest {
    /// @dev The canonical ERC-6551 registry, lower-case hex without the prefix, as
    ///      `vm.toString(bytes)` renders bytecode.
    string internal constant REGISTRY_HEX = "000000006551c19487814612e58fe06813775758";

    function test_noTokenBoundAccountCode() public {
        /* Scenario: COL-9 — No token-bound account code
           When the deployed MintABear is inspected
           Then it holds no ERC-6551 account code, no account guard and no registry call */
        _assertNoEntryPoint("accountOf(uint256)", abi.encode(uint256(1)));
        _assertNoEntryPoint("deployAccount(uint256)", abi.encode(uint256(1)));
        _assertNoEntryPoint("recordAccounts(uint256,uint256)", abi.encode(uint256(1), uint256(2)));
        _assertNoEntryPoint("isBearAccount(address)", abi.encode(alice));
        _assertNoEntryPoint("ACCOUNT_IMPLEMENTATION()", "");
        _assertNoEntryPoint("ACCOUNT_SALT()", "");

        string memory code = vm.toString(address(bears).code);
        assertFalse(vm.contains(code, REGISTRY_HEX), "registry address in bytecode");
    }

    function test_noAccountGuard_derivedAddressIsAnOrdinaryDestination() public {
        /* Scenario: COL-9 — No token-bound account code
           When a bear is sent to the address the canonical registry would derive for a bear
           Then the transfer passes, because there is no account guard to refuse it */
        _mint(alice, 2);
        address derived = LibERC6551.account(makeAddr("implementation"), bytes32(0), block.chainid, address(bears), 2);
        assertEq(derived.code.length, 0, "nothing deployed there");

        vm.prank(alice);
        bears.transferFrom(alice, derived, 1);
        assertEq(bears.ownerOf(1), derived);
        assertEq(bears.transferNonce(1), 1);
    }

    /// @dev An unknown selector on ERC721A reverts with empty return data: there is no
    ///      fallback, so the entry point is simply not there.
    function _assertNoEntryPoint(string memory signature, bytes memory args) internal {
        (bool ok, bytes memory ret) = address(bears).call(abi.encodePacked(bytes4(keccak256(bytes(signature))), args));
        assertFalse(ok, signature);
        assertEq(ret.length, 0, signature);
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
}

/// @dev `maxSupply` is an owner setting on the SeaDrop base, raisable at any time and by
///      OpenSea Studio through `multiConfigure`. `MAX_BEARS` is the constant that makes the
///      stated 4,444 true regardless of how it is configured.
contract MintABearSupplyCapTest is BaseTest {
    function test_maxBears_isTheStatedSupply() public view {
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
