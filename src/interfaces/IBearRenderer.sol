// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title  IBearRenderer
 * @notice Produces the metadata document for a bear.
 * @dev    The renderer is deliberately a separate contract from the token. Ownership,
 *         transfers and the activation counter are permanent; presentation is not. Keeping
 *         them apart means a rendering defect is fixed by deploying a new renderer and
 *         pointing the token at it, without touching any state that holders depend on.
 */
interface IBearRenderer {
    /**
     * @notice Returns the complete metadata document for a bear.
     * @param  tokenId The bear to render.
     * @return The value `tokenURI` should return: a self-contained data URI.
     */
    function render(uint256 tokenId) external view returns (string memory);
}
