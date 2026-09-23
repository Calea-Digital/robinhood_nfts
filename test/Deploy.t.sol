// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {MintABear} from "../src/MintABear.sol";
import {WhitelistClaim} from "../src/WhitelistClaim.sol";
import {Activation} from "../src/Activation.sol";
import {DirectBurnAdapter} from "../src/DirectBurnAdapter.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {MockMNTD} from "./mocks/MockMNTD.sol";

/// @dev OPS-2. The deploy functions run against a fresh local chain; every call the deployer makes
///      after construction is recorded and compared with the listed order.
contract DeployTest is Test {
    Deploy internal deployer;
    MockMNTD internal mntd;

    string internal constant EXAMPLE = "script/config/example.json";
    address internal admin = makeAddr("mintAdmin");
    address internal signer = makeAddr("eligibilitySigner");

    function setUp() public {
        deployer = new Deploy();
        mntd = new MockMNTD(18);
    }

    function _config() internal view returns (Deploy.Config memory cfg) {
        cfg.name = "MintABear";
        cfg.symbol = "BEAR";
        cfg.admin = admin;
        cfg.signer = signer;
        cfg.openAt = 1_791_244_800; // 6 October 2026
        cfg.closeAt = 1_792_972_799; // 25 October 2026, end of day
        cfg.whitelistStageAt = 1_793_232_000; // 29 October 2026
        cfg.mntd = address(mntd);
        cfg.mntdDecimals = 18;
        cfg.thresholdsWhole = [uint128(1_666), 3_333, 8_333, 16_666, 41_666];
        cfg.weights = [uint16(100), 110, 125, 145, 170, 200];
    }

    /// @dev The calls and creations the deployer itself made, in order; its reads are left out.
    function _writes(VmSafe.AccountAccess[] memory accesses) internal view returns (bytes4[] memory out) {
        uint256 n;
        for (uint256 i; i < accesses.length; ++i) {
            if (_isWrite(accesses[i])) ++n;
        }
        out = new bytes4[](n);
        n = 0;
        for (uint256 i; i < accesses.length; ++i) {
            if (!_isWrite(accesses[i])) continue;
            out[n++] = accesses[i].kind == VmSafe.AccountAccessKind.Create ? bytes4(0) : bytes4(accesses[i].data);
        }
    }

    function _isWrite(VmSafe.AccountAccess memory a) internal view returns (bool) {
        return a.accessor == address(deployer)
            && (a.kind == VmSafe.AccountAccessKind.Create || a.kind == VmSafe.AccountAccessKind.Call);
    }

    function test_deploy_correctFromTheFirstBlock() public {
        /* Scenario: OPS-2 — Correct from the first block
           When the deploy script runs on a fresh chain
           Then each contract is created with its constructor arguments in the listed order and is
             never left deployed-but-unconfigured
           And the only address set after construction is Activation's crediter; every other call
             after construction is a listed setting or ownership transfer, in the listed order */
        Deploy.Config memory cfg = _config();

        vm.startStateDiffRecording();
        WhitelistClaim registry = deployer.deployWhitelist(cfg);
        bytes4[] memory calls = _writes(vm.stopAndReturnStateDiff());
        assertEq(calls.length, 1, "WhitelistClaim: construction only");
        assertEq(calls[0], bytes4(0));
        assertEq(registry.owner(), admin);
        assertEq(registry.signer(), signer);
        assertEq(registry.openAt(), cfg.openAt);
        assertEq(registry.closeAt(), cfg.closeAt);

        vm.startStateDiffRecording();
        MintABear bears = deployer.deployCollection(cfg);
        calls = _writes(vm.stopAndReturnStateDiff());
        assertEq(calls.length, 4, "MintABear: construction and three calls");
        assertEq(calls[0], bytes4(0));
        assertEq(calls[1], bears.setMaxSupply.selector);
        assertEq(calls[2], bears.setTransferValidator.selector);
        assertEq(calls[3], bears.transferOwnership.selector);
        assertEq(bears.name(), "MintABear");
        assertEq(bears.symbol(), "BEAR");
        assertEq(bears.maxSupply(), 4444);
        assertEq(bears.getTransferValidator(), deployer.TRANSFER_VALIDATOR_V3());
        vm.prank(admin);
        bears.acceptOwnership();
        assertEq(bears.owner(), admin, "the two-step transfer completes with the admin");

        vm.startStateDiffRecording();
        (Activation activation, DirectBurnAdapter adapter) = deployer.deployActivation(cfg, address(bears));
        calls = _writes(vm.stopAndReturnStateDiff());
        assertEq(calls.length, 5, "Activation and adapter: two constructions and three calls");
        assertEq(calls[0], bytes4(0));
        assertEq(calls[1], bytes4(0));
        assertEq(calls[2], activation.setCrediter.selector, "the one address set after construction");
        assertEq(calls[3], activation.setPaused.selector);
        assertEq(calls[4], activation.transferOwnership.selector);
        assertEq(address(activation.BEARS()), address(bears));
        assertEq(activation.thresholdFor(1), 1_666 * 1e18);
        assertEq(activation.thresholdFor(5), 41_666 * 1e18);
        assertEq(activation.weightFor(5), 200);
        assertEq(address(adapter.MNTD()), address(mntd));
        assertEq(address(adapter.ACTIVATION()), address(activation));
        assertEq(activation.crediter(), address(adapter));
        assertTrue(activation.paused(), "paused until the switch-on date");
        assertEq(activation.owner(), admin);
    }

    function test_deployWhitelist_refusesACloseTooNearTheStage() public {
        /* Scenario:
           Given a campaign that closes less than 48 hours before the whitelist stage
           When the whitelist is deployed
           Then it reverts with CloseTooLate; exactly 48 hours passes */
        Deploy.Config memory cfg = _config();
        cfg.whitelistStageAt = uint256(cfg.closeAt) + 48 hours - 1;
        vm.expectRevert(abi.encodeWithSelector(Deploy.CloseTooLate.selector, cfg.closeAt, cfg.whitelistStageAt));
        deployer.deployWhitelist(cfg);

        cfg.whitelistStageAt = uint256(cfg.closeAt) + 48 hours;
        deployer.deployWhitelist(cfg);
    }

    function test_deploy_refusesMissingAddresses() public {
        /* Scenario:
           Given a config with the admin, the signer or $MNTD left zero, or no collection address
           When the deployment that needs it runs
           Then it reverts with MissingAddress naming the field */
        Deploy.Config memory cfg = _config();
        cfg.admin = address(0);
        vm.expectRevert(abi.encodeWithSelector(Deploy.MissingAddress.selector, "admin"));
        deployer.deployWhitelist(cfg);
        vm.expectRevert(abi.encodeWithSelector(Deploy.MissingAddress.selector, "admin"));
        deployer.deployCollection(cfg);
        vm.expectRevert(abi.encodeWithSelector(Deploy.MissingAddress.selector, "admin"));
        deployer.deployActivation(cfg, address(1));

        cfg = _config();
        cfg.signer = address(0);
        vm.expectRevert(abi.encodeWithSelector(Deploy.MissingAddress.selector, "signer"));
        deployer.deployWhitelist(cfg);

        cfg = _config();
        cfg.mntd = address(0);
        vm.expectRevert(abi.encodeWithSelector(Deploy.MissingAddress.selector, "mntd"));
        deployer.deployActivation(cfg, address(1));

        vm.expectRevert(abi.encodeWithSelector(Deploy.MissingAddress.selector, "bears"));
        deployer.deployActivation(_config(), address(0));
    }

    function test_deployActivation_checksDecimalsAndScales() public {
        /* Scenario:
           Given $MNTD reporting 6 decimals
           When Activation is deployed with a config written for 18, and then for 6
           Then the first reverts with DecimalsMismatch and the second scales the thresholds by 10^6 */
        MockMNTD six = new MockMNTD(6);
        MintABear bears = deployer.deployCollection(_config());
        Deploy.Config memory cfg = _config();
        cfg.mntd = address(six);
        vm.expectRevert(abi.encodeWithSelector(Deploy.DecimalsMismatch.selector, 18, 6));
        deployer.deployActivation(cfg, address(bears));

        cfg.mntdDecimals = 6;
        (Activation activation,) = deployer.deployActivation(cfg, address(bears));
        assertEq(activation.thresholdFor(1), 1_666 * 1e6);
        assertEq(activation.thresholdFor(5), 41_666 * 1e6);
    }

    function test_scaledThresholds_refusesAnOverflow() public {
        /* Scenario:
           Given decimals so large a scaled threshold does not fit uint128
           When the thresholds are scaled
           Then it reverts rather than truncating */
        Deploy.Config memory cfg = _config();
        cfg.mntdDecimals = 36;
        vm.expectRevert(SafeCastLib.Overflow.selector);
        deployer.scaledThresholds(cfg);
    }

    function test_loadConfig_readsTheTemplate() public view {
        /* Scenario:
           Given script/config/example.json
           When it is loaded
           Then every field reads as written */
        Deploy.Config memory cfg = deployer.loadConfig(EXAMPLE);
        assertEq(cfg.name, "MintABear");
        assertEq(cfg.symbol, "BEAR");
        assertEq(cfg.admin, 0x00000000000000000000000000000000000a0001);
        assertEq(cfg.signer, 0x00000000000000000000000000000000000A0002);
        assertEq(cfg.openAt, 1_791_244_800);
        assertEq(cfg.closeAt, 1_792_972_799);
        assertEq(cfg.whitelistStageAt, 1_793_232_000);
        assertEq(cfg.mntd, 0x00000000000000000000000000000000000A0003);
        assertEq(cfg.mntdDecimals, 18);
        assertEq(cfg.thresholdsWhole[0], 1_666);
        assertEq(cfg.thresholdsWhole[4], 41_666);
        assertEq(cfg.weights[0], 100);
        assertEq(cfg.weights[5], 200);
    }

    function test_runEntryPoints_broadcastEachDeployment() public {
        /* Scenario:
           Given the template config, with a $MNTD stand-in at its address
           When runWhitelist, runCollection and runActivation are called in turn
           Then each deploys its contracts configured as listed */
        vm.etch(0x00000000000000000000000000000000000A0003, address(mntd).code);

        WhitelistClaim registry = deployer.runWhitelist(EXAMPLE);
        assertEq(registry.owner(), 0x00000000000000000000000000000000000a0001);

        MintABear bears = deployer.runCollection(EXAMPLE);
        assertEq(bears.maxSupply(), 4444);

        (Activation activation, DirectBurnAdapter adapter) = deployer.runActivation(EXAMPLE, address(bears));
        assertEq(activation.crediter(), address(adapter));
        assertTrue(activation.paused());
        assertEq(activation.owner(), 0x00000000000000000000000000000000000a0001);
    }
}
