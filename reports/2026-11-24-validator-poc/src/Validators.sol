// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// The proposal: a validator that records every transfer by incrementing a per-token nonce.
contract CountingValidator {
    mapping(uint256 => uint256) public nonce;
    function validateTransfer(address, address, address, uint256 tokenId) external {
        nonce[tokenId]++;
    }
}

/// The control: a validator that only reads, and refuses one token id.
contract ReadOnlyValidator {
    function validateTransfer(address, address, address, uint256 tokenId) external pure {
        require(tokenId != 999, "blocked");
    }
}
