// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IBearRenderer} from "../../src/interfaces/IBearRenderer.sol";

/// @dev Returns an identifiable string so delegation can be asserted without parsing JSON.
contract MockRenderer is IBearRenderer {
    string public tag;

    constructor(string memory tag_) {
        tag = tag_;
    }

    function render(uint256) external view returns (string memory) {
        return tag;
    }
}
