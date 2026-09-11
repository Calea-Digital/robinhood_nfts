// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {LibERC6551} from "solady/accounts/LibERC6551.sol";

import {MintABear} from "../src/MintABear.sol";
import {BearAccount} from "../src/BearAccount.sol";
import {Activation} from "../src/Activation.sol";
import {PlaceholderRenderer} from "../src/renderers/PlaceholderRenderer.sol";
import {MockMNTD} from "./mocks/MockMNTD.sol";

/// @dev Shared fixture. The canonical ERC-6551 registry is etched in rather than mocked, so
///      the account addresses exercised here are the ones the collection will really use.
abstract contract BaseTest is Test {
    MintABear internal bears;
    BearAccount internal accountImpl;
    PlaceholderRenderer internal renderer;
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
        vm.etch(LibERC6551.REGISTRY, LibERC6551.REGISTRY_BYTECODE);

        address[] memory allowed = new address[](1);
        allowed[0] = seaDrop;

        accountImpl = new BearAccount();
        renderer = new PlaceholderRenderer("A bear.", "https://mint.io", "ipfs://placeholder");
        bears = new MintABear("MintABear", "BEAR", allowed, address(accountImpl), address(renderer));
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
