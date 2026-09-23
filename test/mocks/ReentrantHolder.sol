// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721Receiver} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";

import {DirectBurnAdapter} from "../../src/DirectBurnAdapter.sol";
import {HookedMNTD, IBurnHook} from "./HookedMNTD.sol";

/// @dev A bear holder that, when its $MNTD is burned, calls `burn` again once from inside the
///      token's `burnFrom` — the nested call a hooked token makes possible.
contract ReentrantHolder is IBurnHook, IERC721Receiver {
    DirectBurnAdapter internal immutable adapter;
    uint256 internal tokenId;
    uint128 internal nestedAmount;
    bool internal armed;

    constructor(DirectBurnAdapter adapter_, HookedMNTD mntd_) {
        adapter = adapter_;
        mntd_.approve(address(adapter_), type(uint256).max);
    }

    function burnTwice(uint256 tokenId_, uint128 outer, uint128 nested) external {
        (tokenId, nestedAmount, armed) = (tokenId_, nested, true);
        adapter.burn(tokenId_, outer);
    }

    function onBurn() external {
        if (!armed) return;
        armed = false;
        adapter.burn(tokenId, nestedAmount);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
