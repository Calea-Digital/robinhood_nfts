// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LibERC6551} from "solady/accounts/LibERC6551.sol";
import {IERC721A} from "ERC721A/IERC721A.sol";
import {TwoStepOwnable} from "utility-contracts/TwoStepOwnable.sol";
import {ERC721TransferValidator} from "seadrop/lib/ERC721TransferValidator.sol";

import {Vm} from "forge-std/Vm.sol";

import {BaseTest} from "./BaseTest.t.sol";
import {MintABear} from "../src/MintABear.sol";
import {MockTransferValidator} from "./mocks/MockTransferValidator.sol";

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

/// @dev COL-12. Every listed read answers for a minted bear; `exists` is the one read that is
///      safe on any id.
contract MintABearReadsTest is BaseTest {
    function test_everyReadAnswers() public {
        /* Scenario: COL-12 — Every read answers
           When ownerOf, exists, totalSupply, maxSupply, MAX_BEARS, transferNonce, tokenURI,
             royaltyInfo, getTransferValidator and getMintStats are called for a minted bear
           Then each returns without reverting
           And exists(id) is false for an unminted id */
        _mint(alice, 1);
        bears.setBaseURI("ipfs://bears/");
        MintABear.RoyaltyInfo memory info;
        info.royaltyAddress = bob;
        info.royaltyBps = 500;
        bears.setRoyaltyInfo(info);

        assertEq(bears.ownerOf(1), alice);
        assertTrue(bears.exists(1));
        assertEq(bears.totalSupply(), 1);
        assertEq(bears.maxSupply(), MAX_SUPPLY);
        assertEq(bears.MAX_BEARS(), 4444);
        assertEq(bears.transferNonce(1), 0);
        assertEq(bears.tokenURI(1), "ipfs://bears/1");
        (address receiver, uint256 amount) = bears.royaltyInfo(1, 1 ether);
        assertEq(receiver, bob);
        assertEq(amount, 0.05 ether);
        assertEq(bears.getTransferValidator(), address(0));
        (uint256 minted, uint256 supply, uint256 cap) = bears.getMintStats(alice);
        assertEq(minted, 1);
        assertEq(supply, 1);
        assertEq(cap, MAX_SUPPLY);

        assertFalse(bears.exists(2), "unminted id");
    }

    function test_exists_isFalseOutsideTheMintedRange() public {
        /* Scenario: COL-12 — Every read answers
           Given three bears minted
           When exists is read for id 0, the minted ids, the next id and ids far beyond
           Then it is true for the minted ids and false everywhere else, never reverting */
        _mint(alice, 3);
        assertFalse(bears.exists(0));
        assertTrue(bears.exists(1));
        assertTrue(bears.exists(3));
        assertFalse(bears.exists(4));
        assertFalse(bears.exists(MAX_SUPPLY));
        assertFalse(bears.exists(type(uint256).max));
    }

    function test_exists_followsMintingNotOwnership() public {
        /* Scenario: COL-12 — Every read answers
           Given a minted bear
           When it changes hands
           Then exists stays true, because it answers whether the bear was minted */
        _mint(alice, 1);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertTrue(bears.exists(1));
        assertEq(bears.ownerOf(1), bob);
    }
}

/// @dev COL-4. `TransferNonceAdvanced(tokenId, nonce)` is the activation-reset event: it fires
///      for every non-mint transfer, in the same transaction as `Transfer`, whether or not a
///      level existed.
contract MintABearResetEventTest is BaseTest {
    /// @dev Mirrors `MintABear.TransferNonceAdvanced` and ERC721A's `Transfer`; solc 0.8.17
    ///      cannot qualify an event by contract name in an `emit`, which `expectEmit` needs.
    event TransferNonceAdvanced(uint256 indexed tokenId, uint64 nonce);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function test_transfer_emitsTheResetEvent_withoutALevel() public {
        /* Scenario: COL-4 — The reset event fires on every non-mint transfer
           When a bear is transferred, whether or not it has a level
           Then TransferNonceAdvanced(tokenId, nonce) is emitted in the same transaction as Transfer */
        _mint(alice, 1);

        vm.expectEmit(true, false, false, true, address(bears));
        emit TransferNonceAdvanced(1, 1);
        vm.expectEmit(true, true, true, false, address(bears));
        emit Transfer(alice, bob, 1);

        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertEq(bears.transferNonce(1), 1, "the event carries the counter after the transfer");
    }

    function test_transfer_emitsTheResetEvent_withALevel() public {
        /* Scenario: COL-4 — The reset event fires on every non-mint transfer
           Given a bear that has a level
           When it is transferred
           Then TransferNonceAdvanced fires in the same transaction as Transfer
           And what Activation recorded at the previous counter value is void */
        _mint(alice, 1);
        _fund(alice, 5_000);
        vm.prank(alice);
        activation.burn(1, 5_000 * UNIT);
        assertEq(activation.levelOf(1), 1, "level before");

        vm.expectEmit(true, false, false, true, address(bears));
        emit TransferNonceAdvanced(1, 1);
        vm.expectEmit(true, true, true, false, address(bears));
        emit Transfer(alice, bob, 1);

        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertEq(activation.levelOf(1), 0, "void after the reset event");
    }

    function test_everyTransfer_emitsTheNextNonce() public {
        /* Scenario: COL-4 — The reset event fires on every non-mint transfer
           Given a bear that has already moved once
           When it moves back to a previous owner, and then by an operator
           Then each transfer emits the event with the next counter value */
        _mint(alice, 1);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);

        vm.expectEmit(true, false, false, true, address(bears));
        emit TransferNonceAdvanced(1, 2);
        vm.prank(bob);
        bears.transferFrom(bob, alice, 1);

        vm.prank(alice);
        bears.setApprovalForAll(operator, true);
        vm.expectEmit(true, false, false, true, address(bears));
        emit TransferNonceAdvanced(1, 3);
        vm.prank(operator);
        bears.safeTransferFrom(alice, bob, 1);
    }

    function test_mint_emitsNoResetEvent() public {
        /* Scenario: COL-4 — The reset event fires on every non-mint transfer
           When bears are minted
           Then no TransferNonceAdvanced is emitted, because a mint is not a transfer */
        vm.recordLogs();
        _mint(alice, 3);

        bytes32 topic = keccak256("TransferNonceAdvanced(uint256,uint64)");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            assertTrue(logs[i].topics[0] != topic, "reset event on mint");
        }
        assertEq(logs.length, 3, "three Transfer events and nothing else");
    }
}

/// @dev COL-13. The events and their arguments: ERC721A's `Transfer`, `Approval` and
///      `ApprovalForAll`, SeaDrop's `TransferValidatorUpdated`, and `TransferNonceAdvanced`.
contract MintABearEventsTest is BaseTest {
    /// @dev Local mirrors, because solc 0.8.17 cannot qualify an event by contract in `emit`.
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event TransferNonceAdvanced(uint256 indexed tokenId, uint64 nonce);
    event TransferValidatorUpdated(address oldValidator, address newValidator);

    MockTransferValidator internal validator;

    function setUp() public override {
        super.setUp();
        validator = new MockTransferValidator();
    }

    function test_events_carryTheDocumentedArguments() public {
        /* Scenario: COL-13 — Events carry the documented arguments
           When a bear is transferred and the validator is changed
           Then Transfer, TransferNonceAdvanced and TransferValidatorUpdated are emitted with the
             documented arguments */
        _mint(alice, 1);

        vm.expectEmit(false, false, false, true, address(bears));
        emit TransferValidatorUpdated(address(0), address(validator));
        bears.setTransferValidator(address(validator));

        vm.expectEmit(true, false, false, true, address(bears));
        emit TransferNonceAdvanced(1, 1);
        vm.expectEmit(true, true, true, false, address(bears));
        emit Transfer(alice, bob, 1);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);

        vm.expectEmit(false, false, false, true, address(bears));
        emit TransferValidatorUpdated(address(validator), address(0));
        bears.setTransferValidator(address(0));
    }

    function test_approvalEvents_carryTheDocumentedArguments() public {
        /* Scenario: COL-13 — Events carry the documented arguments
           When a holder approves one address for a bear and an operator for all
           Then Approval(owner, approved, tokenId) and ApprovalForAll(owner, operator, approved) are emitted */
        _mint(alice, 1);

        vm.expectEmit(true, true, true, false, address(bears));
        emit Approval(alice, bob, 1);
        vm.prank(alice);
        bears.approve(bob, 1);

        vm.expectEmit(true, true, false, true, address(bears));
        emit ApprovalForAll(alice, operator, true);
        vm.prank(alice);
        bears.setApprovalForAll(operator, true);
    }

    function test_setTransferValidator_toTheSameValue_reverts() public {
        /* Scenario:
           Given the validator already at a value
           When the owner sets it to that same value
           Then it reverts with SameTransferValidator and no event is emitted */
        vm.expectRevert(ERC721TransferValidator.SameTransferValidator.selector);
        bears.setTransferValidator(address(0));

        bears.setTransferValidator(address(validator));
        vm.expectRevert(ERC721TransferValidator.SameTransferValidator.selector);
        bears.setTransferValidator(address(validator));
    }
}

/// @dev COL-8. No bear can be destroyed. `ERC721SeaDrop` exposes a public, non-virtual `burn`
///      that cannot be overridden, so it is refused in the transfer hook; a transfer to the
///      zero address is refused in `transferFrom` with the same error. A bear sent to an
///      address nobody controls stays in the supply.
contract MintABearBurnGuardTest is BaseTest {
    address internal constant DEAD = 0x000000000000000000000000000000000000dEaD;

    function test_burn_byOwner_reverts() public {
        /* Scenario: COL-8 — No bear can be destroyed
           When anyone, the owner included, calls burn or transfers a bear to the zero address
           Then it reverts with BurnDisabled
           And totalSupply is unchanged */
        _mint(alice, 1);
        vm.prank(alice);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.burn(1);
        assertEq(bears.totalSupply(), 1);
    }

    function test_burn_byApprovedOperator_reverts() public {
        /* Scenario: COL-8 — No bear can be destroyed
           Given alice approved an operator for all her bears
           When the operator calls burn
           Then it reverts with BurnDisabled, so an approval cannot destroy a holder's bear */
        _mint(alice, 1);
        vm.prank(alice);
        bears.setApprovalForAll(operator, true);

        vm.prank(operator);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.burn(1);
        assertEq(bears.totalSupply(), 1);
    }

    function test_burn_byStranger_reverts() public {
        /* Scenario: COL-8 — No bear can be destroyed
           When a wallet with no approval calls burn on someone else's bear
           Then ERC721A's approval check refuses it before the hook is reached
           And totalSupply is unchanged */
        _mint(alice, 1);
        vm.prank(bob);
        vm.expectRevert(IERC721A.TransferCallerNotOwnerNorApproved.selector);
        bears.burn(1);
        assertEq(bears.totalSupply(), 1);
    }

    function test_burn_leavesSupplyAndOwnershipIntact() public {
        /* Scenario: COL-8 — No bear can be destroyed
           Given a bear that someone has tried to burn
           When supply, ownership and the counter are read
           Then nothing moved, so the id can never be orphaned */
        _mint(alice, 1);
        vm.prank(alice);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.burn(1);

        assertEq(bears.totalSupply(), 1, "supply unchanged");
        assertEq(bears.ownerOf(1), alice, "owner unchanged");
        assertEq(bears.transferNonce(1), 0, "counter unchanged");
    }

    function test_transferToZeroAddress_reverts() public {
        /* Scenario: COL-8 — No bear can be destroyed
           When the owner transfers a bear to the zero address
           Then it reverts with BurnDisabled
           And totalSupply is unchanged */
        _mint(alice, 1);
        vm.prank(alice);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.transferFrom(alice, address(0), 1);

        assertEq(bears.totalSupply(), 1, "supply unchanged");
        assertEq(bears.ownerOf(1), alice, "owner unchanged");
        assertEq(bears.transferNonce(1), 0, "counter unchanged");
    }

    function test_safeTransferToZeroAddress_reverts() public {
        /* Scenario: COL-8 — No bear can be destroyed
           When an approved operator safe-transfers a bear to the zero address
           Then it reverts with BurnDisabled, because safeTransferFrom routes through transferFrom
           And totalSupply is unchanged */
        _mint(alice, 1);
        vm.prank(alice);
        bears.setApprovalForAll(operator, true);

        vm.prank(operator);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.safeTransferFrom(alice, address(0), 1);

        vm.prank(operator);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.safeTransferFrom(alice, address(0), 1, "");

        assertEq(bears.totalSupply(), 1, "supply unchanged");
    }

    function test_transferToDeadAddress_keepsTheBearInSupply() public {
        /* Scenario: COL-8 — No bear can be destroyed
           Given the canonical dead address, which nobody controls
           When a bear is sent there
           Then it is an ordinary transfer: the bear stays in the supply and the counter advances */
        _mint(alice, 1);
        vm.prank(alice);
        bears.transferFrom(alice, DEAD, 1);

        assertEq(bears.ownerOf(1), DEAD);
        assertEq(bears.totalSupply(), 1, "still in the supply");
        assertEq(bears.transferNonce(1), 1);
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
