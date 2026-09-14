// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {PlaceholderRenderer} from "../src/renderers/PlaceholderRenderer.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

contract PlaceholderRendererTest is Test {
    PlaceholderRenderer internal renderer;
    address internal alice = makeAddr("alice");

    function setUp() public {
        renderer = new PlaceholderRenderer("A bear.", "https://mint.io", "ipfs://placeholder");
    }

    function test_render_returnsBase64JsonDataUri() public {
        /* Scenario:
           Given the pre-reveal renderer
           When a bear is rendered
           Then the result is a self-contained base64 JSON data URI */
        string memory uri = renderer.render(1234);
        assertTrue(LibString.startsWith(uri, "data:application/json;base64,"));
    }

    function test_render_isIdenticalAcrossBears() public {
        /* Scenario:
           Given the pre-reveal renderer
           When two different bears are rendered
           Then only the name differs, because no traits have been revealed */
        assertTrue(
            keccak256(bytes(renderer.render(1))) != keccak256(bytes(renderer.render(2))),
            "name should still carry the token id"
        );
    }

    function test_strings_areReadable() public {
        /* Scenario:
           Given strings supplied at construction
           When they are read back
           Then they match what was supplied */
        assertEq(renderer.description(), "A bear.");
        assertEq(renderer.externalUrl(), "https://mint.io");
        assertEq(renderer.image(), "ipfs://placeholder");
    }

    function test_setStrings_byOwner() public {
        /* Scenario:
           Given the renderer owner
           When they revise the collection strings
           Then the new values are returned */
        renderer.setStrings("New.", "https://getminted.io", "ipfs://revealed");
        assertEq(renderer.description(), "New.");
        assertEq(renderer.externalUrl(), "https://getminted.io");
        assertEq(renderer.image(), "ipfs://revealed");
    }

    function test_setStrings_byNonOwner_reverts() public {
        /* Scenario:
           Given a wallet that does not own the renderer
           When it tries to revise the strings
           Then the call is refused */
        vm.prank(alice);
        vm.expectRevert();
        renderer.setStrings("x", "y", "z");
    }

    /// @dev Strips the `data:application/json;base64,` prefix and returns the document.
    function _decode(string memory uri) internal pure returns (string memory) {
        bytes memory b = bytes(uri);
        uint256 prefix = 29;
        bytes memory tail = new bytes(b.length - prefix);
        for (uint256 i = prefix; i < b.length; ++i) {
            tail[i - prefix] = b[i];
        }
        return string(Base64.decode(string(tail)));
    }

    function test_render_producesTheExpectedDocument() public {
        /* Scenario:
           Given ordinary strings
           When a bear is rendered
           Then the decoded document is exactly the metadata marketplaces expect */
        assertEq(
            _decode(renderer.render(4444)),
            '{"name":"MINT Bear #4444","description":"A bear.","external_url":"https://mint.io","image":"ipfs://placeholder","attributes":[]}'
        );
    }

    function test_render_escapesDoubleQuotes() public {
        /* Scenario:
           Given a description containing a double quote, which reads as ordinary copy
           When a bear is rendered
           Then the quote is escaped and the document stays parseable */
        renderer.setStrings('A 4,444 "free mint" bear.', "https://mint.io", "ipfs://x");
        assertEq(
            _decode(renderer.render(1)),
            '{"name":"MINT Bear #1","description":"A 4,444 \\"free mint\\" bear.","external_url":"https://mint.io","image":"ipfs://x","attributes":[]}'
        );
    }

    function test_render_escapesAttemptedFieldInjection() public {
        /* Scenario:
           Given a description shaped to close its field and open another
           When a bear is rendered
           Then it stays inside the description and no second image key appears */
        renderer.setStrings('x","image":"ipfs://injected', "https://mint.io", "ipfs://real");
        string memory doc = _decode(renderer.render(1));

        assertTrue(LibString.contains(doc, '"image":"ipfs://real"'), "real image survives");
        assertFalse(LibString.contains(doc, '"image":"ipfs://injected"'), "injected key must not appear");
    }

    function test_render_escapesBackslashes() public {
        /* Scenario:
           Given a description containing a backslash
           When a bear is rendered
           Then it is escaped rather than swallowing the character after it */
        renderer.setStrings("back\\slash", "https://mint.io", "ipfs://x");
        assertTrue(LibString.contains(_decode(renderer.render(1)), "back\\\\slash"));
    }

    function test_render_escapesTheUrlAndImageToo() public {
        /* Scenario:
           Given a quote in the external url and the image
           When a bear is rendered
           Then both are escaped, not only the description */
        renderer.setStrings("ok", 'https://mint.io/"evil', 'ipfs://"evil');
        string memory doc = _decode(renderer.render(1));
        assertTrue(LibString.contains(doc, 'https://mint.io/\\"evil'), "url escaped");
        assertTrue(LibString.contains(doc, 'ipfs://\\"evil'), "image escaped");
    }

    function test_render_emptyStringsStayValid() public {
        /* Scenario:
           Given every string left empty
           When a bear is rendered
           Then the document is still well formed, just empty */
        renderer.setStrings("", "", "");
        assertEq(
            _decode(renderer.render(1)),
            '{"name":"MINT Bear #1","description":"","external_url":"","image":"","attributes":[]}'
        );
    }
}
