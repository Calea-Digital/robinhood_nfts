// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {VmSafe} from "forge-std/Vm.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {BaseTest} from "./BaseTest.t.sol";
import {Activation} from "../src/Activation.sol";
import {IMintABear} from "../src/interfaces/IMintABear.sol";
import {IERC721A} from "ERC721A/IERC721A.sol";
import {MockMNTD} from "./mocks/MockMNTD.sol";
import {HookedMNTD} from "./mocks/HookedMNTD.sol";
import {ReentrantHolder} from "./mocks/ReentrantHolder.sol";

/// @dev ACT-1. `Activation` holds one token, $MNTD, and reads only the collection.
contract ActivationOneTokenTest is BaseTest {
    function test_activation_holdsOneToken_andReadsOnlyTheCollection() public {
        /* Scenario: ACT-1 — One token, one collection
           When Activation's code and constructor are inspected
           Then its only calls to $MNTD are decimals in the constructor and burnFrom of the
             caller's own balance in burn, and it moves no other token
           And it reads only MintABear's ownerOf, transferNonce and exists */
        _mint(alice, 1);
        address fresh = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));

        vm.startStateDiffRecording();
        new Activation(address(bears), address(mntd), _thresholds(), _weights());
        Activation act = Activation(fresh);
        mntd.mint(alice, 3_333 * UNIT);
        vm.startPrank(alice);
        mntd.approve(fresh, type(uint256).max);
        act.burn(1, 3_333 * UNIT);
        act.linkBear(1);
        act.unlinkBear();
        vm.stopPrank();
        uint256[] memory ids = new uint256[](3);
        (ids[0], ids[1], ids[2]) = (1, 2, 4445);
        act.snapshot(ids);
        act.weightOf(1);
        act.costToReach(1, 5);
        act.linkOf(alice);
        act.lifetimeBurned(1);
        VmSafe.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();

        uint256 decimalsCalls;
        uint256 burnCalls;
        uint256 reads;
        for (uint256 i; i < accesses.length; ++i) {
            VmSafe.AccountAccess memory a = accesses[i];
            if (a.accessor != fresh) continue;
            // The code-size check solc makes before a call that returns nothing: not a call.
            if (a.kind == VmSafe.AccountAccessKind.Extcodesize) continue;
            if (a.kind == VmSafe.AccountAccessKind.Resume) continue;
            assertEq(a.value, 0, "Activation sends no value");
            bytes4 selector = bytes4(a.data);
            if (a.account == address(mntd)) {
                if (selector == MockMNTD.decimals.selector) {
                    assertTrue(a.kind == VmSafe.AccountAccessKind.StaticCall, "decimals is a read");
                    ++decimalsCalls;
                } else {
                    assertEq(selector, MockMNTD.burnFrom.selector, "the only other call to $MNTD is burnFrom");
                    (address account,) = abi.decode(_args(a.data), (address, uint256));
                    assertEq(account, alice, "of the caller's own balance");
                    ++burnCalls;
                }
                continue;
            }
            assertEq(a.account, address(bears), "Activation calls nothing but the token and the collection");
            assertTrue(a.kind == VmSafe.AccountAccessKind.StaticCall, "and only reads the collection");
            assertTrue(
                selector == IMintABear.ownerOf.selector || selector == IMintABear.transferNonce.selector
                    || selector == IMintABear.exists.selector,
                "through ownerOf, transferNonce and exists only"
            );
            ++reads;
        }
        assertEq(decimalsCalls, 1, "decimals once, in the constructor");
        assertEq(burnCalls, 1, "burnFrom once, in burn");
        assertGt(reads, 0);

        (bool hasCredit,) = fresh.staticcall(abi.encodeWithSignature("crediter()"));
        assertFalse(hasCredit, "no crediter");
    }

    function _args(bytes memory data) internal pure returns (bytes memory args) {
        args = new bytes(data.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = data[i + 4];
        }
    }
}

/// @dev ACT-4 and ACT-7: `burn` — who may call it, what it refuses, what it records and burns.
contract ActivationBurnTest is BaseTest {
    event BearActivated(
        uint256 indexed tokenId,
        address indexed burner,
        uint8 previousLevel,
        uint8 newLevel,
        uint256 amount,
        uint256 cumulative
    );

    function setUp() public override {
        super.setUp();
        _mint(alice, 1);
        _fund(alice, 50_000);
    }

    function _burnAs(address caller, uint128 amount) internal {
        vm.prank(caller);
        activation.burn(1, amount);
    }

    function test_burn_recordsAndBurnsInOneTransaction() public {
        /* Scenario: ACT-7 — Record and burn in one transaction
           Given the holder has approved Activation on $MNTD
           When the holder calls burn(tokenId, amount) for a bear below level 5
           Then the burn is recorded and burnFrom executes in one transaction, and BearActivated is
             emitted
           And a call by a non-owner reverts with NotBearOwner */
        uint256 supply = mntd.totalSupply();
        vm.expectEmit(true, true, false, true, address(activation));
        emit BearActivated(1, alice, 0, 2, 3_333 * UNIT, 3_333 * UNIT);
        _burnAs(alice, 3_333 * UNIT);

        assertEq(activation.cumulativeOf(1), 3_333 * UNIT, "recorded");
        assertEq(activation.levelOf(1), 2);
        assertEq(mntd.balanceOf(alice), (50_000 - 3_333) * UNIT, "burned from the holder");
        assertEq(mntd.totalSupply(), supply - 3_333 * UNIT, "and from the supply");

        _fund(bob, 1_000);
        vm.expectRevert(Activation.NotBearOwner.selector);
        _burnAs(bob, UNIT);
        assertEq(mntd.balanceOf(bob), 1_000 * UNIT, "nothing burned");
    }

    function test_burn_byAnApprovedOperator_reverts() public {
        /* Scenario:
           Given alice approved an operator for all her bears, and the operator holds $MNTD
           When the operator burns for alice's bear
           Then it reverts with NotBearOwner: an approval on the bear does not make a burner */
        vm.prank(alice);
        bears.setApprovalForAll(operator, true);
        _fund(operator, 1_000);
        vm.expectRevert(Activation.NotBearOwner.selector);
        _burnAs(operator, UNIT);
        assertEq(mntd.balanceOf(operator), 1_000 * UNIT);
    }

    function test_burn_accumulatesAcrossBurns() public {
        /* Scenario:
           Given a bear burned for 1,000 and then 666
           When its level is read
           Then the burns add up to 1,666 and the bear stands at level 1 */
        _burnAs(alice, 1_000 * UNIT);
        assertEq(activation.levelOf(1), 0);
        _burnAs(alice, 666 * UNIT);
        assertEq(activation.cumulativeOf(1), 1_666 * UNIT);
        assertEq(activation.levelOf(1), 1);
    }

    function test_burn_everyThresholdBoundary() public {
        /* Scenario:
           Given a bear one base unit short of each threshold
           When that last unit is burned
           Then the level rises by exactly one at each threshold */
        uint128 banked;
        for (uint8 k; k < 5; ++k) {
            uint128 threshold = activation.thresholdFor(k + 1);
            _burnAs(alice, threshold - 1 - banked);
            assertEq(activation.levelOf(1), k, "one unit short");
            _burnAs(alice, 1);
            assertEq(activation.levelOf(1), k + 1, "at the threshold");
            banked = threshold;
        }
    }

    function test_burn_spanningSeveralThresholds_jumpsToTheHighestCleared() public {
        /* Scenario:
           Given an unactivated bear
           When one burn clears three thresholds
           Then the level is 3 and BearActivated reports 0 to 3 */
        vm.expectEmit(true, true, false, true, address(activation));
        emit BearActivated(1, alice, 0, 3, 9_000 * UNIT, 9_000 * UNIT);
        _burnAs(alice, 9_000 * UNIT);
        assertEq(activation.levelOf(1), 3);
    }

    function test_burn_atLevelFive_reverts() public {
        /* Scenario:
           Given a bear at level 5
           When its owner burns more
           Then it reverts with AlreadyAtMaxLevel and nothing is burned */
        _burnAs(alice, 41_666 * UNIT);
        uint256 balance = mntd.balanceOf(alice);
        vm.expectRevert(Activation.AlreadyAtMaxLevel.selector);
        _burnAs(alice, UNIT);
        assertEq(mntd.balanceOf(alice), balance);
    }

    function test_burn_whilePaused_burnsNothing() public {
        /* Scenario:
           Given the owner has paused
           When the holder burns
           Then it reverts with ContractPaused and no $MNTD is burned */
        activation.setPaused(true);
        vm.expectRevert(Activation.ContractPaused.selector);
        _burnAs(alice, UNIT);
        assertEq(mntd.balanceOf(alice), 50_000 * UNIT);
    }

    function test_burn_zeroAmount_reverts() public {
        /* Scenario:
           Given a burn of zero
           When the holder sends it
           Then it reverts with ZeroAmount */
        vm.expectRevert(Activation.ZeroAmount.selector);
        _burnAs(alice, 0);
    }

    function test_burn_withoutEnoughAllowanceOrBalance_revertsWhole() public {
        /* Scenario:
           Given a holder with no allowance, and one with too little $MNTD
           When each burns
           Then the token's revert undoes the whole call: nothing is recorded */
        vm.prank(alice);
        mntd.approve(address(activation), 0);
        vm.expectRevert(MockMNTD.InsufficientAllowance.selector);
        _burnAs(alice, UNIT);
        assertEq(activation.cumulativeOf(1), 0);

        _mint(bob, 1);
        _fund(bob, 100);
        vm.prank(bob);
        vm.expectRevert(MockMNTD.InsufficientBalance.selector);
        activation.burn(2, 200 * UNIT);
        assertEq(activation.cumulativeOf(2), 0);
        assertEq(activation.lifetimeBurned(2), 0);
    }

    function test_burn_checksRunInTheSpecifiedOrder() public {
        /* Scenario:
           Given a burn that fails several checks at once
           When it is sent
           Then the first failing check in the order ContractPaused, ZeroAmount, NotBearOwner,
             AlreadyAtMaxLevel, Overshoot names the revert */
        _mint(bob, 1);
        activation.setPaused(true);
        vm.expectRevert(Activation.ContractPaused.selector);
        _burnAs(bob, 0);

        activation.setPaused(false);
        vm.expectRevert(Activation.ZeroAmount.selector);
        _burnAs(bob, 0);
        vm.expectRevert(Activation.NotBearOwner.selector);
        _burnAs(bob, 50_000 * UNIT);

        _burnAs(alice, 41_666 * UNIT);
        vm.expectRevert(Activation.NotBearOwner.selector);
        _burnAs(bob, UNIT);
        vm.expectRevert(Activation.AlreadyAtMaxLevel.selector);
        _burnAs(alice, 50_000 * UNIT);

        vm.prank(bob);
        vm.expectRevert(Activation.Overshoot.selector);
        activation.burn(2, 41_667 * UNIT);
    }

    function test_burnOrLink_forAnUnmintedId_revertsInTheCollection() public {
        /* Scenario:
           Given an id that was never minted
           When anyone burns for it or links it
           Then the collection's ownerOf reverts with OwnerQueryForNonexistentToken, before
             NotBearOwner, and nothing is recorded or burned */
        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
        _burnAsFor(alice, 4445, UNIT);
        vm.prank(alice);
        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
        activation.linkBear(4445);
        assertEq(activation.lifetimeBurned(4445), 0);
        assertEq(mntd.balanceOf(alice), 50_000 * UNIT);
    }

    function _burnAsFor(address caller, uint256 tokenId, uint128 amount) internal {
        vm.prank(caller);
        activation.burn(tokenId, amount);
    }
}

/// @dev ACT-4. The record is written before `burnFrom`, and `burn` is non-reentrant: a token that
///      calls back during `burnFrom` cannot burn again.
contract ActivationReentrancyTest is BaseTest {
    HookedMNTD internal hooked;
    Activation internal hookedActivation;
    ReentrantHolder internal holder;

    event BearActivated(
        uint256 indexed tokenId,
        address indexed burner,
        uint8 previousLevel,
        uint8 newLevel,
        uint256 amount,
        uint256 cumulative
    );

    function setUp() public override {
        super.setUp();
        hooked = new HookedMNTD();
        hookedActivation = new Activation(address(bears), address(hooked), _thresholds(), _weights());
        holder = new ReentrantHolder(hookedActivation, hooked);
        _mint(address(holder), 1);
        hooked.mint(address(holder), 100_000 * UNIT);
    }

    function test_burn_isRecordedOnce() public {
        /* Scenario: ACT-4 — A burn is recorded once
           Given the owner of a bear below level 5 who has approved Activation on $MNTD
           When the owner calls burn(tokenId, amount)
           Then the cumulative and lifetimeBurned grow by amount, BearActivated is emitted and the
             owner's $MNTD falls by amount
           And a burn made from inside the token's burnFrom reverts */
        vm.expectRevert(ReentrancyGuard.Reentrancy.selector);
        holder.burnTwice(1, 1_000 * UNIT, 10 * UNIT);
        assertEq(hookedActivation.cumulativeOf(1), 0, "the nested burn undid the whole call");
        assertEq(hooked.balanceOf(address(holder)), 100_000 * UNIT);

        vm.expectEmit(true, true, false, true, address(hookedActivation));
        emit BearActivated(1, address(holder), 0, 0, 1_000 * UNIT, 1_000 * UNIT);
        holder.burnOnce(1, 1_000 * UNIT);
        assertEq(hookedActivation.cumulativeOf(1), 1_000 * UNIT);
        assertEq(hookedActivation.lifetimeBurned(1), 1_000 * UNIT);
        assertEq(hooked.balanceOf(address(holder)), 99_000 * UNIT);
    }

    function test_burn_recordsBeforeTheTokenBurns() public {
        /* Scenario:
           Given a holder that reads Activation from inside the token's burnFrom
           When it burns for its bear
           Then cumulativeOf and lifetimeBurned already show the amount while burnFrom runs:
             the record is written first and the burn follows it in the same call */
        holder.burnOnce(1, 1_000 * UNIT);
        holder.burnObserving(1, 666 * UNIT);
        assertEq(holder.cumulativeDuringBurn(), 1_666 * UNIT, "recorded before burnFrom");
        assertEq(holder.lifetimeDuringBurn(), 1_666 * UNIT, "lifetime too");
        assertEq(hooked.balanceOf(address(holder)), 100_000 * UNIT - 1_666 * UNIT, "and then burned");
    }

    function test_nestedBurn_withinTheLimit_isStillRefused() public {
        /* Scenario:
           Given a holder whose nested burn would stay within level 5
           When the token calls back and the holder burns again from inside burnFrom
           Then it reverts with Reentrancy all the same: one burn per call */
        vm.expectRevert(ReentrancyGuard.Reentrancy.selector);
        holder.burnTwice(1, 41_656 * UNIT, 10 * UNIT);
        assertEq(hookedActivation.lifetimeBurned(1), 0);
    }
}

/// @dev Constructor guards and scaling: the token, thresholds and weights are immutable, so each
///      input is checked and the thresholds are scaled by the token's own decimals.
contract ActivationConstructionTest is BaseTest {
    function test_constructor_rejectsZeroBearsOrToken() public {
        /* Scenario:
           Given a deployment without the collection or the token address
           When Activation is constructed
           Then it reverts with ZeroAddress */
        vm.expectRevert(Activation.ZeroAddress.selector);
        new Activation(address(0), address(mntd), _thresholds(), _weights());
        vm.expectRevert(Activation.ZeroAddress.selector);
        new Activation(address(bears), address(0), _thresholds(), _weights());
    }

    function test_constructor_rejectsBadThresholds() public {
        /* Scenario:
           Given a zero first threshold, or thresholds not strictly ascending
           When Activation is constructed
           Then it reverts with ThresholdsNotAscending */
        uint128[5] memory t = _thresholds();
        t[0] = 0;
        vm.expectRevert(Activation.ThresholdsNotAscending.selector);
        new Activation(address(bears), address(mntd), t, _weights());

        t = _thresholds();
        t[3] = t[2];
        vm.expectRevert(Activation.ThresholdsNotAscending.selector);
        new Activation(address(bears), address(mntd), t, _weights());
    }

    function test_constructor_rejectsWeightsNotAscending() public {
        /* Scenario:
           Given weights where a level weighs no more than the one below
           When Activation is constructed
           Then it reverts with WeightsNotAscending */
        uint16[6] memory w = _weights();
        w[4] = w[3];
        vm.expectRevert(Activation.WeightsNotAscending.selector);
        new Activation(address(bears), address(mntd), _thresholds(), w);
    }

    function test_constructor_scalesTheThresholdsByTheTokensDecimals() public {
        /* Scenario:
           Given a 6-decimal token
           When Activation is constructed with the whole-token thresholds
           Then DECIMALS reads 6 and each threshold is its whole figure times 10^6 */
        MockMNTD six = new MockMNTD(6);
        Activation act = new Activation(address(bears), address(six), _thresholds(), _weights());
        assertEq(act.DECIMALS(), 6);
        assertEq(act.thresholdFor(1), 1_666 * 1e6);
        assertEq(act.thresholdFor(5), 41_666 * 1e6);
    }

    function test_constructor_refusesThresholdsThatDoNotFit() public {
        /* Scenario:
           Given a token whose decimals would take the last threshold past uint128
           When Activation is constructed
           Then it reverts rather than truncating */
        MockMNTD huge = new MockMNTD(40);
        vm.expectRevert(SafeCastLib.Overflow.selector);
        new Activation(address(bears), address(huge), _thresholds(), _weights());
    }

    function test_constructor_setsTheCollectionTheTokenAndTheOwner() public view {
        /* Scenario:
           Given a fresh Activation
           When BEARS, MNTD, DECIMALS, paused and owner are read
           Then they are the collection, the token, its decimals, false and the deployer */
        assertEq(address(activation.BEARS()), address(bears));
        assertEq(address(activation.MNTD()), address(mntd));
        assertEq(activation.DECIMALS(), 18);
        assertEq(activation.owner(), address(this));
        assertFalse(activation.paused());
    }
}

/// @dev The owner's powers: `setPaused` and ownership; renouncing is refused.
contract ActivationOwnershipTest is BaseTest {
    event PausedSet(bool paused);

    function setUp() public override {
        super.setUp();
        _mint(alice, 1);
    }

    function test_setPaused_byNonOwner_reverts() public {
        /* Scenario:
           Given a wallet that does not own Activation
           When it calls setPaused
           Then it reverts with Unauthorized */
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        activation.setPaused(true);
    }

    function test_setPaused_togglesAndEmits() public {
        /* Scenario:
           Given the owner
           When it pauses and unpauses
           Then PausedSet is emitted each time and burns work again afterwards */
        vm.expectEmit(false, false, false, true, address(activation));
        emit PausedSet(true);
        activation.setPaused(true);
        assertTrue(activation.paused());
        vm.expectEmit(false, false, false, true, address(activation));
        emit PausedSet(false);
        activation.setPaused(false);
        _burnFor(1, 1_666);
        assertEq(activation.levelOf(1), 1);
    }

    function test_renounceOwnership_reverts_pausedOrNot() public {
        /* Scenario:
           When the owner renounces, paused or not, or a stranger does
           Then each reverts with RenounceDisabled and the owner can still pause */
        vm.expectRevert(Activation.RenounceDisabled.selector);
        activation.renounceOwnership();
        activation.setPaused(true);
        vm.expectRevert(Activation.RenounceDisabled.selector);
        activation.renounceOwnership();
        vm.prank(alice);
        vm.expectRevert(Activation.RenounceDisabled.selector);
        activation.renounceOwnership();

        assertEq(activation.owner(), address(this));
        activation.setPaused(false);
        assertFalse(activation.paused());
    }
}

/// @dev The reset: a transfer voids the record without any call into `Activation`.
contract ActivationResetTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 1);
    }

    function test_transfer_resetsEverything_withNoCallIntoActivation() public {
        /* Scenario: ACT-5 — A transfer resets everything
           Given a bear at level 2 with a Status link
           When it is transferred to another wallet
           Then levelOf and cumulativeOf read zero, weightOf reads weightFor(0) and linkOf reads
             (0, 0), with no call into Activation */
        _burnFor(1, 3_333);
        vm.prank(alice);
        activation.linkBear(1);
        assertEq(activation.levelOf(1), 2);
        (uint256 linked,) = activation.linkOf(alice);
        assertEq(linked, 1);

        vm.startStateDiffRecording();
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        VmSafe.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();
        for (uint256 i; i < accesses.length; ++i) {
            assertTrue(accesses[i].account != address(activation), "the transfer never touches Activation");
        }

        assertEq(activation.levelOf(1), 0);
        assertEq(activation.cumulativeOf(1), 0);
        assertEq(activation.weightOf(1), activation.weightFor(0));
        (uint256 tokenId, uint8 level) = activation.linkOf(alice);
        assertEq(tokenId, 0);
        assertEq(level, 0);
    }

    function test_transfer_resetsCumulativeLevelAndWeight() public {
        /* Scenario:
           Given a bear at level 5
           When it is sold
           Then the buyer sees cumulative 0, level 0 and the level-0 weight */
        _burnFor(1, 41_666);
        assertEq(activation.levelOf(1), 5);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertEq(activation.cumulativeOf(1), 0);
        assertEq(activation.levelOf(1), 0);
        assertEq(activation.weightOf(1), 100);
    }

    function test_transfer_preservesLifetimeBurned() public {
        /* Scenario:
           Given a bear burned for
           When it changes hands
           Then lifetimeBurned is unchanged */
        _burnFor(1, 1_666);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertEq(activation.lifetimeBurned(1), 1_666 * UNIT);
    }

    function test_burn_afterTransfer_startsFromZero() public {
        /* Scenario:
           Given a bear sold at level 1
           When the new owner burns the first threshold
           Then they stand at level 1 with their own cumulative, and lifetime holds both */
        _burnFor(1, 1_666);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        _burnFor(1, 1_666);
        assertEq(activation.levelOf(1), 1);
        assertEq(activation.cumulativeOf(1), 1_666 * UNIT);
        assertEq(activation.lifetimeBurned(1), 3_332 * UNIT);
    }

    function test_transfer_thereAndBack_doesNotRestoreTheLevel() public {
        /* Scenario:
           Given a bear sold and bought back by its original owner
           When its level is read
           Then it is still zero, because the counter moved twice */
        _burnFor(1, 1_666);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        vm.prank(bob);
        bears.transferFrom(bob, alice, 1);
        assertEq(activation.levelOf(1), 0);
    }
}

/// @dev The Status link.
contract ActivationLinkTest is BaseTest {
    event BearLinked(address indexed wallet, uint256 indexed tokenId);
    event BearUnlinked(address indexed wallet, uint256 indexed tokenId);

    function setUp() public override {
        super.setUp();
        _mint(alice, 2);
    }

    function test_linkBear_oneNominationPerWallet() public {
        /* Scenario: ACT-9 — One nomination per wallet
           Given a wallet owning a bear at level 2
           When it calls linkBear(tokenId)
           Then linkOf(wallet) reads (tokenId, 2)
           And after the bear moves it reads (0, 0) */
        _burnFor(1, 3_333);
        vm.prank(alice);
        activation.linkBear(1);
        (uint256 tokenId, uint8 level) = activation.linkOf(alice);
        assertEq(tokenId, 1);
        assertEq(level, 2);

        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        (tokenId, level) = activation.linkOf(alice);
        assertEq(tokenId, 0);
        assertEq(level, 0);
    }

    function test_linkBear_byANewOwner_ofATradedBear() public {
        /* Scenario:
           Given a bear alice has sold to bob, so its counter has moved
           When bob burns it to level 2 and links it
           Then linkOf(bob) reads (tokenId, 2), recorded at the counter's current value
           And once bob sells it back, linkOf(bob) reads (0, 0) */
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertEq(bears.transferNonce(1), 1);

        _burnFor(1, 3_333);
        vm.prank(bob);
        activation.linkBear(1);
        (uint256 tokenId, uint8 level) = activation.linkOf(bob);
        assertEq(tokenId, 1, "the new owner's link stands");
        assertEq(level, 2);

        vm.prank(bob);
        bears.transferFrom(bob, alice, 1);
        (tokenId, level) = activation.linkOf(bob);
        assertEq(tokenId, 0);
        assertEq(level, 0);
    }

    function test_linkOf_levelFollowsLaterBurns() public {
        /* Scenario:
           Given a linked bear at level 1
           When its owner burns up to level 4
           Then linkOf reads the new level without a new nomination */
        _burnFor(1, 1_666);
        vm.prank(alice);
        activation.linkBear(1);
        _burnFor(1, 15_000);
        (uint256 tokenId, uint8 level) = activation.linkOf(alice);
        assertEq(tokenId, 1);
        assertEq(level, 4);
    }

    function test_walletWithSeveralBears_carriesOneLink() public {
        /* Scenario:
           Given a wallet holding two activated bears, one linked
           When linkOf is read
           Then it names the one linked bear; the other adds royalty weight (ACT-10) but no Status */
        _burnFor(1, 1_666);
        _burnFor(2, 41_666);
        vm.prank(alice);
        activation.linkBear(1);
        (uint256 tokenId, uint8 level) = activation.linkOf(alice);
        assertEq(tokenId, 1);
        assertEq(level, 1);
        assertEq(activation.weightOf(2), 200);
    }

    function test_linkBear_recordsTheNomination() public {
        /* Scenario:
           Given a bear owner at level 1
           When they nominate it
           Then BearLinked is emitted and the link reports that bear and its level */
        _burnFor(1, 1_666);
        vm.expectEmit(true, true, true, true, address(activation));
        emit BearLinked(alice, 1);
        vm.prank(alice);
        activation.linkBear(1);
        (uint256 tokenId, uint8 level) = activation.linkOf(alice);
        assertEq(tokenId, 1);
        assertEq(level, 1);
    }

    function test_linkBear_byNonOwner_reverts() public {
        /* Scenario:
           Given a bear owned by alice
           When bob tries to nominate it
           Then it reverts with NotBearOwner */
        vm.prank(bob);
        vm.expectRevert(Activation.NotBearOwner.selector);
        activation.linkBear(1);
    }

    function test_linkBear_whenPaused_reverts() public {
        /* Scenario:
           Given the owner has paused
           When a holder nominates a bear
           Then it reverts with ContractPaused */
        activation.setPaused(true);
        vm.prank(alice);
        vm.expectRevert(Activation.ContractPaused.selector);
        activation.linkBear(1);
    }

    function test_linkBear_replacesThePreviousNomination() public {
        /* Scenario:
           Given a wallet that has nominated one bear
           When it nominates another
           Then only the newer nomination stands */
        vm.startPrank(alice);
        activation.linkBear(1);
        activation.linkBear(2);
        vm.stopPrank();
        (uint256 tokenId,) = activation.linkOf(alice);
        assertEq(tokenId, 2);
    }

    function test_transfer_voidsThePreviousOwnersLink() public {
        /* Scenario:
           Given alice has nominated her bear
           When she sells it
           Then her link reads (0, 0) */
        _burnFor(1, 1_666);
        vm.startPrank(alice);
        activation.linkBear(1);
        bears.transferFrom(alice, bob, 1);
        vm.stopPrank();
        (uint256 tokenId, uint8 level) = activation.linkOf(alice);
        assertEq(tokenId, 0);
        assertEq(level, 0);
    }

    function test_unlinkBear_clearsTheNomination() public {
        /* Scenario:
           Given a nominated bear
           When the owner unlinks
           Then BearUnlinked is emitted, the link reads empty and the bear has not moved */
        vm.startPrank(alice);
        activation.linkBear(1);
        vm.expectEmit(true, true, true, true, address(activation));
        emit BearUnlinked(alice, 1);
        activation.unlinkBear();
        vm.stopPrank();
        (uint256 tokenId,) = activation.linkOf(alice);
        assertEq(tokenId, 0);
        assertEq(bears.ownerOf(1), alice);
    }

    function test_unlinkBear_withNoNomination_isHarmlessAndSilent() public {
        /* Scenario:
           Given a wallet with no nomination
           When it unlinks anyway
           Then nothing reverts and no event is emitted */
        vm.recordLogs();
        vm.prank(bob);
        activation.unlinkBear();
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function test_unlinkBear_whilePaused_succeeds() public {
        /* Scenario:
           Given a nominated bear and a pause
           When the owner unlinks
           Then it succeeds: the pause closes links, not unlinks */
        vm.prank(alice);
        activation.linkBear(1);
        activation.setPaused(true);
        vm.prank(alice);
        activation.unlinkBear();
        (uint256 tokenId,) = activation.linkOf(alice);
        assertEq(tokenId, 0);
    }

    function test_linkOf_withNoNomination_readsEmpty() public view {
        /* Scenario:
           Given a wallet that never nominated a bear
           When its link is read
           Then it reads (0, 0) */
        (uint256 tokenId, uint8 level) = activation.linkOf(bob);
        assertEq(tokenId, 0);
        assertEq(level, 0);
    }
}

/// @dev Thresholds, weights, `costToReach` and `snapshot`.
contract ActivationViewsTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 2);
    }

    function test_thresholdFor_everyLevel() public view {
        /* Scenario:
           Given the specified thresholds in whole $MNTD and an 18-decimal token
           When each level's threshold is read
           Then level 0 costs nothing and levels 1-5 return the constructor's values in base units */
        uint128[5] memory t = _thresholds();
        assertEq(activation.thresholdFor(0), 0);
        for (uint8 k; k < 5; ++k) {
            assertEq(activation.thresholdFor(k + 1), t[k] * UNIT);
        }
        assertEq(activation.thresholdFor(1), 1_666 * UNIT);
        assertEq(activation.thresholdFor(5), 41_666 * UNIT);
    }

    function test_weightFor_everyLevel() public view {
        /* Scenario:
           Given the specified weights
           When each level's weight is read
           Then levels 0-5 return 100, 110, 125, 145, 170, 200 */
        uint16[6] memory w = _weights();
        for (uint8 k; k < 6; ++k) {
            assertEq(activation.weightFor(k), w[k]);
        }
    }

    function test_weightOf_followsTheLevel() public {
        /* Scenario:
           Given an unactivated bear and a bear burned to level 3
           When their weights are read
           Then they are 100 and 145 */
        _burnFor(2, 8_333);
        assertEq(activation.weightOf(1), 100);
        assertEq(activation.weightOf(2), 145);
    }

    function test_levelReads_aboveMaxLevel_revertWithInvalidLevel() public {
        /* Scenario:
           Given a level that does not exist
           When its threshold, weight or cost is read
           Then each reverts with InvalidLevel */
        vm.expectRevert(Activation.InvalidLevel.selector);
        activation.thresholdFor(6);
        vm.expectRevert(Activation.InvalidLevel.selector);
        activation.weightFor(6);
        vm.expectRevert(Activation.InvalidLevel.selector);
        activation.costToReach(1, 6);
    }

    function test_costToReach_returnsTheRemainderOrZero() public {
        /* Scenario:
           Given a bear burned for 1,000
           When the cost to level 1, level 5 and level 0 is read
           Then it returns 666, 40,666 and 0 */
        _burnFor(1, 1_000);
        assertEq(activation.costToReach(1, 1), 666 * UNIT);
        assertEq(activation.costToReach(1, 5), 40_666 * UNIT);
        assertEq(activation.costToReach(1, 0), 0);
    }

    function test_snapshot_answersForAnyIds() public {
        /* Scenario:
           Given bear 1 unactivated, bear 2 at level 2 and no bear 4445
           When snapshot([1, 2, 4445]) is read
           Then it returns owner, level and weight for 1 and 2 and zeroes for 4445 */
        _burnFor(2, 3_333);
        uint256[] memory ids = new uint256[](3);
        (ids[0], ids[1], ids[2]) = (1, 2, 4445);
        Activation.BearState[] memory rows = activation.snapshot(ids);
        assertEq(rows.length, 3);
        assertEq(rows[0].owner, alice);
        assertEq(rows[0].level, 0);
        assertEq(rows[0].weight, 100);
        assertEq(rows[1].owner, alice);
        assertEq(rows[1].level, 2);
        assertEq(rows[1].weight, 125);
        assertEq(rows[2].owner, address(0));
        assertEq(rows[2].level, 0);
        assertEq(rows[2].weight, 0);
    }
}

/// @dev ACT-2. Five cumulative thresholds, given in whole $MNTD and scaled by the token's decimals.
contract ActivationThresholdsTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 2);
    }

    function test_cumulativeThresholds_giveTheLevel() public {
        /* Scenario: ACT-2 — Cumulative thresholds give the level
           Given the thresholds 1,666 / 3,333 / 8,333 / 16,666 / 41,666 whole $MNTD and a token with
             18 decimals
           When a bear's cumulative reaches 8,333 $MNTD
           Then levelOf reads 3 and costToReach(id, 4) reads 8,333 × 10^18 */
        assertEq(activation.DECIMALS(), 18);
        assertEq(activation.thresholdFor(1), 1_666 * UNIT);
        assertEq(activation.thresholdFor(2), 3_333 * UNIT);
        assertEq(activation.thresholdFor(3), 8_333 * UNIT);
        assertEq(activation.thresholdFor(4), 16_666 * UNIT);
        assertEq(activation.thresholdFor(5), 41_666 * UNIT);

        _burnFor(1, 8_333);
        assertEq(activation.cumulativeOf(1), 8_333 * UNIT);
        assertEq(activation.levelOf(1), 3);
        assertEq(activation.costToReach(1, 4), 8_333 * 1e18);
    }

    function test_theTable_isReadCumulatively() public {
        /* Scenario:
           Given one bear burned for 41,666 at once and another level by level
           When both are read
           Then both stand at level 5 having been burned for 41,666 in all: each figure is a
             running total, not the price of one step */
        _burnFor(1, 41_666);

        uint128[5] memory t = _thresholds();
        uint128 banked;
        for (uint8 k; k < 5; ++k) {
            _burnFor(2, t[k] - banked);
            banked = t[k];
        }

        assertEq(activation.levelOf(1), 5);
        assertEq(activation.levelOf(2), 5);
        assertEq(activation.cumulativeOf(1), 41_666 * UNIT);
        assertEq(activation.cumulativeOf(2), 41_666 * UNIT);
    }

    function test_costToReach_atEveryLevel() public {
        /* Scenario:
           Given a bear burned for 8,333
           When costToReach is read for each level
           Then levels 0-3 cost nothing and levels 4 and 5 cost their threshold less 8,333 */
        _burnFor(1, 8_333);
        for (uint8 k; k <= 3; ++k) {
            assertEq(activation.costToReach(1, k), 0);
        }
        assertEq(activation.costToReach(1, 4), (16_666 - 8_333) * UNIT);
        assertEq(activation.costToReach(1, 5), (41_666 - 8_333) * UNIT);
    }
}

/// @dev ACT-3. Six royalty weights, basis 100, fixed at construction; a bear weighs what its
///      current level weighs.
contract ActivationWeightsTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 1);
    }

    function test_weights_followTheLevel() public {
        /* Scenario: ACT-3 — Weights follow the level
           Given the weights 100 / 110 / 125 / 145 / 170 / 200
           When a bear at level 3 is read
           Then weightOf returns 145 and weightFor(5) returns 200 */
        assertEq(activation.weightFor(0), 100);
        assertEq(activation.weightFor(1), 110);
        assertEq(activation.weightFor(2), 125);
        assertEq(activation.weightFor(3), 145);
        assertEq(activation.weightFor(4), 170);
        assertEq(activation.weightFor(5), 200);

        _burnFor(1, 8_333);
        assertEq(activation.levelOf(1), 3);
        assertEq(activation.weightOf(1), 145);
        assertEq(activation.weightFor(5), 200);
    }

    function test_weightOf_risesWithEveryLevel_andResetsOnTransfer() public {
        /* Scenario:
           Given an unactivated bear
           When it is burned up to each threshold in turn, then sold
           Then weightOf reads 100, 110, 125, 145, 170, 200, and 100 again after the sale */
        uint16[6] memory w = _weights();
        uint128[5] memory t = _thresholds();
        assertEq(activation.weightOf(1), w[0]);
        uint128 banked;
        for (uint8 k; k < 5; ++k) {
            _burnFor(1, t[k] - banked);
            banked = t[k];
            assertEq(activation.weightOf(1), w[k + 1]);
        }

        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertEq(activation.weightOf(1), w[0]);
    }
}

/// @dev ACT-6. `lifetimeBurned` accumulates every burn ever recorded for a bear and never resets.
contract ActivationLifetimeTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 1);
    }

    function test_lifetime_neverResets() public {
        /* Scenario: ACT-6 — Lifetime never resets
           Given a bear burned for twice with a transfer in between
           When lifetimeBurned is read
           Then it is the sum of both burns */
        _burnFor(1, 2_000);
        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        _burnFor(1, 500);

        assertEq(activation.lifetimeBurned(1), 2_500 * UNIT);
        assertEq(activation.cumulativeOf(1), 500 * UNIT, "the cumulative did reset");
    }

    function test_lifetime_sumsAcrossOwnersAndAReturn() public {
        /* Scenario:
           Given a bear burned for under alice, bob, and alice again after it came back
           When lifetimeBurned and cumulativeOf are read after each step
           Then lifetimeBurned only ever grows, to the sum of all three burns, while
             cumulativeOf holds only the current holding's burns */
        _burnFor(1, 1_666);
        assertEq(activation.lifetimeBurned(1), 1_666 * UNIT);

        vm.prank(alice);
        bears.transferFrom(alice, bob, 1);
        assertEq(activation.lifetimeBurned(1), 1_666 * UNIT, "a transfer leaves it");
        _burnFor(1, 3_333);
        assertEq(activation.lifetimeBurned(1), 4_999 * UNIT);
        assertEq(activation.cumulativeOf(1), 3_333 * UNIT);

        vm.prank(bob);
        bears.transferFrom(bob, alice, 1);
        _burnFor(1, 1);
        assertEq(activation.lifetimeBurned(1), 5_000 * UNIT);
        assertEq(activation.cumulativeOf(1), 1 * UNIT, "alice's earlier burn does not come back");
    }
}

/// @dev ACT-10. `snapshot(ids)` is what MINT's royalty accounting reads at each closing block;
///      the sums — per wallet, and the eligible total without `0x…dEaD` — are taken off-chain.
contract ActivationSnapshotTest is BaseTest {
    address internal constant DEAD = 0x000000000000000000000000000000000000dEaD;

    function setUp() public override {
        super.setUp();
        _mint(alice, 2);
        _mint(bob, 2);
    }

    function test_snapshot_answersForAnyIds() public {
        /* Scenario: ACT-10 — The snapshot answers for any ids
           When snapshot([1, 2, 4445]) is read
           Then it returns owner, level and weight for ids 1 and 2 and zeroes for the id that does
             not exist */
        _burnFor(1, 8_333);
        uint256[] memory ids = new uint256[](3);
        (ids[0], ids[1], ids[2]) = (1, 2, 4445);
        Activation.BearState[] memory rows = activation.snapshot(ids);

        assertEq(rows.length, 3);
        assertEq(rows[0].owner, alice);
        assertEq(rows[0].level, 3);
        assertEq(rows[0].weight, 145);
        assertEq(rows[1].owner, alice);
        assertEq(rows[1].level, 0);
        assertEq(rows[1].weight, 100);
        assertEq(rows[2].owner, address(0));
        assertEq(rows[2].level, 0);
        assertEq(rows[2].weight, 0);
    }

    function test_snapshot_reproducesTheSplitInputs() public {
        /* Scenario:
           Given four bears — alice's at levels 5 and 0, bob's at level 2, and bob's other sent to
             0x…dEaD at level 1 before it moved
           When snapshot([1, 2, 3, 4]) is read and summed off-chain
           Then alice weighs 300, bob 125, the dead address's bear is reported with that owner at
             the level-0 weight, and the eligible total excluding it is 425 */
        _burnFor(1, 41_666);
        _burnFor(3, 3_333);
        _burnFor(4, 1_666);
        vm.prank(bob);
        bears.transferFrom(bob, DEAD, 4);

        uint256[] memory ids = new uint256[](4);
        (ids[0], ids[1], ids[2], ids[3]) = (1, 2, 3, 4);
        Activation.BearState[] memory rows = activation.snapshot(ids);

        assertEq(rows[3].owner, DEAD, "the dead address stays visible; it is excluded off-chain");
        assertEq(rows[3].weight, 100, "and its record was reset by the move");

        uint256 aliceWeight;
        uint256 bobWeight;
        uint256 eligible;
        for (uint256 i; i < rows.length; ++i) {
            if (rows[i].owner == alice) aliceWeight += rows[i].weight;
            if (rows[i].owner == bob) bobWeight += rows[i].weight;
            if (rows[i].owner != DEAD) eligible += rows[i].weight;
        }
        assertEq(aliceWeight, 300);
        assertEq(bobWeight, 125);
        assertEq(eligible, 425);
    }

    function test_snapshot_edgeIds() public view {
        /* Scenario:
           Given the collection
           When snapshot is read for no ids, and for id 0
           Then it returns an empty array, and zeroes for id 0 (bears are numbered from 1) */
        assertEq(activation.snapshot(new uint256[](0)).length, 0);
        uint256[] memory zero = new uint256[](1);
        Activation.BearState[] memory rows = activation.snapshot(zero);
        assertEq(rows[0].owner, address(0));
        assertEq(rows[0].weight, 0);
    }
}

/// @dev ACT-8. `burn` refuses any amount beyond what level 5 needs, so no $MNTD is destroyed for
///      nothing; the portal sizes each burn with `costToReach`.
contract ActivationOvershootTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 1);
        _fund(alice, 50_000);
    }

    function test_burn_pastLevelFive_burnsNothing() public {
        /* Scenario: ACT-8 — Nothing is burned for nothing
           Given a bear whose costToReach(id, 5) reads x
           When the holder calls burn(id, x + 1)
           Then it reverts with Overshoot and no $MNTD is burned */
        vm.prank(alice);
        activation.burn(1, 2_000 * UNIT);
        uint128 x = activation.costToReach(1, 5);
        assertEq(x, (41_666 - 2_000) * UNIT);
        uint256 balance = mntd.balanceOf(alice);
        uint256 supply = mntd.totalSupply();
        uint128 cumulative = activation.cumulativeOf(1);

        vm.prank(alice);
        vm.expectRevert(Activation.Overshoot.selector);
        activation.burn(1, x + 1);

        assertEq(mntd.balanceOf(alice), balance, "no $MNTD burned");
        assertEq(mntd.totalSupply(), supply);
        assertEq(activation.cumulativeOf(1), cumulative, "nothing recorded");
    }

    function test_costToReach_sizesABurnToEachLevelExactly() public {
        /* Scenario:
           Given an unactivated bear
           When the holder burns costToReach(id, k) for k = 1 to 5 in turn
           Then each burn lands the bear exactly on level k, and costToReach(id, k) then reads 0 */
        for (uint8 k = 1; k <= 5; ++k) {
            uint128 cost = activation.costToReach(1, k);
            vm.prank(alice);
            activation.burn(1, cost);
            assertEq(activation.levelOf(1), k);
            assertEq(activation.cumulativeOf(1), activation.thresholdFor(k));
            assertEq(activation.costToReach(1, k), 0);
        }
        assertEq(mntd.balanceOf(alice), (50_000 - 41_666) * UNIT, "exactly 41,666 burned in all");
    }
}

/// @dev ACT-11. The pause closes burns and links and nothing else; it admits no exemption.
contract ActivationPauseTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 2);
    }

    function test_pause_closesBurnsAndLinksOnly() public {
        /* Scenario: ACT-11 — Pause closes burns and links only
           Given the owner has paused
           When a holder calls burn or linkBear
           Then both revert with ContractPaused
           And reads, unlinkBear and every transfer still succeed */
        _burnFor(1, 3_333);
        vm.prank(alice);
        activation.linkBear(1);
        _fund(alice, 1_000);
        activation.setPaused(true);

        vm.prank(alice);
        vm.expectRevert(Activation.ContractPaused.selector);
        activation.burn(1, UNIT);
        vm.prank(alice);
        vm.expectRevert(Activation.ContractPaused.selector);
        activation.linkBear(2);
        assertEq(mntd.balanceOf(alice), 1_000 * UNIT, "no $MNTD burned while paused");

        assertEq(activation.levelOf(1), 2);
        assertEq(activation.cumulativeOf(1), 3_333 * UNIT);
        assertEq(activation.weightOf(1), 125);
        assertEq(activation.costToReach(1, 3), 5_000 * UNIT);
        (uint256 linked,) = activation.linkOf(alice);
        assertEq(linked, 1);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        assertEq(activation.snapshot(ids)[0].level, 2);

        vm.prank(alice);
        activation.unlinkBear();
        (linked,) = activation.linkOf(alice);
        assertEq(linked, 0);

        vm.prank(alice);
        bears.transferFrom(alice, bob, 2);
        assertEq(bears.ownerOf(2), bob);
    }

    function test_pause_admitsNoExemption() public {
        /* Scenario:
           Given the owner has paused
           When the owner, holding a bear and $MNTD, tries to burn or link
           Then both revert with ContractPaused: no address is exempt */
        activation.transferOwnership(alice);
        _fund(alice, 1_000);
        vm.startPrank(alice);
        activation.setPaused(true);
        vm.expectRevert(Activation.ContractPaused.selector);
        activation.burn(1, UNIT);
        vm.expectRevert(Activation.ContractPaused.selector);
        activation.linkBear(1);
        vm.stopPrank();
    }

    function test_rehearsalWindow_opensAndClosesBurns() public {
        /* Scenario:
           Given Activation paused from deployment
           When a holder burns, the owner opens the window, the holder burns, and the owner closes it
           Then only the burn inside the window is burned and recorded */
        _fund(alice, 50_000);
        activation.setPaused(true);
        vm.prank(alice);
        vm.expectRevert(Activation.ContractPaused.selector);
        activation.burn(1, UNIT);

        activation.setPaused(false);
        vm.prank(alice);
        activation.burn(1, 1_666 * UNIT);
        activation.setPaused(true);

        vm.prank(alice);
        vm.expectRevert(Activation.ContractPaused.selector);
        activation.burn(1, UNIT);
        assertEq(mntd.balanceOf(alice), (50_000 - 1_666) * UNIT);
        assertEq(activation.levelOf(1), 1);
    }
}

/// @dev ACT-12. The owner sets the pause and can hand ownership on; a bear's owner burns and links;
///      nothing else is administrable. The complete external interface is read from the compiled
///      artifact and pinned here, so a function added later — a setter, a freeze, a clawback, a
///      second way to record a level — fails this suite until the specification says so.
contract ActivationRolesTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 1);
    }

    function test_onlyTheOwnerAdministers() public {
        /* Scenario: ACT-12 — Only the owner administers
           When a non-owner calls setPaused, or anyone calls renounceOwnership
           Then it reverts
           And no function anywhere changes the token, thresholds, weights or a bear's record other
             than its owner's burn */
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        activation.setPaused(true);
        vm.expectRevert(Activation.RenounceDisabled.selector);
        activation.renounceOwnership();

        string[24] memory expected = [
            // reads
            "BEARS()",
            "DECIMALS()",
            "MNTD()",
            "costToReach(uint256,uint8)",
            "cumulativeOf(uint256)",
            "levelOf(uint256)",
            "lifetimeBurned(uint256)",
            "linkOf(address)",
            "paused()",
            "snapshot(uint256[])",
            "thresholdFor(uint8)",
            "weightFor(uint8)",
            "weightOf(uint256)",
            "owner()",
            "ownershipHandoverExpiresAt(address)",
            // a bear's owner: the burn and the link
            "burn(uint256,uint128)",
            "linkBear(uint256)",
            "unlinkBear()",
            // the owner: pause and ownership (Solady); renounce reverts
            "setPaused(bool)",
            "transferOwnership(address)",
            "renounceOwnership()",
            "requestOwnershipHandover()",
            "cancelOwnershipHandover()",
            "completeOwnershipHandover(address)"
        ];
        string memory artifact = vm.readFile("out/Activation.sol/Activation.json");
        string[] memory actual = vm.parseJsonKeys(artifact, ".methodIdentifiers");
        assertEq(actual.length, expected.length, "function count");
        for (uint256 i; i < expected.length; ++i) {
            assertTrue(_contains(actual, expected[i]), expected[i]);
        }
        // methodIdentifiers lists named functions only; a fallback or receive shows in the ABI.
        string[] memory kinds = abi.decode(vm.parseJson(artifact, ".abi[*].type"), (string[]));
        assertTrue(_contains(kinds, "function"), "the ABI was read");
        assertFalse(_contains(kinds, "fallback"), "no fallback");
        assertFalse(_contains(kinds, "receive"), "no receive");
    }

    function test_ownerFunctions_leaveTheTokenThresholdsWeightsAndRecordsAlone() public {
        /* Scenario:
           Given a bear burned to level 2 and linked
           When the owner runs every owner function — setPaused on and off, a handover and a
             transfer of ownership
           Then the token, thresholds, weights, the bear's cumulative, level, lifetime and link read
             as before */
        _burnFor(1, 3_333);
        vm.prank(alice);
        activation.linkBear(1);

        activation.setPaused(true);
        activation.setPaused(false);
        address next = makeAddr("nextOwner");
        vm.prank(next);
        activation.requestOwnershipHandover();
        activation.completeOwnershipHandover(next);
        vm.prank(next);
        activation.transferOwnership(address(this));

        assertEq(address(activation.MNTD()), address(mntd));
        uint128[5] memory t = _thresholds();
        uint16[6] memory w = _weights();
        for (uint8 k; k < 5; ++k) {
            assertEq(activation.thresholdFor(k + 1), t[k] * UNIT);
        }
        for (uint8 k; k < 6; ++k) {
            assertEq(activation.weightFor(k), w[k]);
        }
        assertEq(activation.cumulativeOf(1), 3_333 * UNIT);
        assertEq(activation.levelOf(1), 2);
        assertEq(activation.lifetimeBurned(1), 3_333 * UNIT);
        (uint256 tokenId, uint8 level) = activation.linkOf(alice);
        assertEq(tokenId, 1);
        assertEq(level, 2);
    }

    function _contains(string[] memory list, string memory item) internal pure returns (bool) {
        for (uint256 i; i < list.length; ++i) {
            if (keccak256(bytes(list[i])) == keccak256(bytes(item))) return true;
        }
        return false;
    }
}

/// @dev ACT-13. Each event is checked in the recorded logs against its documented signature: the
///      first topic is the hash of the documented text, the indexed arguments are the remaining
///      topics, and the rest decodes from the data.
contract ActivationEventsTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 1);
        _fund(alice, 10_000);
    }

    function test_events_carryTheDocumentedArguments() public {
        /* Scenario: ACT-13 — Events carry the documented arguments
           When a burn, a link, an unlink and a pause happen
           Then BearActivated, BearLinked, BearUnlinked and PausedSet are emitted with the documented
             arguments */
        vm.recordLogs();
        vm.prank(alice);
        activation.burn(1, 3_333 * UNIT);
        VmSafe.Log memory log = _only(vm.getRecordedLogs());
        assertEq(log.topics[0], keccak256("BearActivated(uint256,address,uint8,uint8,uint256,uint256)"));
        assertEq(log.topics.length, 3, "tokenId and burner indexed");
        assertEq(uint256(log.topics[1]), 1, "tokenId");
        assertEq(address(uint160(uint256(log.topics[2]))), alice, "burner");
        (uint8 previousLevel, uint8 newLevel, uint256 amount, uint256 cumulative) =
            abi.decode(log.data, (uint8, uint8, uint256, uint256));
        assertEq(previousLevel, 0);
        assertEq(newLevel, 2);
        assertEq(amount, 3_333 * UNIT);
        assertEq(cumulative, 3_333 * UNIT);

        // A second burn tells previousLevel from 0 and amount from cumulative.
        vm.prank(alice);
        activation.burn(1, 5_000 * UNIT);
        log = _only(vm.getRecordedLogs());
        (previousLevel, newLevel, amount, cumulative) = abi.decode(log.data, (uint8, uint8, uint256, uint256));
        assertEq(previousLevel, 2);
        assertEq(newLevel, 3);
        assertEq(amount, 5_000 * UNIT);
        assertEq(cumulative, 8_333 * UNIT);

        vm.prank(alice);
        activation.linkBear(1);
        log = _only(vm.getRecordedLogs());
        assertEq(log.topics[0], keccak256("BearLinked(address,uint256)"));
        assertEq(address(uint160(uint256(log.topics[1]))), alice, "wallet");
        assertEq(uint256(log.topics[2]), 1, "tokenId");

        vm.prank(alice);
        activation.unlinkBear();
        log = _only(vm.getRecordedLogs());
        assertEq(log.topics[0], keccak256("BearUnlinked(address,uint256)"));
        assertEq(address(uint160(uint256(log.topics[1]))), alice, "wallet");
        assertEq(uint256(log.topics[2]), 1, "tokenId");

        activation.setPaused(true);
        log = _only(vm.getRecordedLogs());
        assertEq(log.topics[0], keccak256("PausedSet(bool)"));
        assertTrue(abi.decode(log.data, (bool)), "paused");
    }

    /// @dev The one log the last call emitted, from Activation.
    function _only(VmSafe.Log[] memory logs) internal view returns (VmSafe.Log memory) {
        assertEq(logs.length, 1, "exactly one event");
        assertEq(logs[0].emitter, address(activation));
        return logs[0];
    }
}

/// @dev ACT-14. Every listed read answers for a bear that has been burned for.
contract ActivationReadsTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 1);
    }

    function test_everyReadAnswers() public {
        /* Scenario: ACT-14 — Every read answers
           When every listed read is called for a bear that has been burned for
           Then each returns without reverting
           And BEARS and MNTD return the deployed addresses and DECIMALS the token's decimals */
        _burnFor(1, 3_333);
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
        assertEq(address(activation.BEARS()), address(bears));
        assertEq(address(activation.MNTD()), address(mntd));
        assertEq(activation.DECIMALS(), mntd.decimals());
    }
}
