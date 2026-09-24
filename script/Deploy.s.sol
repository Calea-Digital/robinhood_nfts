// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Script, console2} from "forge-std/Script.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {MintABear} from "../src/MintABear.sol";
import {WhitelistClaim} from "../src/WhitelistClaim.sol";
import {Activation} from "../src/Activation.sol";

/**
 * @title  Deploy
 * @notice Deploys the tranche-1 contracts on Robinhood Chain in the order OPS-2 lists, each with
 *         every address it needs as a constructor argument. Three entry points, because each
 *         contract is deployed before the page that depends on it and the three pages open at
 *         different times:
 *
 *             forge script script/Deploy.s.sol --rpc-url $RPC --broadcast --verify --verifier sourcify --sig "runWhitelist(string)"  script/config/<chain>.json
 *             forge script script/Deploy.s.sol --rpc-url $RPC --broadcast --verify --verifier sourcify --sig "runCollection(string)" script/config/<chain>.json
 *             forge script script/Deploy.s.sol --rpc-url $RPC --broadcast --verify --verifier sourcify --sig "runActivation(string,address)" script/config/<chain>.json $BEARS
 *
 *         `--verify --verifier sourcify` verifies each created contract as it is broadcast (OPS-3);
 *         `script/verify.sh <chainId>` retries and checks afterwards.
 *
 *         No address is set after construction; every call after it is a listed setting
 *         (`setMaxSupply`, `setTransferValidator`, `setPaused(true)`) or an ownership transfer. `MintABear`'s transfer is two-step: MINT's admin completes it with
 *         `acceptOwnership`, then Iñigo sets provenance, `baseURI` and royalties in Studio.
 *         Values still open with MINT — the admin and signer (CQ-12), the campaign dates (CQ-1),
 *         $MNTD's address (CQ-2) — come from the config file; nothing here assumes them. `Activation`
 *         reads $MNTD's `decimals` itself and scales the whole-token thresholds.
 */
contract Deploy is Script {
    /// @notice Canonical SeaDrop on Robinhood Chain (verified 2026-09-10).
    address public constant SEADROP = 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5;

    /// @notice Limit Break transfer validator V3 on Robinhood Chain (verified 2026-09-15; COL-7).
    address public constant TRANSFER_VALIDATOR_V3 = 0x721C002B0059009a671D00aD1700c9748146cd1B;

    /// @notice The collection's supply; `maxSupply` is set to exactly this (COL-2).
    uint256 public constant MAX_SUPPLY = 4444;

    /// @notice The least time between the campaign's close and the whitelist stage (WL-5).
    uint256 public constant CLOSE_TO_STAGE = 48 hours;

    /// @notice Everything the three deployments read, from `script/config/<chain>.json`.
    struct Config {
        string name;
        string symbol;
        address admin;
        address signer;
        uint40 openAt;
        uint40 closeAt;
        uint256 whitelistStageAt;
        address mntd;
        uint128[5] thresholdsWhole;
        uint16[6] weights;
    }

    /// @notice A required address is zero.
    error MissingAddress(string field);

    /// @notice The campaign closes less than 48 hours before the whitelist stage.
    error CloseTooLate(uint256 closeAt, uint256 whitelistStageAt);

    /// @notice The address given as the collection is not a MintABear.
    error NotTheCollection(address bears);

    /// @notice A config array has the wrong number of entries.
    error ConfigLength(string field);

    function runWhitelist(string memory path) external returns (WhitelistClaim registry) {
        Config memory cfg = loadConfig(path);
        vm.startBroadcast();
        registry = deployWhitelist(cfg);
        vm.stopBroadcast();
        console2.log("WhitelistClaim", address(registry));
    }

    function runCollection(string memory path) external returns (MintABear bears) {
        Config memory cfg = loadConfig(path);
        vm.startBroadcast();
        bears = deployCollection(cfg);
        vm.stopBroadcast();
        console2.log("MintABear", address(bears));
    }

    function runActivation(string memory path, address bears) external returns (Activation activation) {
        Config memory cfg = loadConfig(path);
        vm.startBroadcast();
        activation = deployActivation(cfg, bears);
        vm.stopBroadcast();
        console2.log("Activation", address(activation));
    }

    /**
     * @notice `WhitelistClaim(owner, signer, openAt, closeAt)` with MINT's admin as owner, before
     *         the campaign opens. Refuses a close less than 48 hours before the whitelist stage.
     */
    function deployWhitelist(Config memory cfg) public returns (WhitelistClaim registry) {
        _require(cfg.admin, "admin");
        _require(cfg.signer, "signer");
        if (uint256(cfg.closeAt) + CLOSE_TO_STAGE > cfg.whitelistStageAt) {
            revert CloseTooLate(cfg.closeAt, cfg.whitelistStageAt);
        }
        registry = new WhitelistClaim(cfg.admin, cfg.signer, cfg.openAt, cfg.closeAt);
    }

    /**
     * @notice `MintABear(name, symbol, [SeaDrop])` → `setMaxSupply(4444)` →
     *         `setTransferValidator(V3)` → the first half of the two-step transfer to MINT's admin.
     */
    function deployCollection(Config memory cfg) public returns (MintABear bears) {
        _require(cfg.admin, "admin");
        address[] memory allowed = new address[](1);
        allowed[0] = SEADROP;
        bears = new MintABear(cfg.name, cfg.symbol, allowed);
        bears.setMaxSupply(MAX_SUPPLY);
        bears.setTransferValidator(TRANSFER_VALIDATOR_V3);
        bears.transferOwnership(cfg.admin);
    }

    /**
     * @notice `Activation(bears, mntd, thresholdsWhole, weights)` → `setPaused(true)` until the
     *         switch-on date → ownership to MINT's admin. `Activation` reads $MNTD's `decimals`
     *         and scales the thresholds itself. Every value is immutable, so the collection is
     *         checked first and the scaled values are printed for the runbook's read-back.
     */
    function deployActivation(Config memory cfg, address bears) public returns (Activation activation) {
        _require(cfg.admin, "admin");
        _require(cfg.mntd, "mntd");
        _require(bears, "bears");
        _requireCollection(bears);
        activation = new Activation(bears, cfg.mntd, cfg.thresholdsWhole, cfg.weights);
        activation.setPaused(true);
        activation.transferOwnership(cfg.admin);

        console2.log("Activation DECIMALS", activation.DECIMALS());
        for (uint8 k = 1; k <= 5; ++k) {
            console2.log("thresholdFor", k, activation.thresholdFor(k));
        }
        for (uint8 k; k <= 5; ++k) {
            console2.log("weightFor", k, activation.weightFor(k));
        }
    }

    /// @notice Reads the config file for one chain.
    function loadConfig(string memory path) public view returns (Config memory cfg) {
        string memory json = vm.readFile(path);
        cfg.name = vm.parseJsonString(json, ".name");
        cfg.symbol = vm.parseJsonString(json, ".symbol");
        cfg.admin = vm.parseJsonAddress(json, ".admin");
        cfg.signer = vm.parseJsonAddress(json, ".signer");
        cfg.openAt = SafeCastLib.toUint40(vm.parseJsonUint(json, ".openAt"));
        cfg.closeAt = SafeCastLib.toUint40(vm.parseJsonUint(json, ".closeAt"));
        cfg.whitelistStageAt = vm.parseJsonUint(json, ".whitelistStageAt");
        cfg.mntd = vm.parseJsonAddress(json, ".mntd");
        uint256[] memory t = vm.parseJsonUintArray(json, ".thresholdsWhole");
        uint256[] memory w = vm.parseJsonUintArray(json, ".weights");
        if (t.length != 5) revert ConfigLength("thresholdsWhole");
        if (w.length != 6) revert ConfigLength("weights");
        for (uint256 i; i < 5; ++i) {
            cfg.thresholdsWhole[i] = SafeCastLib.toUint128(t[i]);
        }
        for (uint256 i; i < 6; ++i) {
            cfg.weights[i] = SafeCastLib.toUint16(w[i]);
        }
    }

    function _require(address value, string memory field) private pure {
        if (value == address(0)) revert MissingAddress(field);
    }

    /// @dev `Activation` never calls the collection at construction, so a wrong address would be
    ///      fixed in it for good: refuse anything that does not answer `MAX_BEARS` with 4,444.
    function _requireCollection(address bears) private view {
        if (bears.code.length == 0) revert NotTheCollection(bears);
        try MintABear(bears).MAX_BEARS() returns (uint256 maxBears) {
            if (maxBears != MAX_SUPPLY) revert NotTheCollection(bears);
        } catch {
            revert NotTheCollection(bears);
        }
    }
}
