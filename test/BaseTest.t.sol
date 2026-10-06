// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {MintABear} from "../src/MintABear.sol";
import {Activation} from "../src/Activation.sol";
import {MockMNTD} from "./mocks/MockMNTD.sol";

/// @dev Shared fixture: the collection with one allowed SeaDrop address, an 18-decimal $MNTD
///      stand-in, and an Activation over both with the specified thresholds and weights.
abstract contract BaseTest is Test {
    MintABear internal bears;
    Activation internal activation;
    MockMNTD internal mntd;

    address internal seaDrop = makeAddr("seaDrop");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal operator = makeAddr("operator");

    uint256 internal constant MAX_SUPPLY = 4444;
    uint128 internal constant UNIT = 1e18;

    function setUp() public virtual {
        address[] memory allowed = new address[](1);
        allowed[0] = seaDrop;

        bears = new MintABear("MintABear", "BEAR", allowed);
        bears.setMaxSupply(MAX_SUPPLY);

        mntd = new MockMNTD(18);
        activation = new Activation(address(this), address(bears), address(mntd), _thresholds(), _weights());
        // Activation is constructed paused (ACT-15); the suites start from the switch-on state.
        activation.setPaused(false);
    }

    /// @dev The specified thresholds, 1,666 / 3,333 / 8,333 / 16,666 / 41,666 whole $MNTD (ACT-2).
    function _thresholds() internal pure returns (uint128[5] memory) {
        return [uint128(1_666), 3_333, 8_333, 16_666, 41_666];
    }

    /// @dev The specified weights, 100 / 110 / 125 / 145 / 170 / 200 (ACT-3).
    function _weights() internal pure returns (uint16[6] memory) {
        return [uint16(100), 110, 125, 145, 170, 200];
    }

    /// @dev Mints `quantity` bears to `to` through the allowed SeaDrop address.
    function _mint(address to, uint256 quantity) internal {
        vm.prank(seaDrop);
        bears.mintSeaDrop(to, quantity);
    }

    /// @dev Gives `holder` `whole` $MNTD and approves `Activation` for it.
    function _fund(address holder, uint128 whole) internal {
        mntd.mint(holder, uint256(whole) * UNIT);
        vm.prank(holder);
        mntd.approve(address(activation), type(uint256).max);
    }

    /// @dev The bear's owner burns `whole` $MNTD for it, funded and approved first.
    function _burnFor(uint256 tokenId, uint128 whole) internal {
        address holder = bears.ownerOf(tokenId);
        _fund(holder, whole);
        vm.prank(holder);
        activation.burn(tokenId, whole * UNIT);
    }
}
