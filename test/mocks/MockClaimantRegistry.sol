// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {WhitelistClaim} from "../../src/WhitelistClaim.sol";

/// @dev Answers the reads `WhitelistExport.checkedRows` makes with whatever rows and counts a test
///      sets, so the script's own checks can be shown to refuse an inconsistent list.
contract MockClaimantRegistry {
    uint16 public constant TOTAL_SPOTS = 1000;

    WhitelistClaim.Claimant[] internal _rows;
    mapping(address => uint8) public claimsOf;
    uint256 public spotsLeft = TOTAL_SPOTS;

    function push(address wallet, uint8 rowAllocations, uint8 counted) external {
        _rows.push(WhitelistClaim.Claimant({wallet: wallet, allocations: rowAllocations}));
        claimsOf[wallet] = counted;
    }

    function setSpotsLeft(uint256 left) external {
        spotsLeft = left;
    }

    function claimants(uint256 offset, uint256 limit) external view returns (WhitelistClaim.Claimant[] memory rows) {
        uint256 total = _rows.length;
        uint256 end = offset >= total ? offset : (limit > total - offset ? total : offset + limit);
        rows = new WhitelistClaim.Claimant[](end - offset);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = _rows[offset + i];
        }
    }
}
