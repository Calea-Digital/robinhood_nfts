// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest} from "./BaseTest.t.sol";
import {MintABear} from "../src/MintABear.sol";
import {IERC2981} from "openzeppelin-contracts/interfaces/IERC2981.sol";
import {ISeaDropTokenContractMetadata} from "seadrop/interfaces/ISeaDropTokenContractMetadata.sol";
import {INonFungibleSeaDropToken} from "seadrop/interfaces/INonFungibleSeaDropToken.sol";
import {TwoStepOwnable} from "utility-contracts/TwoStepOwnable.sol";

/**
 * @title  SeaDropIntegrationTest
 * @notice Pins the boundary between what OpenSea Studio configures and what this collection
 *         enforces for itself.
 * @dev    Two functions on `ERC721SeaDrop` that matter here are `virtual`, `mintSeaDrop` and
 *         `tokenURI`, and the collection overrides neither. `getMintStats`, `setMaxSupply`,
 *         `setBaseURI`, `multiConfigure` and `burn` are all final, so anything this collection
 *         needs to enforce against them has to happen in `_beforeTokenTransfers`. These tests
 *         exist so that the consequences of that are written down rather than discovered
 *         during the drop.
 */
contract SeaDropIntegrationTest is BaseTest {
    /// @dev Mirrors SeaDrop's `RoyaltyInfoUpdated`; solc 0.8.17 cannot qualify an event in `emit`.
    event RoyaltyInfoUpdated(address receiver, uint256 bps);

    /// @dev Stand-in for the royalty pot MINT names (CQ-15): distinct from the admin and every vault.
    address internal pot = makeAddr("royaltyPot");

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
        /* Scenario: COL-1 — Only SeaDrop mints
           Given the collection deployed with canonical SeaDrop as its only allowed minter
           When any other address calls the mint path
           Then the call reverts and no bear is minted */
        vm.prank(alice);
        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        bears.mintSeaDrop(alice, 1);

        vm.prank(operator);
        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        bears.mintSeaDrop(bob, 3);

        assertEq(bears.totalSupply(), 0, "nothing minted");
    }

    function test_mintSeaDrop_byTheContractOwner_reverts() public {
        /* Scenario: COL-1 — Only SeaDrop mints
           Given the contract owner, who configures the drop but is not a SeaDrop
           When they call the mint path directly
           Then the call reverts and no bear is minted */
        assertEq(bears.owner(), address(this));
        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        bears.mintSeaDrop(address(this), 1);
        assertEq(bears.totalSupply(), 0);
    }

    function test_noOtherMintEntryPoint() public {
        /* Scenario: COL-1 — Only SeaDrop mints
           When the usual public mint selectors are called on the collection
           Then none exists: mintSeaDrop is the only way a bear comes into being */
        string[4] memory signatures = [
            "mint(address,uint256)", "mint(uint256)", "safeMint(address,uint256)", "mint(address)"
        ];
        for (uint256 i; i < signatures.length; ++i) {
            (bool ok, bytes memory ret) = address(bears)
                .call(abi.encodePacked(bytes4(keccak256(bytes(signatures[i]))), abi.encode(alice, uint256(1))));
            assertFalse(ok, signatures[i]);
            assertEq(ret.length, 0, signatures[i]);
        }
        assertEq(bears.totalSupply(), 0);
    }

    function test_updateAllowedSeaDrop_isOwnerOnly() public {
        /* Scenario: COL-1 — Only SeaDrop mints
           Given the allowed-SeaDrop list is the owner's setting
           When a non-owner tries to add itself as a minter
           Then it reverts, and the owner can still change the list */
        address[] memory allowed = new address[](1);
        allowed[0] = alice;

        vm.prank(alice);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        bears.updateAllowedSeaDrop(allowed);

        bears.updateAllowedSeaDrop(allowed);
        vm.prank(alice);
        bears.mintSeaDrop(alice, 1);
        assertEq(bears.ownerOf(1), alice);
        assertEq(bears.transferNonce(1), 0);
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

    function test_baseURI_isServed() public {
        /* Scenario: COL-5 — Metadata is base URI plus id
           Given baseURI set through Studio
           When tokenURI(id) is read
           Then it returns baseURI followed by id */
        _mint(alice, 1);
        bears.setBaseURI("https://api.example.com/");

        assertEq(bears.baseURI(), "https://api.example.com/", "stored");
        assertEq(bears.tokenURI(1), "https://api.example.com/1", "served");
    }

    function test_provenanceHash_mustPrecedeTheFirstMint() public {
        /* Scenario:
           Given provenance may only be set before minting starts
           When it is set on a collection with nothing minted
           Then it succeeds, and once the first bear exists it is refused */
        bears.setProvenanceHash(keccak256("manifest"));
        assertEq(bears.provenanceHash(), keccak256("manifest"));

        _mint(alice, 1);
        vm.expectRevert(ISeaDropTokenContractMetadata.ProvenanceHashCannotBeSetAfterMintStarted.selector);
        bears.setProvenanceHash(keccak256("late"));
    }

    /*                  SECONDARY TRADING SURFACE                     */

    function test_royaltyInfo_readsFivePercentToThePot() public {
        /* Scenario: COL-6 — Royalty info reads 5% to the pot
           Given royalty info set in Studio to 500 basis points and the pot address
           When royaltyInfo(id, salePrice) is read
           Then it returns the pot address and 5% of salePrice */
        bears.setRoyaltyInfo(_royalty(pot, 500));
        _mint(alice, 1);

        (address receiver, uint256 amount) = bears.royaltyInfo(1, 10 ether);
        assertEq(receiver, pot);
        assertEq(amount, 0.5 ether);

        assertEq(bears.royaltyAddress(), pot);
        assertEq(bears.royaltyBasisPoints(), 500);
    }

    function test_royaltyInfo_isTheSameForEveryBear() public {
        /* Scenario: COL-6 — Royalty info reads 5% to the pot
           Given royalty info set to 500 basis points and the pot
           When royaltyInfo is read for the first bear, the last bear and an id that does not exist
           Then every answer is the pot and 5%, because the rate is collection-wide */
        bears.setRoyaltyInfo(_royalty(pot, 500));
        _mint(alice, 1);

        (address r1, uint256 a1) = bears.royaltyInfo(1, 1 ether);
        (address r2, uint256 a2) = bears.royaltyInfo(4444, 1 ether);
        (address r3, uint256 a3) = bears.royaltyInfo(9999, 1 ether);
        assertEq(r1, pot);
        assertEq(r2, pot);
        assertEq(r3, pot);
        assertEq(a1, 0.05 ether);
        assertEq(a2, 0.05 ether);
        assertEq(a3, 0.05 ether);
    }

    function test_setRoyaltyInfo_emitsRoyaltyInfoUpdated() public {
        /* Scenario: COL-6 — Royalty info reads 5% to the pot
           When the owner sets royalty info
           Then RoyaltyInfoUpdated(receiver, bps) is emitted with the pot and 500 */
        vm.expectEmit(false, false, false, true, address(bears));
        emit RoyaltyInfoUpdated(pot, 500);
        bears.setRoyaltyInfo(_royalty(pot, 500));
    }

    function test_setRoyaltyInfo_aboveTenThousandBps_reverts() public {
        /* Scenario: COL-6 — Royalty info reads 5% to the pot
           When the owner sets a rate above 100%
           Then SeaDrop refuses it with InvalidRoyaltyBasisPoints */
        vm.expectRevert(
            abi.encodeWithSelector(ISeaDropTokenContractMetadata.InvalidRoyaltyBasisPoints.selector, 10_001)
        );
        bears.setRoyaltyInfo(_royalty(pot, 10_001));
    }

    function test_setRoyaltyInfo_isOwnerOnly() public {
        /* Scenario: COL-6 — Royalty info reads 5% to the pot
           When a wallet that does not own the contract sets royalty info
           Then it reverts with OnlyOwner and nothing changes */
        vm.prank(alice);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        bears.setRoyaltyInfo(_royalty(alice, 1_000));
        assertEq(bears.royaltyAddress(), address(0));
        assertEq(bears.royaltyBasisPoints(), 0);
    }

    function _royalty(address receiver, uint96 bps) internal pure returns (MintABear.RoyaltyInfo memory info) {
        info.royaltyAddress = receiver;
        info.royaltyBps = bps;
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

    function test_supportsInterface_advertisesEverythingStudioLooksFor() public view {
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

    function test_transferValidator_startsUnset_deployScriptSetsIt() public view {
        /* Scenario:
           Given a freshly constructed collection
           When the validator is read
           Then it is unset: the deploy script sets Limit Break V3 right after setMaxSupply (OPS-2, COL-7) */
        assertEq(bears.getTransferValidator(), address(0));
    }
}
