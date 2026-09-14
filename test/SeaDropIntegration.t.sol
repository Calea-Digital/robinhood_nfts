// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest} from "./BaseTest.t.sol";
import {MintABear} from "../src/MintABear.sol";
import {MockRenderer} from "./mocks/MockRenderer.sol";
import {IERC2981} from "openzeppelin-contracts/interfaces/IERC2981.sol";
import {ISeaDropTokenContractMetadata} from "seadrop/interfaces/ISeaDropTokenContractMetadata.sol";
import {INonFungibleSeaDropToken} from "seadrop/interfaces/INonFungibleSeaDropToken.sol";

/**
 * @title  SeaDropIntegrationTest
 * @notice Pins the boundary between what OpenSea Studio configures and what this collection
 *         enforces for itself.
 * @dev    Only one function on `ERC721SeaDrop` that matters here is `virtual`: `mintSeaDrop`
 *         and `tokenURI`. `getMintStats`, `setMaxSupply`, `setBaseURI`, `multiConfigure` and
 *         `burn` are all final, so anything this collection needs to enforce against them has
 *         to happen in `_beforeTokenTransfers`. These tests exist so that the consequences of
 *         that are written down rather than discovered during the drop.
 */
contract SeaDropIntegrationTest is BaseTest {
    function test_mintSeaDrop_isUntouched() public {
        /* Scenario:
           Given the canonical SeaDrop mint entry point
           When it mints a batch
           Then it behaves normally: sequential ids from 1, no transfer counter movement */
        vm.prank(seaDrop);
        bears.mintSeaDrop(alice, 5);

        assertEq(bears.totalSupply(), 5);
        assertEq(bears.ownerOf(1), alice);
        assertEq(bears.ownerOf(5), alice);
        assertEq(bears.transferNonce(1), 0, "minting is not a transfer");
    }

    function test_mintSeaDrop_fromDisallowedAddress_reverts() public {
        /* Scenario:
           Given an address that is not an allowed SeaDrop
           When it tries to mint
           Then SeaDrop's own guard refuses it, unchanged by anything here */
        vm.prank(alice);
        vm.expectRevert();
        bears.mintSeaDrop(alice, 1);
    }

    function test_getMintStats_tracksPerWalletMinting() public {
        /* Scenario:
           Given SeaDrop drives per-wallet limits from getMintStats
           When two wallets mint different amounts
           Then each wallet's count is reported independently */
        _mint(alice, 3);
        _mint(bob, 1);

        (uint256 aliceMinted, uint256 supply, uint256 cap) = bears.getMintStats(alice);
        assertEq(aliceMinted, 3);
        assertEq(supply, 4);
        assertEq(cap, MAX_SUPPLY);

        (uint256 bobMinted,,) = bears.getMintStats(bob);
        assertEq(bobMinted, 1);
    }

    function test_burnRefusal_keepsPerWalletLimitsHonest() public {
        /* Scenario:
           Given per-wallet limits count minted rather than held
           When a holder tries to burn to reset their count
           Then the burn is refused, so the limit cannot be cycled */
        _mint(alice, 2);
        vm.prank(alice);
        vm.expectRevert(MintABear.BurnDisabled.selector);
        bears.burn(1);

        (uint256 minted,,) = bears.getMintStats(alice);
        assertEq(minted, 2, "count intact");
    }

    /*              SUPPLY: WHERE STUDIO AND THE CAP MEET              */

    function test_maxSupplyBelowCap_seaDropRefusesFirst() public {
        /* Scenario:
           Given maxSupply configured more restrictively than the hard cap
           When a mint would pass it
           Then SeaDrop's own error fires, which is the normal sold-out path */
        bears.setMaxSupply(10);
        _mint(alice, 10);

        vm.prank(seaDrop);
        vm.expectRevert();
        bears.mintSeaDrop(alice, 1);
        assertEq(bears.totalSupply(), 10);
    }

    function test_maxSupplyAboveCap_mintStopsAtTheCap() public {
        /* Scenario:
           Given maxSupply misconfigured above the hard cap, which Studio can do
           When minting runs past 4,444
           Then the cap refuses it — the collection cannot be inflated, but the failure
           lands at mint time rather than at configuration time */
        bears.setMaxSupply(10_000);
        _mint(alice, MAX_SUPPLY);

        vm.prank(seaDrop);
        vm.expectRevert(MintABear.ExceedsMaxBears.selector);
        bears.mintSeaDrop(alice, 1);
    }

    function test_maxSupplyAboveCap_isVisibleInMintStats() public {
        /* Scenario:
           Given maxSupply above the hard cap
           When getMintStats is read, as SeaDrop and Studio read it
           Then it reports the configured value and not the real ceiling. getMintStats is
           final, so this mismatch cannot be corrected in code — the deploy runbook has to
           set maxSupply to MAX_BEARS exactly. */
        bears.setMaxSupply(10_000);
        (,, uint256 reported) = bears.getMintStats(alice);

        assertEq(reported, 10_000, "what Studio sees");
        assertEq(bears.MAX_BEARS(), 4444, "what actually applies");
    }

    /*                      MULTICONFIGURE                            */

    function test_multiConfigure_appliesSupplyAndMetadata() public {
        /* Scenario:
           Given Studio configures the collection in one call
           When multiConfigure runs
           Then the settings it owns are applied */
        MintABear.MultiConfigureStruct memory config;
        config.maxSupply = MAX_SUPPLY;
        config.baseURI = "https://api.example.com/";
        config.contractURI = "https://api.example.com/contract";
        config.provenanceHash = keccak256("manifest");

        bears.multiConfigure(config);

        assertEq(bears.maxSupply(), MAX_SUPPLY);
        assertEq(bears.baseURI(), "https://api.example.com/");
        assertEq(bears.contractURI(), "https://api.example.com/contract");
        assertEq(bears.provenanceHash(), keccak256("manifest"));
    }

    function test_baseURI_isSetButNeverUsed() public {
        /* Scenario:
           Given Studio sets a baseURI, which it does by default for a managed drop
           When a bear's tokenURI is read
           Then the renderer answers and the baseURI is ignored. This collection serves
           metadata on-chain; anything configured through Studio's metadata fields has no
           effect and the portal team needs to know that. */
        _mint(alice, 1);
        bears.setBaseURI("https://api.example.com/");

        MockRenderer mock = new MockRenderer("FROM_RENDERER");
        bears.setRenderer(address(mock));

        assertEq(bears.baseURI(), "https://api.example.com/", "stored");
        assertEq(bears.tokenURI(1), "FROM_RENDERER", "but not served");
    }

    function test_provenanceHash_mustPrecedeTheFirstMint() public {
        /* Scenario:
           Given provenance may only be set before minting starts
           When recordAccounts runs first, as the runbook requires
           Then provenance can still be set, because recording is not minting */
        bears.recordAccounts(1, 100);
        bears.setProvenanceHash(keccak256("manifest"));
        assertEq(bears.provenanceHash(), keccak256("manifest"));

        _mint(alice, 1);
        vm.expectRevert();
        bears.setProvenanceHash(keccak256("late"));
    }

    /*                  SECONDARY TRADING SURFACE                     */

    function test_royalties_areUntouched() public {
        /* Scenario:
           Given royalties configured through the SeaDrop base
           When royaltyInfo is queried the way a marketplace queries it
           Then it answers normally */
        MintABear.RoyaltyInfo memory info;
        info.royaltyAddress = bob;
        info.royaltyBps = 500;
        bears.setRoyaltyInfo(info);

        _mint(alice, 1);
        (address receiver, uint256 amount) = bears.royaltyInfo(1, 10 ether);
        assertEq(receiver, bob);
        assertEq(amount, 0.5 ether);
    }

    function test_operatorTransfer_worksLikeAConduit() public {
        /* Scenario:
           Given an operator approved for all, which is how Seaport's conduit moves tokens
           When it transfers a bear to a buyer
           Then it succeeds and the transfer counter advances */
        _mint(alice, 1);
        vm.prank(alice);
        bears.setApprovalForAll(operator, true);

        vm.prank(operator);
        bears.transferFrom(alice, bob, 1);

        assertEq(bears.ownerOf(1), bob);
        assertEq(bears.transferNonce(1), 1);
    }

    function test_recordedAccounts_doNotBlockOrdinaryCounterparties() public {
        /* Scenario:
           Given the whole supply of account addresses is recorded
           When bears move between ordinary wallets and marketplace addresses
           Then nothing is blocked; only the derived account addresses are refused */
        bears.recordAccounts(1, MAX_SUPPLY);
        _mint(alice, 1);

        vm.prank(alice);
        bears.transferFrom(alice, seaDrop, 1);
        assertEq(bears.ownerOf(1), seaDrop);

        assertFalse(bears.isBearAccount(seaDrop), "SeaDrop is not a bear account");
        assertFalse(bears.isBearAccount(operator), "nor an operator");
        assertFalse(bears.isBearAccount(alice), "nor a holder");
    }

    function test_supportsInterface_advertisesEverythingStudioLooksFor() public {
        /* Scenario:
           Given OpenSea detects capability through ERC-165
           When the interfaces are queried
           Then all of them still read true */
        assertTrue(bears.supportsInterface(0x01ffc9a7), "ERC165");
        assertTrue(bears.supportsInterface(0x80ac58cd), "ERC721");
        assertTrue(bears.supportsInterface(0x5b5e139f), "ERC721Metadata");
        assertTrue(bears.supportsInterface(type(IERC2981).interfaceId), "ERC2981 royalties");
        assertTrue(bears.supportsInterface(0x49064906), "ERC4906 metadata update");
        assertTrue(bears.supportsInterface(type(ISeaDropTokenContractMetadata).interfaceId), "SeaDrop metadata");
        assertTrue(bears.supportsInterface(type(INonFungibleSeaDropToken).interfaceId), "SeaDrop token");
    }

    function test_transferValidator_staysUnset() public {
        /* Scenario:
           Given ERC-721C enforcement is deliberately off
           When the validator is read
           Then it is unset, so OpenSea's conduit and smart wallets can move bears */
        assertEq(bears.getTransferValidator(), address(0));
    }
}
