// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721Receiver} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";

import {Activation} from "../../src/Activation.sol";
import {HookedMNTD, IBurnHook} from "./HookedMNTD.sol";

/// @dev A bear holder that, when its $MNTD is burned, calls `burn` again once from inside the
///      token's `burnFrom` — the nested call a hooked token makes possible.
contract ReentrantHolder is IBurnHook, IERC721Receiver {
    Activation internal immutable activation;
    uint256 internal tokenId;
    uint128 internal nestedAmount;
    bool internal armed;

    constructor(Activation activation_, HookedMNTD mntd_) {
        activation = activation_;
        mntd_.approve(address(activation_), type(uint256).max);
    }

    function burnTwice(uint256 tokenId_, uint128 outer, uint128 nested) external {
        (tokenId, nestedAmount, armed) = (tokenId_, nested, true);
        activation.burn(tokenId_, outer);
    }

    function burnOnce(uint256 tokenId_, uint128 amount) external {
        activation.burn(tokenId_, amount);
    }

    function onBurn() external {
        if (!armed) return;
        armed = false;
        activation.burn(tokenId, nestedAmount);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
