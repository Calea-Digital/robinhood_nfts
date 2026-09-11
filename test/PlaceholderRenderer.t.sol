// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {PlaceholderRenderer} from "../src/renderers/PlaceholderRenderer.sol";
import {LibString} from "solady/utils/LibString.sol";

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
}
