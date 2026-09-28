// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SeaDrop} from "seadrop/SeaDrop.sol";
import {AllowListData, MintParams} from "seadrop/lib/SeaDropStructs.sol";
import {SeaDropErrorsAndEvents} from "seadrop/lib/SeaDropErrorsAndEvents.sol";

import {MintABear} from "../src/MintABear.sol";
import {WhitelistClaim} from "../src/WhitelistClaim.sol";
import {AllowListTree} from "../script/lib/AllowListTree.sol";
import {WhitelistExport} from "../script/WhitelistExport.s.sol";
import {WhitelistClaimBase} from "./WhitelistClaim.t.sol";
import {WhitelistImportBase} from "./WhitelistImport.t.sol";
import {MockClaimantRegistry} from "./mocks/MockClaimantRegistry.sol";

/// @dev Puts the library's internal functions behind an external call, so their reverts can be expected.
contract AllowListTreeHarness {
    function root(bytes32[] memory leaves) external pure returns (bytes32) {
        return AllowListTree.root(leaves);
    }

    function proof(bytes32[] memory leaves, bytes32 target) external pure returns (bytes32[] memory) {
        return AllowListTree.proof(leaves, target);
    }
}

/// @dev `AllowListTree` against merkletreejs 0.2.32 — the library and options SeaDrop's own
///      reference tests build allowlists with (`hashLeaves`, `sortLeaves`, `sortPairs`). The vector
///      was produced by that library over the five rows below; `test/fixtures/merkletreejs-vector.js`
///      regenerates it.
contract AllowListTreeTest is WhitelistClaimBase {
    WhitelistExport internal exporter;
    AllowListTreeHarness internal tree;

    bytes32 internal constant VECTOR_ROOT = 0x8cabae64e27037f2c74f33c05a4ceeed39b40d86c4dd9f866aa87fe7ee3627e7;

    function setUp() public override {
        super.setUp();
        exporter = new WhitelistExport();
        tree = new AllowListTreeHarness();
    }

    function _stage() internal pure returns (MintParams memory) {
        return MintParams({
            mintPrice: 0,
            maxTotalMintableByWallet: 0,
            startTime: 1_793_145_599,
            endTime: 1_793_231_999,
            dropStageIndex: 1,
            maxTokenSupplyForStage: 4444,
            feeBps: 0,
            restrictFeeRecipients: false
        });
    }

    function _vectorRows() internal pure returns (WhitelistClaim.Claimant[] memory rows) {
        rows = new WhitelistClaim.Claimant[](5);
        rows[0] = WhitelistClaim.Claimant({wallet: 0x1111111111111111111111111111111111111111, allocations: 2});
        rows[1] = WhitelistClaim.Claimant({wallet: 0x2222222222222222222222222222222222222222, allocations: 1});
        rows[2] = WhitelistClaim.Claimant({wallet: 0x3333333333333333333333333333333333333333, allocations: 1});
        rows[3] = WhitelistClaim.Claimant({wallet: 0x4444444444444444444444444444444444444444, allocations: 2});
        rows[4] = WhitelistClaim.Claimant({wallet: 0x5555555555555555555555555555555555555555, allocations: 1});
    }

    function test_root_equalsMerkletreejs() public view {
        /* Scenario:
           Given five rows and a whitelist stage
           When the allowlist root is built from them
           Then it equals the root merkletreejs 0.2.32 builds with SeaDrop's reference options,
             whatever order the rows come in */
        bytes32[] memory leaves = exporter.leaves(_vectorRows(), _stage());
        assertEq(tree.root(leaves), VECTOR_ROOT);

        bytes32[] memory reversed = new bytes32[](leaves.length);
        for (uint256 i; i < leaves.length; ++i) {
            reversed[i] = leaves[leaves.length - 1 - i];
        }
        assertEq(tree.root(reversed), VECTOR_ROOT);
    }

    function test_proof_equalsMerkletreejs() public view {
        /* Scenario:
           Given the same five rows
           When proofs are built for a leaf in a full pair and for the odd leaf carried up
           Then each equals merkletreejs's proof for that leaf */
        bytes32[] memory leaves = exporter.leaves(_vectorRows(), _stage());
        assertEq(leaves[0], 0x53efe867013727e3689231b2edb0a63025e9634bbf513e19f77dfabdb4f80a39);

        bytes32[] memory p0 = tree.proof(leaves, leaves[0]);
        assertEq(p0.length, 3);
        assertEq(p0[0], 0x0864690c4cbd1e2b49c2db6498363c3462f0f9a0b5b79314c3055ca020c5eeb1);
        assertEq(p0[1], 0x15d735c8f8236876b0ecba70c984be63b40f9003b6d68a208f25dc466d913857);
        assertEq(p0[2], 0xe159d9efea745add5d4acf1787c45222eb52d7ebd7c7d80340bae0b043628776);

        bytes32[] memory p2 = tree.proof(leaves, leaves[2]);
        assertEq(p2.length, 1);
        assertEq(p2[0], 0x309e51cece4ba52cf32a9606b56a3e769d668d2cdee1aa9414f7d6ae0113d464);
    }

    function test_root_ofOneLeaf_isTheLeaf() public view {
        /* Scenario:
           Given a single row
           When the root is built
           Then it is that row's leaf, as merkletreejs gives it */
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = exporter.leaves(_vectorRows(), _stage())[0];
        assertEq(tree.root(leaves), leaves[0]);
        assertEq(tree.proof(leaves, leaves[0]).length, 0);
    }

    function test_tree_refusesNoLeavesAndAnUnknownLeaf() public {
        /* Scenario:
           Given no leaves, or a leaf that is not among them
           When a root or a proof is asked for
           Then it reverts with EmptyTree or LeafNotFound */
        vm.expectRevert(AllowListTree.EmptyTree.selector);
        tree.root(new bytes32[](0));

        bytes32[] memory leaves = exporter.leaves(_vectorRows(), _stage());
        vm.expectRevert(abi.encodeWithSelector(AllowListTree.LeafNotFound.selector, bytes32(uint256(1))));
        tree.proof(leaves, bytes32(uint256(1)));
    }
}

/// @dev The export and the compare against a registry, a SeaDrop and a `MintABear` deployed here.
contract WhitelistExportTest is WhitelistClaimBase {
    WhitelistExport internal exporter;
    SeaDrop internal seaDrop;
    MintABear internal bears;

    string internal constant CSV = "exports/test-whitelist.csv";
    address internal feeRecipient = makeAddr("feeRecipient");

    function setUp() public override {
        super.setUp();
        exporter = new WhitelistExport();
        seaDrop = new SeaDrop();
        address[] memory allowed = new address[](1);
        allowed[0] = address(seaDrop);
        bears = new MintABear("MintABear", "BEAR", allowed);
        bears.setMaxSupply(4444);
    }

    function _stage() internal pure returns (MintParams memory) {
        return MintParams({
            mintPrice: 0,
            maxTotalMintableByWallet: 0,
            startTime: uint256(CLOSE_AT) + 2 days,
            endTime: uint256(CLOSE_AT) + 3 days,
            dropStageIndex: 1,
            maxTokenSupplyForStage: 4444,
            feeBps: 0,
            restrictFeeRecipients: false
        });
    }

    function _campaign() internal {
        _claim(alice, 1, ACCOUNT_A);
        _claim(bob, 1, ACCOUNT_B);
        _claim(alice, 2, ACCOUNT_A);
        _claim(carol, 1, keccak256("getminted:account-c"));
        vm.warp(uint256(CLOSE_AT) + 1);
    }

    function _setRoot(bytes32 root) internal {
        bears.updateAllowList(
            address(seaDrop), AllowListData({merkleRoot: root, publicKeyURIs: new string[](0), allowListURI: ""})
        );
    }

    function test_export_writesTheCsv() public {
        /* Scenario:
           Given a closed campaign with three claimants
           When export runs
           Then the CSV carries a header and one wallet,allocations row per claimant, in claim order */
        _campaign();
        WhitelistClaim.Claimant[] memory rows = exporter.export(address(wl), CSV);
        assertEq(rows.length, 3);

        string memory expected = string.concat(
            "wallet,allocations\n", vm.toString(alice), ",2\n", vm.toString(bob), ",1\n", vm.toString(carol), ",1\n"
        );
        assertEq(vm.readFile(CSV), expected);
        vm.removeFile(CSV);
    }

    function test_exportAndCompare_refuseWhileClaimsAreOpen() public {
        /* Scenario:
           Given a campaign with spots left, at its last second
           When export or compare runs
           Then each reverts with CampaignStillOpen, because a later claim would be missing; one
             second after the close both run */
        _claim(alice, 1, ACCOUNT_A);
        vm.warp(CLOSE_AT);

        vm.expectRevert(abi.encodeWithSelector(WhitelistExport.CampaignStillOpen.selector, CLOSE_AT, 999));
        exporter.export(address(wl), CSV);
        vm.expectRevert(abi.encodeWithSelector(WhitelistExport.CampaignStillOpen.selector, CLOSE_AT, 999));
        exporter.compare(address(wl), address(seaDrop), address(bears), _stage());

        vm.warp(uint256(CLOSE_AT) + 1);
        assertEq(exporter.checkedRows(wl).length, 1);
    }

    function test_export_readsEveryPage() public {
        /* Scenario:
           Given a campaign sold out of 500 claimants before its close, more than one page
           When the rows are read
           Then all 500 come back, each with two allocations: a sell-out ends the campaign early */
        for (uint256 i; i < 500; ++i) {
            address wallet = makeAddr(string(abi.encode("claimant", i)));
            bytes32 account = keccak256(abi.encode("account", i));
            _claim(wallet, 1, account);
            _claim(wallet, 2, account);
        }
        WhitelistClaim.Claimant[] memory rows = exporter.checkedRows(wl);
        assertEq(rows.length, 500);
        assertEq(rows[499].wallet, makeAddr(string(abi.encode("claimant", uint256(499)))));
        assertEq(rows[499].allocations, 2);
    }

    function test_compare_passesForTheRegistrysAllowlist_andEveryProofMints() public {
        /* Scenario:
           Given a closed campaign and the allowlist root built from its rows set on SeaDrop
           When compare runs
           Then it passes, and each row's proof mints exactly its allocations and no more */
        _campaign();
        WhitelistClaim.Claimant[] memory rows = exporter.checkedRows(wl);
        bytes32[] memory leaves = exporter.leaves(rows, _stage());
        _setRoot(AllowListTree.root(leaves));

        assertEq(exporter.compare(address(wl), address(seaDrop), address(bears), _stage()), AllowListTree.root(leaves));

        vm.warp(uint256(CLOSE_AT) + 2 days);
        for (uint256 i; i < rows.length; ++i) {
            MintParams memory params = _stage();
            params.maxTotalMintableByWallet = rows[i].allocations;
            bytes32[] memory proof = AllowListTree.proof(leaves, leaves[i]);

            vm.prank(rows[i].wallet);
            seaDrop.mintAllowList(address(bears), feeRecipient, address(0), rows[i].allocations, params, proof);
            assertEq(bears.balanceOf(rows[i].wallet), rows[i].allocations);

            vm.prank(rows[i].wallet);
            vm.expectRevert(
                abi.encodeWithSelector(
                    SeaDropErrorsAndEvents.MintQuantityExceedsMaxMintedPerWallet.selector,
                    rows[i].allocations + 1,
                    rows[i].allocations
                )
            );
            seaDrop.mintAllowList(address(bears), feeRecipient, address(0), 1, params, proof);
        }
    }

    function test_compare_failsWhenTheLoadedListDiffers() public {
        /* Scenario:
           Given a root on SeaDrop built from a list missing one claimant, or from other stage parameters
           When compare runs
           Then it reverts with RootMismatch naming both roots */
        _campaign();
        WhitelistClaim.Claimant[] memory rows = exporter.checkedRows(wl);
        bytes32 expected = AllowListTree.root(exporter.leaves(rows, _stage()));

        WhitelistClaim.Claimant[] memory short = new WhitelistClaim.Claimant[](2);
        short[0] = rows[0];
        short[1] = rows[1];
        bytes32 loaded = AllowListTree.root(exporter.leaves(short, _stage()));
        _setRoot(loaded);
        vm.expectRevert(abi.encodeWithSelector(WhitelistExport.RootMismatch.selector, expected, loaded));
        exporter.compare(address(wl), address(seaDrop), address(bears), _stage());

        MintParams memory other = _stage();
        other.endTime += 1;
        loaded = AllowListTree.root(exporter.leaves(rows, other));
        _setRoot(loaded);
        vm.expectRevert(abi.encodeWithSelector(WhitelistExport.RootMismatch.selector, expected, loaded));
        exporter.compare(address(wl), address(seaDrop), address(bears), _stage());
    }
}

/// @dev The export and compare over the owner-imported registry (WL-7), read through the same
///      interface as `WhitelistClaim`.
contract WhitelistExportImportTest is WhitelistImportBase {
    WhitelistExport internal exporter;
    SeaDrop internal seaDrop;
    MintABear internal bears;

    string internal constant CSV = "exports/test-whitelist-import.csv";

    function setUp() public override {
        super.setUp();
        exporter = new WhitelistExport();
        seaDrop = new SeaDrop();
        address[] memory allowed = new address[](1);
        allowed[0] = address(seaDrop);
        bears = new MintABear("MintABear", "BEAR", allowed);
        bears.setMaxSupply(4444);
    }

    function _stage() internal pure returns (MintParams memory) {
        return MintParams({
            mintPrice: 0,
            maxTotalMintableByWallet: 0,
            startTime: uint256(CLOSE_AT) + 2 days,
            endTime: uint256(CLOSE_AT) + 3 days,
            dropStageIndex: 1,
            maxTokenSupplyForStage: 4444,
            feeBps: 0,
            restrictFeeRecipients: false
        });
    }

    function test_export_refusesAnImportUntilItFreezes_evenSoldOut() public {
        /* Scenario:
           Given a WhitelistImport filled to 1,000 allocations, with closeAt not passed
           When export or compare runs, then again one second after closeAt
           Then each reverts with CampaignStillOpen while a correction is still possible, and after
             the close the rows are read */
        address[] memory w = new address[](500);
        uint8[] memory c = new uint8[](500);
        for (uint256 i; i < 500; ++i) {
            (w[i], c[i]) = (_wallet(i), 2);
        }
        vm.prank(admin);
        wl.addAllocations(w, c);
        assertEq(wl.spotsLeft(), 0);

        vm.warp(CLOSE_AT);
        vm.expectRevert(abi.encodeWithSelector(WhitelistExport.CampaignStillOpen.selector, CLOSE_AT, 0));
        exporter.export(address(wl), CSV);
        vm.expectRevert(abi.encodeWithSelector(WhitelistExport.CampaignStillOpen.selector, CLOSE_AT, 0));
        exporter.compare(address(wl), address(seaDrop), address(bears), _stage());

        vm.warp(uint256(CLOSE_AT) + 1);
        assertEq(exporter.checkedRows(WhitelistClaim(address(wl))).length, 500);
    }

    function test_exportAndCompare_overAFrozenImport() public {
        /* Scenario:
           Given a frozen WhitelistImport of alice (2) and bob (1), and the root of its rows set on SeaDrop
           When export and compare run
           Then the CSV carries both rows, compare passes, and each proof mints exactly its allocations */
        (address[] memory w, uint8[] memory c) = _two(alice, 2, bob, 1);
        vm.prank(admin);
        wl.addAllocations(w, c);
        vm.warp(uint256(CLOSE_AT) + 1);

        WhitelistClaim.Claimant[] memory rows = exporter.export(address(wl), CSV);
        assertEq(
            vm.readFile(CSV),
            string.concat("wallet,allocations\n", vm.toString(alice), ",2\n", vm.toString(bob), ",1\n")
        );
        vm.removeFile(CSV);

        bytes32[] memory leaves = exporter.leaves(rows, _stage());
        bytes32 root = AllowListTree.root(leaves);
        bears.updateAllowList(
            address(seaDrop), AllowListData({merkleRoot: root, publicKeyURIs: new string[](0), allowListURI: ""})
        );
        assertEq(exporter.compare(address(wl), address(seaDrop), address(bears), _stage()), root);

        vm.warp(uint256(CLOSE_AT) + 2 days);
        for (uint256 i; i < rows.length; ++i) {
            MintParams memory params = _stage();
            params.maxTotalMintableByWallet = rows[i].allocations;
            vm.prank(rows[i].wallet);
            seaDrop.mintAllowList(
                address(bears),
                makeAddr("feeRecipient"),
                address(0),
                rows[i].allocations,
                params,
                AllowListTree.proof(leaves, leaves[i])
            );
            assertEq(bears.balanceOf(rows[i].wallet), rows[i].allocations);
        }
    }
}

/// @dev The export's own checks, against a registry stand-in that answers inconsistently.
contract WhitelistExportChecksTest is WhitelistClaimBase {
    WhitelistExport internal exporter;
    MockClaimantRegistry internal registry;

    function setUp() public override {
        super.setUp();
        exporter = new WhitelistExport();
        registry = new MockClaimantRegistry();
    }

    function test_checkedRows_refusesADuplicateWallet() public {
        /* Scenario:
           Given a list naming one wallet twice
           When the rows are checked
           Then it reverts with DuplicateWallet */
        registry.push(alice, 1, 1);
        registry.push(alice, 1, 1);
        registry.setSpotsLeft(998);
        vm.expectRevert(abi.encodeWithSelector(WhitelistExport.DuplicateWallet.selector, alice));
        exporter.checkedRows(WhitelistClaim(address(registry)));
    }

    function test_checkedRows_refusesARowThatDisagreesWithClaimsOf() public {
        /* Scenario:
           Given a row whose allocation count differs from claimsOf
           When the rows are checked
           Then it reverts with AllocationMismatch */
        registry.push(alice, 2, 1);
        vm.expectRevert(abi.encodeWithSelector(WhitelistExport.AllocationMismatch.selector, alice, 2, 1));
        exporter.checkedRows(WhitelistClaim(address(registry)));
    }

    function test_checkedRows_refusesRowsThatDoNotAddUp() public {
        /* Scenario:
           Given rows totalling fewer allocations than the spots claimed
           When the rows are checked
           Then it reverts with TotalMismatch */
        registry.push(alice, 1, 1);
        registry.setSpotsLeft(997);
        vm.expectRevert(abi.encodeWithSelector(WhitelistExport.TotalMismatch.selector, 1, 3));
        exporter.checkedRows(WhitelistClaim(address(registry)));
    }
}
