// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Script, console2} from "forge-std/Script.sol";
import {LibSort} from "solady/utils/LibSort.sol";
import {ISeaDrop} from "seadrop/interfaces/ISeaDrop.sol";
import {MintParams} from "seadrop/lib/SeaDropStructs.sol";

import {WhitelistClaim} from "../src/WhitelistClaim.sol";
import {AllowListTree} from "./lib/AllowListTree.sol";

/**
 * @title  WhitelistExport
 * @notice Read-only tooling for the whitelist's step into the mint (WL-4). Nothing is broadcast.
 *
 *         `export` reads the registry's claimant list, checks it, and writes the CSV loaded as the
 *         whitelist stage's allowlist in Studio:
 *
 *             forge script script/WhitelistExport.s.sol --rpc-url $RPC \
 *               --sig "export(address,string)" $REGISTRY exports/whitelist.csv
 *
 *         `compare` rebuilds the allowlist root from the registry and the stage's parameters as
 *         Studio configured them, reads the root Studio set on SeaDrop, and fails unless they are
 *         equal. A match proves the loaded allowlist is exactly the registry's rows; a mismatch says
 *         only that something differs — rows, stage parameters or tree construction — not which:
 *
 *             forge script script/WhitelistExport.s.sol --rpc-url $RPC \
 *               --sig "compare(address,address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256,bool))" \
 *               $REGISTRY 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5 $COLLECTION \
 *               "(0,0,$START,$END,1,4444,$FEE_BPS,$RESTRICT)"
 *
 *         `maxTotalMintableByWallet` in the stage tuple is ignored: each row's leaf takes the
 *         wallet's allocation count as its limit.
 */
contract WhitelistExport is Script {
    /// @dev Rows read per `claimants` call.
    uint256 internal constant PAGE = 200;

    /// @notice A wallet appears twice in the claimant list.
    error DuplicateWallet(address wallet);

    /// @notice A row's allocation count differs from `claimsOf`.
    error AllocationMismatch(address wallet, uint8 row, uint8 claimsOf);

    /// @notice The rows do not add up to the spots claimed.
    error TotalMismatch(uint256 rows, uint256 claimed);

    /// @notice The root on SeaDrop is not the root of the registry's rows.
    error RootMismatch(bytes32 expected, bytes32 onChain);

    /// @notice The campaign can still take claims: the window has not closed and spots are left.
    error CampaignStillOpen(uint40 closeAt, uint256 spotsLeft);

    /**
     * @notice Writes the registry's claimant list to `path` as `wallet,allocations` rows, after
     *         checking each wallet appears once with `claimsOf` allocations and the total equals the
     *         spots claimed.
     * @param  registry The deployed `WhitelistClaim`.
     * @param  path     Output file, under `exports/`.
     */
    function export(address registry, string memory path) public returns (WhitelistClaim.Claimant[] memory rows) {
        rows = checkedRows(WhitelistClaim(registry));
        vm.createDir("exports", true);
        vm.writeFile(path, "wallet,allocations\n");
        for (uint256 i; i < rows.length; ++i) {
            vm.writeLine(path, string.concat(vm.toString(rows[i].wallet), ",", vm.toString(rows[i].allocations)));
        }
        console2.log("rows", rows.length);
        console2.log("written to", path);
    }

    /**
     * @notice Fails unless the allowlist root SeaDrop holds for `collection` is the root of the
     *         registry's rows under `stage`.
     * @param  registry   The deployed `WhitelistClaim`.
     * @param  seaDrop    The SeaDrop the collection mints through.
     * @param  collection The `MintABear` deployment.
     * @param  stage      The whitelist stage's parameters as set in Studio.
     */
    function compare(address registry, address seaDrop, address collection, MintParams memory stage)
        public
        view
        returns (bytes32 expected)
    {
        expected = AllowListTree.root(leaves(checkedRows(WhitelistClaim(registry)), stage));
        bytes32 onChain = ISeaDrop(seaDrop).getAllowListMerkleRoot(collection);
        console2.log("expected root");
        console2.logBytes32(expected);
        console2.log("on-chain root");
        console2.logBytes32(onChain);
        if (expected != onChain) revert RootMismatch(expected, onChain);
        console2.log("match: the allowlist is the registry's rows");
    }

    /// @notice The allowlist leaves for `rows`, each with its allocation count as the wallet limit.
    function leaves(WhitelistClaim.Claimant[] memory rows, MintParams memory stage)
        public
        pure
        returns (bytes32[] memory out)
    {
        // A copy, so the caller's `stage` is left as it was passed.
        MintParams memory params = MintParams({
            mintPrice: stage.mintPrice,
            maxTotalMintableByWallet: 0,
            startTime: stage.startTime,
            endTime: stage.endTime,
            dropStageIndex: stage.dropStageIndex,
            maxTokenSupplyForStage: stage.maxTokenSupplyForStage,
            feeBps: stage.feeBps,
            restrictFeeRecipients: stage.restrictFeeRecipients
        });
        out = new bytes32[](rows.length);
        for (uint256 i; i < rows.length; ++i) {
            params.maxTotalMintableByWallet = rows[i].allocations;
            out[i] = AllowListTree.leaf(rows[i].wallet, params);
        }
    }

    /// @notice The whole claimant list, checked against the registry's own counts. Refused while
    ///         the campaign can still take claims (WL-4: after the window closes or the spots sell
    ///         out), since a later claim would be missing from the list.
    function checkedRows(WhitelistClaim registry) public view returns (WhitelistClaim.Claimant[] memory rows) {
        uint40 closeAt = registry.closeAt();
        uint256 left = registry.spotsLeft();
        if (block.timestamp <= closeAt && left > 0) revert CampaignStillOpen(closeAt, left);

        rows = new WhitelistClaim.Claimant[](0);
        for (uint256 offset;; offset += PAGE) {
            WhitelistClaim.Claimant[] memory page = registry.claimants(offset, PAGE);
            WhitelistClaim.Claimant[] memory grown = new WhitelistClaim.Claimant[](rows.length + page.length);
            for (uint256 i; i < rows.length; ++i) {
                grown[i] = rows[i];
            }
            for (uint256 i; i < page.length; ++i) {
                grown[rows.length + i] = page[i];
            }
            rows = grown;
            if (page.length < PAGE) break;
        }

        address[] memory wallets = new address[](rows.length);
        uint256 total;
        for (uint256 i; i < rows.length; ++i) {
            uint8 counted = registry.claimsOf(rows[i].wallet);
            if (rows[i].allocations != counted) {
                revert AllocationMismatch(rows[i].wallet, rows[i].allocations, counted);
            }
            wallets[i] = rows[i].wallet;
            total += rows[i].allocations;
        }
        LibSort.sort(wallets);
        for (uint256 i = 1; i < wallets.length; ++i) {
            if (wallets[i] == wallets[i - 1]) revert DuplicateWallet(wallets[i]);
        }
        uint256 claimed = registry.TOTAL_SPOTS() - registry.spotsLeft();
        if (total != claimed) revert TotalMismatch(total, claimed);
    }
}
