// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest} from "./BaseTest.t.sol";
import {ERC721ContractMetadata} from "seadrop/ERC721ContractMetadata.sol";

import {TwoStepOwnable} from "utility-contracts/TwoStepOwnable.sol";
import {Enforcement} from "../script/Enforcement.s.sol";
import {MockTransferValidator} from "./mocks/MockTransferValidator.sol";

/// @dev OPS-6. The toggle run through the script, from the broadcast signer that owns the
///      collection. `MockTransferValidator` at the V3 address models the zero-state policy; the real
///      V3 is the auditor's Fork-2 (`test/MintABear.tree.md`).
contract EnforcementTest is BaseTest {
    event TransferValidatorUpdated(address oldValidator, address newValidator);

    Enforcement internal script;
    address internal v3;
    address internal foreignVenue = makeAddr("foreignSeaportVenue");

    function setUp() public override {
        super.setUp();
        script = new Enforcement();
        v3 = script.TRANSFER_VALIDATOR_V3();
        vm.etch(v3, address(new MockTransferValidator()).code);
        bears.setTransferValidator(v3);

        bears.transferOwnership(DEFAULT_SENDER);
        vm.prank(DEFAULT_SENDER);
        bears.acceptOwnership();

        _mint(alice, 3);
        vm.prank(alice);
        bears.setApprovalForAll(foreignVenue, true);
    }

    function _foreignTransfer(uint256 tokenId) internal {
        vm.prank(foreignVenue);
        bears.transferFrom(alice, bob, tokenId);
    }

    function test_enforcement_togglesByOneCall() public {
        /* Scenario: OPS-6 — Enforcement toggles by one call
           Given enforcement enabled
           When the admin calls setTransferValidator(address(0)) and then sets V3 again
           Then each call emits TransferValidatorUpdated and the policy follows the current value */
        vm.expectRevert(abi.encodeWithSelector(MockTransferValidator.OperatorNotWhitelisted.selector, foreignVenue));
        _foreignTransfer(1);

        vm.expectEmit(true, true, true, true, address(bears));
        emit TransferValidatorUpdated(v3, address(0));
        script.disable(address(bears));
        assertEq(bears.getTransferValidator(), address(0));
        _foreignTransfer(1);
        assertEq(bears.ownerOf(1), bob, "no validator: any venue settles");

        vm.expectEmit(true, true, true, true, address(bears));
        emit TransferValidatorUpdated(address(0), v3);
        script.enable(address(bears));
        assertEq(bears.getTransferValidator(), v3);
        vm.expectRevert(abi.encodeWithSelector(MockTransferValidator.OperatorNotWhitelisted.selector, foreignVenue));
        _foreignTransfer(2);
    }

    function test_toggle_refusesANoOp() public {
        /* Scenario:
           Given enforcement on
           When enable is run, and after disabling, disable again
           Then each reverts with AlreadyInState before anything is broadcast */
        vm.expectRevert(abi.encodeWithSelector(Enforcement.AlreadyInState.selector, v3));
        script.enable(address(bears));
        script.disable(address(bears));
        vm.expectRevert(abi.encodeWithSelector(Enforcement.AlreadyInState.selector, address(0)));
        script.disable(address(bears));
    }

    function test_enable_restoresV3_overAnotherValidator() public {
        /* Scenario:
           Given the collection holding a validator other than V3
           When status is read and enable is run
           Then status reports it enforced through that validator, and enable replaces it with V3,
             emitting TransferValidatorUpdated(other, V3) */
        address other = address(new MockTransferValidator());
        vm.prank(DEFAULT_SENDER);
        bears.setTransferValidator(other);
        (bool enforced, address validator) = script.status(address(bears));
        assertTrue(enforced);
        assertEq(validator, other);

        vm.expectEmit(true, true, true, true, address(bears));
        emit TransferValidatorUpdated(other, v3);
        script.enable(address(bears));
        assertEq(bears.getTransferValidator(), v3);
    }

    function test_toggle_byANonOwnerSigner_reverts() public {
        /* Scenario:
           Given the collection owned by MINT's admin, not the broadcast signer
           When disable is run
           Then the owner-only call reverts: only the admin toggles enforcement */
        vm.prank(DEFAULT_SENDER);
        bears.transferOwnership(makeAddr("mintAdmin"));
        vm.prank(makeAddr("mintAdmin"));
        bears.acceptOwnership();
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        script.disable(address(bears));
        assertEq(bears.getTransferValidator(), v3);
    }

    function test_status_readsTheCurrentValue() public {
        /* Scenario:
           Given enforcement on, then off
           When status is read
           Then it reports (true, V3), then (false, 0) */
        (bool enforced, address validator) = script.status(address(bears));
        assertTrue(enforced);
        assertEq(validator, v3);
        script.disable(address(bears));
        (enforced, validator) = script.status(address(bears));
        assertFalse(enforced);
        assertEq(validator, address(0));
    }

    function test_safeTransaction_isTheOwnerCall() public view {
        /* Scenario:
           Given a Safe admin
           When the lift and restore transactions are printed
           Then each targets the collection with no value and setTransferValidator's calldata */
        (address to, uint256 value, bytes memory data) = script.safeTransaction(address(bears), false);
        assertEq(to, address(bears));
        assertEq(value, 0);
        assertEq(data, abi.encodeCall(ERC721ContractMetadata.setTransferValidator, (address(0))));
        (,, data) = script.safeTransaction(address(bears), true);
        assertEq(data, abi.encodeCall(ERC721ContractMetadata.setTransferValidator, (v3)));
    }
}
