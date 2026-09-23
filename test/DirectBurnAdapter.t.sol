// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {VmSafe} from "forge-std/Vm.sol";

import {BaseTest} from "./BaseTest.t.sol";
import {Activation} from "../src/Activation.sol";
import {DirectBurnAdapter} from "../src/DirectBurnAdapter.sol";
import {MockMNTD} from "./mocks/MockMNTD.sol";
import {HookedMNTD} from "./mocks/HookedMNTD.sol";
import {ReentrantHolder} from "./mocks/ReentrantHolder.sol";

/// @dev Shared fixture: the adapter over a $MNTD stand-in, set as `Activation`'s crediter, and
///      alice holding bear 1 with 50,000 $MNTD approved to the adapter.
abstract contract DirectBurnAdapterBase is BaseTest {
    MockMNTD internal mntd;
    DirectBurnAdapter internal adapter;

    event BurnedForBear(bytes32 indexed ref, uint256 indexed tokenId, address indexed burner, uint256 amount);
    event BearActivated(
        uint256 indexed tokenId,
        address indexed burner,
        uint8 previousLevel,
        uint8 newLevel,
        uint256 amount,
        uint256 cumulative,
        bytes32 indexed ref
    );

    function setUp() public virtual override {
        super.setUp();
        mntd = new MockMNTD(18);
        adapter = new DirectBurnAdapter(address(mntd), address(activation));
        activation.setCrediter(address(adapter));

        _mint(alice, 1);
        _fund(alice, 50_000);
    }

    function _fund(address who, uint256 whole) internal {
        mntd.mint(who, whole * UNIT);
        vm.prank(who);
        mntd.approve(address(adapter), type(uint256).max);
    }

    function _burn(address who, uint256 tokenId, uint128 amount) internal {
        vm.prank(who);
        adapter.burn(tokenId, amount);
    }
}

/// @dev ACT-7. The burn and the credit happen in one transaction, through the one crediter.
contract DirectBurnAdapterTest is DirectBurnAdapterBase {
    function test_burn_burnsAndCreditsInOneTransaction() public {
        /* Scenario: ACT-7 — Burn and credit in one transaction
           Given the holder has approved the adapter on $MNTD
           When the holder calls burn(tokenId, amount) for a bear below level 5
           Then burnFrom and credit execute in one transaction and BurnedForBear is emitted
           And a call by a non-owner reverts with NotOwner */
        uint256 supplyBefore = mntd.totalSupply();

        vm.expectEmit(true, true, true, true, address(activation));
        emit BearActivated(1, alice, 0, 2, 3_333 * UNIT, 3_333 * UNIT, bytes32(uint256(1)));
        vm.expectEmit(true, true, true, true, address(adapter));
        emit BurnedForBear(bytes32(uint256(1)), 1, alice, 3_333 * UNIT);
        _burn(alice, 1, 3_333 * UNIT);

        assertEq(mntd.balanceOf(alice), (50_000 - 3_333) * UNIT, "burned from the holder");
        assertEq(mntd.totalSupply(), supplyBefore - 3_333 * UNIT, "supply reduced");
        assertEq(activation.levelOf(1), 2, "credited");
        assertEq(activation.cumulativeOf(1), 3_333 * UNIT);

        _fund(bob, 10_000);
        vm.expectRevert(DirectBurnAdapter.NotOwner.selector);
        _burn(bob, 1, UNIT);
        assertEq(mntd.balanceOf(bob), 10_000 * UNIT, "nothing burned for the non-owner");
    }

    function test_burn_byAnApprovedOperator_reverts() public {
        /* Scenario:
           Given bob approved by alice to move her bear, with $MNTD of his own
           When bob burns for alice's bear
           Then it reverts with NotOwner: only the holder burns for a bear */
        vm.prank(alice);
        bears.setApprovalForAll(bob, true);
        _fund(bob, 10_000);
        vm.expectRevert(DirectBurnAdapter.NotOwner.selector);
        _burn(bob, 1, UNIT);
    }

    function test_burn_atLevelFive_reverts() public {
        /* Scenario:
           Given a bear at level 5
           When its holder burns again
           Then it reverts with AlreadyAtMaxLevel and nothing is burned */
        _burn(alice, 1, 41_666 * UNIT);
        uint256 balance = mntd.balanceOf(alice);
        vm.expectRevert(DirectBurnAdapter.AlreadyAtMaxLevel.selector);
        _burn(alice, 1, UNIT);
        assertEq(mntd.balanceOf(alice), balance);
    }

    function test_burn_pastLevelFive_revertsWithOvershoot_andTheExactRemainderPasses() public {
        /* Scenario:
           Given a bear credited 1,000
           When its holder burns one base unit more than costToReach(id, 5), then exactly that
           Then the first reverts with Overshoot and the second lands the bear on level 5 */
        _burn(alice, 1, 1_000 * UNIT);
        uint128 remainder = activation.costToReach(1, 5);
        vm.expectRevert(DirectBurnAdapter.Overshoot.selector);
        _burn(alice, 1, remainder + 1);
        _burn(alice, 1, remainder);
        assertEq(activation.levelOf(1), 5);
        assertEq(activation.cumulativeOf(1), 41_666 * UNIT);
    }

    function test_burn_whilePaused_burnsNothing() public {
        /* Scenario:
           Given Activation paused
           When the holder burns
           Then it reverts with ContractPaused and no $MNTD is burned */
        activation.setPaused(true);
        vm.expectRevert(Activation.ContractPaused.selector);
        _burn(alice, 1, UNIT);
        assertEq(mntd.balanceOf(alice), 50_000 * UNIT);
        assertEq(adapter.burnCount(), 0);
    }

    function test_burn_zeroAmount_reverts() public {
        /* Scenario:
           Given a burn of zero
           When the holder sends it
           Then Activation's ZeroAmount undoes it */
        vm.expectRevert(Activation.ZeroAmount.selector);
        _burn(alice, 1, 0);
    }

    function test_burn_withoutEnoughAllowanceOrBalance_revertsWhole() public {
        /* Scenario:
           Given a holder who has not approved the adapter, and one with too little $MNTD
           When each burns
           Then the token's refusal undoes the credit too */
        _mint(bob, 1);
        mntd.mint(bob, 10_000 * UNIT);
        vm.expectRevert(MockMNTD.InsufficientAllowance.selector);
        _burn(bob, 2, UNIT);
        assertEq(activation.cumulativeOf(2), 0);

        vm.prank(bob);
        mntd.approve(address(adapter), type(uint256).max);
        vm.expectRevert(MockMNTD.InsufficientBalance.selector);
        _burn(bob, 2, 20_000 * UNIT);
        assertEq(activation.cumulativeOf(2), 0);
    }

    function test_burn_refsCountUpPerAdapter() public {
        /* Scenario:
           Given two burns through the adapter
           When their events and burnCount are read
           Then the refs are 1 and 2 and burnCount is 2 */
        vm.expectEmit(true, true, true, true, address(adapter));
        emit BurnedForBear(bytes32(uint256(1)), 1, alice, 100 * UNIT);
        _burn(alice, 1, 100 * UNIT);
        vm.expectEmit(true, true, true, true, address(adapter));
        emit BurnedForBear(bytes32(uint256(2)), 1, alice, 200 * UNIT);
        _burn(alice, 1, 200 * UNIT);
        assertEq(adapter.burnCount(), 2);
    }

    function test_burn_afterTheCrediterMoves_reverts() public {
        /* Scenario:
           Given the owner has set another crediter
           When the holder burns through this adapter
           Then Activation refuses the credit with NotCrediter and nothing is burned */
        activation.setCrediter(makeAddr("nextAdapter"));
        vm.expectRevert(Activation.NotCrediter.selector);
        _burn(alice, 1, UNIT);
        assertEq(mntd.balanceOf(alice), 50_000 * UNIT);
    }

    function test_reads_andConstruction() public {
        /* Scenario:
           Given a deployed adapter
           When MNTD, ACTIVATION and burnCount are read, and a deployment with a zero address is tried
           Then they return the token, Activation and 0, and the deployment reverts with ZeroAddress */
        assertEq(address(adapter.MNTD()), address(mntd));
        assertEq(address(adapter.ACTIVATION()), address(activation));
        assertEq(adapter.burnCount(), 0);

        vm.expectRevert(DirectBurnAdapter.ZeroAddress.selector);
        new DirectBurnAdapter(address(0), address(activation));
        vm.expectRevert(DirectBurnAdapter.ZeroAddress.selector);
        new DirectBurnAdapter(address(mntd), address(0));
    }

    function test_adapter_hasNoOwnerAndNoSettings() public {
        /* Scenario:
           Given the adapter
           When owner() or any setter is called
           Then none exists */
        string[4] memory signatures = [
            "owner()", "setMNTD(address)", "setActivation(address)", "transferOwnership(address)"
        ];
        for (uint256 i; i < signatures.length; ++i) {
            (bool ok,) =
                address(adapter).call(abi.encodePacked(bytes4(keccak256(bytes(signatures[i]))), abi.encode(alice)));
            assertFalse(ok, signatures[i]);
        }
    }
}

/// @dev A hostile token that calls back into the holder from inside `burnFrom`. Because the credit
///      is recorded first, the nested `burn` sees the raised cumulative: the overshoot guard holds,
///      and each nested credit needs a burn of its own.
contract DirectBurnAdapterHostileTokenTest is BaseTest {
    HookedMNTD internal hooked;
    DirectBurnAdapter internal adapter;
    ReentrantHolder internal holder;

    function setUp() public override {
        super.setUp();
        hooked = new HookedMNTD();
        adapter = new DirectBurnAdapter(address(hooked), address(activation));
        activation.setCrediter(address(adapter));
        holder = new ReentrantHolder(adapter, hooked);
        _mint(address(holder), 1);
        hooked.mint(address(holder), 100_000 * UNIT);
    }

    function test_nestedBurn_cannotOvershoot() public {
        /* Scenario:
           Given a holder 10 $MNTD short of level 5 after its outer burn is recorded
           When the token calls back and the holder burns 20 more from inside burnFrom
           Then the nested burn reverts with Overshoot, undoing the whole transaction */
        vm.expectRevert(DirectBurnAdapter.Overshoot.selector);
        holder.burnTwice(1, 41_656 * UNIT, 20 * UNIT);
        assertEq(activation.cumulativeOf(1), 0);
        assertEq(hooked.balanceOf(address(holder)), 100_000 * UNIT);
    }

    function test_nestedBurn_withinTheLimit_isBurnedAndCreditedSeparately() public {
        /* Scenario:
           Given the same holder
           When the nested burn is 10, exactly what level 5 still needs
           Then both burns are credited and both amounts are burned: no credit without its burn */
        holder.burnTwice(1, 41_656 * UNIT, 10 * UNIT);
        assertEq(activation.levelOf(1), 5);
        assertEq(activation.cumulativeOf(1), 41_666 * UNIT);
        assertEq(hooked.balanceOf(address(holder)), (100_000 - 41_666) * UNIT);
        assertEq(adapter.burnCount(), 2);
    }
}

/// @dev ACT-8. The adapter refuses any amount beyond what level 5 needs, so no $MNTD is destroyed
///      for nothing; the portal sizes each burn with `costToReach`.
contract DirectBurnAdapterOvershootTest is DirectBurnAdapterBase {
    function test_burn_pastLevelFive_burnsNothing() public {
        /* Scenario: ACT-8 — Nothing is burned for nothing
           Given a bear whose costToReach(id, 5) reads x
           When the holder calls burn(id, x + 1)
           Then it reverts with Overshoot and no $MNTD is burned */
        _burn(alice, 1, 2_000 * UNIT);
        uint128 x = activation.costToReach(1, 5);
        assertEq(x, (41_666 - 2_000) * UNIT);
        uint256 balance = mntd.balanceOf(alice);
        uint256 supply = mntd.totalSupply();
        uint128 cumulative = activation.cumulativeOf(1);

        vm.expectRevert(DirectBurnAdapter.Overshoot.selector);
        _burn(alice, 1, x + 1);

        assertEq(mntd.balanceOf(alice), balance, "no $MNTD burned");
        assertEq(mntd.totalSupply(), supply);
        assertEq(activation.cumulativeOf(1), cumulative, "nothing credited");
    }

    function test_costToReach_sizesABurnToEachLevelExactly() public {
        /* Scenario:
           Given an unactivated bear
           When the holder burns costToReach(id, k) for k = 1 to 5 in turn
           Then each burn lands the bear exactly on level k, and costToReach(id, k) then reads 0 */
        for (uint8 k = 1; k <= 5; ++k) {
            uint128 cost = activation.costToReach(1, k);
            _burn(alice, 1, cost);
            assertEq(activation.levelOf(1), k);
            assertEq(activation.cumulativeOf(1), activation.thresholdFor(k));
            assertEq(activation.costToReach(1, k), 0);
        }
        assertEq(mntd.balanceOf(alice), (50_000 - 41_666) * UNIT, "exactly 41,666 burned in all");
    }
}

/// @dev ACT-11 through the adapter: burns stay closed while `Activation` is paused, and the
///      mainnet rehearsal runs in a window the owner opens and closes again.
contract DirectBurnAdapterPauseTest is DirectBurnAdapterBase {
    function test_rehearsalWindow_opensAndClosesBurns() public {
        /* Scenario:
           Given Activation paused from deployment
           When a holder burns, the owner opens the window, the holder burns, and the owner closes it
           Then only the burn inside the window is burned and credited */
        activation.setPaused(true);
        vm.expectRevert(Activation.ContractPaused.selector);
        _burn(alice, 1, UNIT);

        activation.setPaused(false);
        _burn(alice, 1, 1_666 * UNIT);
        activation.setPaused(true);

        vm.expectRevert(Activation.ContractPaused.selector);
        _burn(alice, 1, UNIT);
        assertEq(mntd.balanceOf(alice), (50_000 - 1_666) * UNIT);
        assertEq(activation.levelOf(1), 1);
        assertEq(adapter.burnCount(), 1);
    }
}

/// @dev ACT-13 for the adapter: `BurnedForBear(ref, tokenId, burner, amount)` in the recorded logs.
contract DirectBurnAdapterEventsTest is DirectBurnAdapterBase {
    function test_burnedForBear_carriesTheDocumentedArguments() public {
        /* Scenario:
           Given a holder's burn through the adapter
           When the logs are read
           Then BurnedForBear(ref, tokenId, burner, amount) follows BearActivated, with ref the
             adapter's burn number */
        vm.recordLogs();
        _burn(alice, 1, 500 * UNIT);
        VmSafe.Log[] memory logs = vm.getRecordedLogs();

        VmSafe.Log memory burned;
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics[0] == keccak256("BurnedForBear(bytes32,uint256,address,uint256)")) {
                burned = logs[i];
                ++found;
                assertEq(
                    logs[i - 1].topics[0],
                    keccak256("BearActivated(uint256,address,uint8,uint8,uint256,uint256,bytes32)"),
                    "after the credit"
                );
            }
        }
        assertEq(found, 1);
        assertEq(burned.emitter, address(adapter));
        assertEq(burned.topics[1], bytes32(uint256(1)), "ref");
        assertEq(uint256(burned.topics[2]), 1, "tokenId");
        assertEq(address(uint160(uint256(burned.topics[3]))), alice, "burner");
        assertEq(abi.decode(burned.data, (uint256)), 500 * UNIT, "amount");
    }
}

/// @dev ACT-14. Every listed read answers on the deployed pair, for a bear credited through the
///      adapter.
contract ActivationReadsTest is DirectBurnAdapterBase {
    function test_everyReadAnswers() public {
        /* Scenario: ACT-14 — Every read answers
           When every listed read is called for a credited bear
           Then each returns without reverting
           And BEARS, MNTD and ACTIVATION return the deployed addresses */
        _burn(alice, 1, 3_333 * UNIT);
        vm.prank(alice);
        activation.linkBear(1);

        assertEq(activation.levelOf(1), 2);
        assertEq(activation.cumulativeOf(1), 3_333 * UNIT);
        assertEq(activation.lifetimeBurned(1), 3_333 * UNIT);
        assertEq(activation.weightOf(1), 125);
        assertEq(activation.weightFor(2), 125);
        assertEq(activation.thresholdFor(3), 8_333 * UNIT);
        assertEq(activation.costToReach(1, 3), 5_000 * UNIT);
        (uint256 tokenId, uint8 level) = activation.linkOf(alice);
        assertEq(tokenId, 1);
        assertEq(level, 2);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        Activation.BearState[] memory rows = activation.snapshot(ids);
        assertEq(rows[0].owner, alice);
        assertEq(rows[0].level, 2);
        assertEq(rows[0].weight, 125);
        assertFalse(activation.paused());
        assertEq(activation.crediter(), address(adapter));
        assertEq(address(activation.BEARS()), address(bears));

        assertEq(address(adapter.MNTD()), address(mntd));
        assertEq(address(adapter.ACTIVATION()), address(activation));
        assertEq(adapter.burnCount(), 1);
    }
}
