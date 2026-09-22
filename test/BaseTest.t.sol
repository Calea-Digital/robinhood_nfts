// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {MintABear} from "../src/MintABear.sol";
import {Activation} from "../src/Activation.sol";
import {MockMNTD} from "./mocks/MockMNTD.sol";

/// @dev Shared fixture: the collection with one allowed SeaDrop address, a $MNTD stand-in and
///      an Activation wired to both.
abstract contract BaseTest is Test {
    MintABear internal bears;
    Activation internal activation;
    MockMNTD internal mntd;

    address internal seaDrop = makeAddr("seaDrop");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal operator = makeAddr("operator");

    uint256 internal constant MAX_SUPPLY = 4444;
    uint8 internal constant DECIMALS = 18;
    uint128 internal constant UNIT = uint128(10 ** uint256(DECIMALS));

    function setUp() public virtual {
        address[] memory allowed = new address[](1);
        allowed[0] = seaDrop;

        bears = new MintABear("MintABear", "BEAR", allowed);
        bears.setMaxSupply(MAX_SUPPLY);

        mntd = new MockMNTD(DECIMALS);

        uint128[5] memory thresholds =
            [uint128(5_000), uint128(15_000), uint128(40_000), uint128(100_000), uint128(250_000)];
        activation = new Activation(address(bears), address(mntd), thresholds);
    }

    /// @dev Mints `quantity` bears to `to` through the allowed SeaDrop address.
    function _mint(address to, uint256 quantity) internal {
        vm.prank(seaDrop);
        bears.mintSeaDrop(to, quantity);
    }

    /// @dev Funds `who` with $MNTD and approves the activation contract to burn it.
    function _fund(address who, uint256 whole) internal {
        mntd.mint(who, whole * UNIT);
        vm.prank(who);
        mntd.approve(address(activation), type(uint256).max);
    }
}
