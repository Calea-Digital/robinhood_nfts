// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IBearRenderer} from "../interfaces/IBearRenderer.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/**
 * @title  PlaceholderRenderer
 * @notice Pre-reveal metadata: every bear shares one image and carries no traits.
 * @dev    Ships at launch so the collection does not wait on artwork. The real renderer
 *         replaces it at reveal; the token's `setRenderer` is the only thing that changes.
 *         The returned document has the same shape as the final one, so marketplaces that
 *         cache the pre-reveal response refresh into the real thing without surprises.
 *
 *         Every owner-supplied string is escaped on the way into the document. Without that,
 *         a single double quote in the description produces invalid JSON for all 4,444
 *         tokens at once, and a carefully shaped one closes the field early and writes
 *         another. Escaping at render rather than rejecting at write keeps apostrophes,
 *         quotes and punctuation available to whoever writes the copy.
 */
contract PlaceholderRenderer is IBearRenderer, Ownable {
    string private _description;
    string private _externalUrl;
    string private _image;

    /// @notice Emitted when any of the collection-level strings change.
    event MetadataStringsUpdated();

    constructor(string memory description_, string memory externalUrl_, string memory image_) {
        _initializeOwner(msg.sender);
        _description = description_;
        _externalUrl = externalUrl_;
        _image = image_;
    }

    /// @inheritdoc IBearRenderer
    function render(uint256 tokenId) external view returns (string memory) {
        bytes memory json = abi.encodePacked(
            '{"name":"MINT Bear #',
            LibString.toString(tokenId),
            '","description":"',
            LibString.escapeJSON(_description),
            '","external_url":"',
            LibString.escapeJSON(_externalUrl),
            '","image":"',
            LibString.escapeJSON(_image),
            '","attributes":[]}'
        );
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(json)));
    }

    /**
     * @notice Updates the collection-level strings.
     * @dev    These are owner-settable rather than fixed because the renderer is replaceable
     *         in any case — declaring them immutable would claim a guarantee this design does
     *         not actually provide. Any content is accepted; `render` escapes it.
     */
    function setStrings(string calldata description_, string calldata externalUrl_, string calldata image_)
        external
        onlyOwner
    {
        _description = description_;
        _externalUrl = externalUrl_;
        _image = image_;
        emit MetadataStringsUpdated();
    }

    /// @notice The collection description embedded in every token's metadata.
    function description() external view returns (string memory) {
        return _description;
    }

    /// @notice The link embedded in every token's metadata.
    function externalUrl() external view returns (string memory) {
        return _externalUrl;
    }

    /// @notice The pre-reveal image, as a URI.
    function image() external view returns (string memory) {
        return _image;
    }
}
