// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {MintABear} from "../src/MintABear.sol";
import {WhitelistClaim} from "../src/WhitelistClaim.sol";
import {Activation} from "../src/Activation.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {MockMNTD} from "./mocks/MockMNTD.sol";
import {INonFungibleSeaDropToken} from "seadrop/interfaces/INonFungibleSeaDropToken.sol";

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
           And no address is set after construction; every call after construction is a listed
             setting or ownership transfer, in the listed order */
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
        Activation activation = deployer.deployActivation(cfg, address(bears));
        calls = _writes(vm.stopAndReturnStateDiff());
        assertEq(calls.length, 3, "Activation: construction and two calls, no address set");
        assertEq(calls[0], bytes4(0));
        assertEq(calls[1], activation.setPaused.selector);
        assertEq(calls[2], activation.transferOwnership.selector);
        assertEq(address(activation.BEARS()), address(bears));
        assertEq(address(activation.MNTD()), address(mntd));
        assertEq(activation.thresholdFor(1), 1_666 * 1e18);
        assertEq(activation.thresholdFor(5), 41_666 * 1e18);
        assertEq(activation.weightFor(5), 200);
        assertTrue(activation.paused(), "paused until the switch-on date");
        assertEq(activation.owner(), admin);
    }

    function test_deployCollection_allowsOnlyCanonicalSeaDrop() public {
        /* Scenario:
           Given the collection the deploy script creates
           When canonical SeaDrop and then any other address call the mint path
           Then SeaDrop mints and the other is refused with OnlyAllowedSeaDrop, so the collection is
             deployed with canonical SeaDrop as its only allowed minter (COL-1) */
        MintABear bears = deployer.deployCollection(_config());
        address alice = makeAddr("alice");

        vm.prank(deployer.SEADROP());
        bears.mintSeaDrop(alice, 1);
        assertEq(bears.ownerOf(1), alice);

        vm.prank(makeAddr("anotherMinter"));
        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        bears.mintSeaDrop(alice, 1);
        assertEq(bears.totalSupply(), 1, "nothing more minted");
    }

    function test_deployCollection_touchesNoSeaDropState() public {
        /* Scenario:
           Given the collection the deploy script creates
           When every account the deployment touches is recorded
           Then canonical SeaDrop is never called, so no drop, signer, payer, payout or fee
             recipient is configured before MINT's admin takes over (COL-10) */
        vm.startStateDiffRecording();
        deployer.deployCollection(_config());
        VmSafe.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();
        for (uint256 i; i < accesses.length; ++i) {
            assertTrue(accesses[i].account != deployer.SEADROP(), "SeaDrop touched");
        }
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

    function test_deployActivation_refusesAnAddressThatIsNotTheCollection() public {
        /* Scenario:
           Given a collection address that is a wallet, or a contract other than MintABear
           When Activation is deployed with it
           Then it reverts with NotTheCollection before anything is created, since the address
             would be immutable in Activation */
        address wallet = makeAddr("notACollection");
        vm.expectRevert(abi.encodeWithSelector(Deploy.NotTheCollection.selector, wallet));
        deployer.deployActivation(_config(), wallet);

        vm.expectRevert(abi.encodeWithSelector(Deploy.NotTheCollection.selector, address(mntd)));
        deployer.deployActivation(_config(), address(mntd));

        StubCollection stub = new StubCollection();
        vm.expectRevert(abi.encodeWithSelector(Deploy.NotTheCollection.selector, address(stub)));
        deployer.deployActivation(_config(), address(stub));
    }

    function test_loadConfig_refusesArraysOfTheWrongLength() public {
        /* Scenario:
           Given a config whose thresholdsWhole has six entries, or whose weights has five
           When it is loaded
           Then it reverts with ConfigLength naming the field, rather than ignoring or missing one */
        string memory json = vm.readFile(EXAMPLE);
        vm.createDir("exports", true);
        string memory path = "exports/test-deploy-config.json";

        vm.writeFile(path, _replace(json, "[1666, 3333, 8333, 16666, 41666]", "[1666, 3333, 8333, 16666, 41666, 1]"));
        vm.expectRevert(abi.encodeWithSelector(Deploy.ConfigLength.selector, "thresholdsWhole"));
        deployer.loadConfig(path);

        vm.writeFile(path, _replace(json, "[100, 110, 125, 145, 170, 200]", "[100, 110, 125, 145, 170]"));
        vm.expectRevert(abi.encodeWithSelector(Deploy.ConfigLength.selector, "weights"));
        deployer.loadConfig(path);
        vm.removeFile(path);
    }

    /// @dev `json` with the one occurrence of `from` replaced by `to`.
    function _replace(string memory json, string memory from, string memory to) internal pure returns (string memory) {
        bytes memory s = bytes(json);
        bytes memory f = bytes(from);
        for (uint256 i; i + f.length <= s.length; ++i) {
            if (keccak256(_slice(s, i, f.length)) == keccak256(f)) {
                return
                    string.concat(string(_slice(s, 0, i)), to, string(_slice(s, i + f.length, s.length - i - f.length)));
            }
        }
        revert("pattern not found");
    }

    function _slice(bytes memory s, uint256 start, uint256 len) internal pure returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i; i < len; ++i) {
            out[i] = s[start + i];
        }
    }

    function test_deployActivation_scalesByTheTokensDecimals() public {
        /* Scenario:
           Given $MNTD reporting 6 decimals
           When Activation is deployed from the whole-token config
           Then Activation reads the decimals itself and scales the thresholds by 10^6 */
        MockMNTD six = new MockMNTD(6);
        MintABear bears = deployer.deployCollection(_config());
        Deploy.Config memory cfg = _config();
        cfg.mntd = address(six);
        Activation activation = deployer.deployActivation(cfg, address(bears));
        assertEq(activation.DECIMALS(), 6);
        assertEq(activation.thresholdFor(1), 1_666 * 1e6);
        assertEq(activation.thresholdFor(5), 41_666 * 1e6);
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

        Activation activation = deployer.runActivation(EXAMPLE, address(bears));
        assertEq(address(activation.MNTD()), 0x00000000000000000000000000000000000A0003);
        assertTrue(activation.paused());
        assertEq(activation.owner(), 0x00000000000000000000000000000000000a0001);
    }
}

/// @dev A contract that answers `MAX_BEARS` with the wrong supply.
contract StubCollection {
    function MAX_BEARS() external pure returns (uint256) {
        return 10_000;
    }
}
