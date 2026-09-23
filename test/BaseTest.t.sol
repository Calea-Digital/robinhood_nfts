// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {MintABear} from "../src/MintABear.sol";
import {Activation} from "../src/Activation.sol";

/// @dev Shared fixture: the collection with one allowed SeaDrop address, and an Activation that
///      reads it, with the specified thresholds (18-decimal base units) and weights and a
///      stand-in crediter address.
abstract contract BaseTest is Test {
    MintABear internal bears;
    Activation internal activation;

    address internal seaDrop = makeAddr("seaDrop");
    address internal crediter = makeAddr("crediter");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal operator = makeAddr("operator");

    uint256 internal constant MAX_SUPPLY = 4444;
    uint128 internal constant UNIT = 1e18;

    /// @dev Crediter references handed out by `_credit`, one per call.
    uint256 internal refCounter;

    function setUp() public virtual {
        address[] memory allowed = new address[](1);
        allowed[0] = seaDrop;

        bears = new MintABear("MintABear", "BEAR", allowed);
        bears.setMaxSupply(MAX_SUPPLY);

        activation = new Activation(address(bears), _thresholds(), _weights());
        activation.setCrediter(crediter);
    }

    /// @dev The specified thresholds, 1,666 / 3,333 / 8,333 / 16,666 / 41,666 whole $MNTD (ACT-2).
    function _thresholds() internal pure returns (uint128[5] memory) {
        return [uint128(1_666) * UNIT, 3_333 * UNIT, 8_333 * UNIT, 16_666 * UNIT, 41_666 * UNIT];
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

    /// @dev The crediter records `whole` $MNTD burned by the bear's owner, at its current counter.
    function _credit(uint256 tokenId, uint128 whole) internal returns (bytes32 ref) {
        ref = bytes32(++refCounter);
        address burner = bears.ownerOf(tokenId);
        uint64 nonce = bears.transferNonce(tokenId);
        vm.prank(crediter);
        activation.credit(tokenId, burner, whole * UNIT, nonce, ref);
    }
}
