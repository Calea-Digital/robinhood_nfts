// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {CountingValidator, ReadOnlyValidator} from "../src/Validators.sol";

interface IStudioClone {
    function setTransferValidator(address) external;
    function getTransferValidator() external view returns (address);
    function mintSeaDrop(address to, uint256 quantity) external;
    function totalSupply() external view returns (uint256);
    function ownerOf(uint256) external view returns (address);
    function transferFrom(address, address, uint256) external;
    function safeTransferFrom(address, address, uint256) external;
    function setApprovalForAll(address, bool) external;
}

/// Fork of Robinhood Chain mainnet: MINT's Studio collection 0x96ba…4dD1 as deployed.
contract ValidatorPoC is Test {
    IStudioClone constant BEARS = IStudioClone(0x96ba687Ad4F1F5213E676cEb7556c48F02ab4dD1);
    address constant ADMIN = 0x153052B43c8fD4ec01f14D1Edd8660778daa6141;
    address constant SEADROP = 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5;
    address constant A = address(0xA11c);
    address constant B = address(0xB0b0);
    address constant OPERATOR = address(0x0FE4);

    function setUp() public {
        vm.createSelectFork("https://rpc.mainnet.chain.robinhood.com");
        vm.prank(SEADROP);
        BEARS.mintSeaDrop(A, 3);
    }

    function _first() internal view returns (uint256) {
        return BEARS.totalSupply() - 2;
    }

    /// The proposal: a validator that writes a nonce on each transfer. Every transfer reverts.
    function test_countingValidator_everyTransferReverts() public {
        CountingValidator v = new CountingValidator();
        vm.prank(ADMIN);
        BEARS.setTransferValidator(address(v));
        uint256 id = _first();

        vm.prank(A);
        vm.expectRevert();
        BEARS.transferFrom(A, B, id);

        assertEq(BEARS.ownerOf(id), A, "bear did not move");
        assertEq(v.nonce(id), 0, "nothing was recorded");
    }

    /// Control: a validator that only reads runs on every route, and can refuse.
    function test_readOnlyValidator_runsOnEveryRoute() public {
        ReadOnlyValidator v = new ReadOnlyValidator();
        vm.prank(ADMIN);
        BEARS.setTransferValidator(address(v));
        uint256 id = _first();

        vm.prank(A);
        BEARS.transferFrom(A, B, id); // owner, transferFrom
        vm.prank(B);
        BEARS.safeTransferFrom(B, A, id); // owner, safeTransferFrom
        vm.prank(A);
        BEARS.setApprovalForAll(OPERATOR, true);
        vm.prank(OPERATOR);
        BEARS.transferFrom(A, B, id); // operator (a marketplace conduit)
        assertEq(BEARS.ownerOf(id), B);
    }
}
