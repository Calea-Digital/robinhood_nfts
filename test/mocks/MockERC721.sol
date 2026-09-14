// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @dev Minimal outside collection, used to prove a bear's account can hold and move NFTs
///      that are not bears. Supports both the safe and unsafe transfer paths, because only
///      the safe one triggers the account's ownership-cycle check.
contract MockERC721 {
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    error NotAuthorized();
    error UnsafeRecipient();

    function mint(address to, uint256 tokenId) external {
        ownerOf[tokenId] = to;
    }

    function approve(address spender, uint256 tokenId) external {
        if (ownerOf[tokenId] != msg.sender) revert NotAuthorized();
        getApproved[tokenId] = spender;
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (ownerOf[tokenId] != from) revert NotAuthorized();
        if (msg.sender != from && msg.sender != getApproved[tokenId] && !isApprovedForAll[from][msg.sender]) {
            revert NotAuthorized();
        }
        delete getApproved[tokenId];
        ownerOf[tokenId] = to;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
        if (to.code.length != 0) {
            bytes4 selector = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
            if (selector != IERC721Receiver.onERC721Received.selector) revert UnsafeRecipient();
        }
    }
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}
