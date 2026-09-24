// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest} from "../BaseTest.t.sol";

/**
 * @title  ForgedLevelRegression
 * @notice Kept from the tranche-1 review of 2026-09-24 (MNT-26, L-1), where this case passed as an
 *         exploit. It is retained inverted: it asserts the absence that now stops it.
 *
 * @dev    The finding. `Activation` accepted `credit(tokenId, burner, amount, nonce, ref)` from
 *         one `crediter` the owner set with `setCrediter`, unchecked and without delay. The owner
 *         could point it at an address of their own and record level 5 for any bear, with no
 *         $MNTD burned — skewing the royalty split and the Status multiplier, against the
 *         family's purpose that a level is evidence of a burn "no key can forge".
 *
 *         The fix. `Activation` burns $MNTD itself (ACT-1, ACT-7): the only way a record grows is
 *         `burn`, sent by the bear's owner, with the burn in the same call. `crediter`,
 *         `setCrediter` and `credit` do not exist.
 */
contract ForgedLevelRegression is BaseTest {
    function test_regression_ownerCannotRecordALevelWithoutABurn() public {
        /* Scenario:
           Given the owner of Activation and a bear it does not hold
           When the owner tries to set a crediter of its own and credit the bear to level 5
           Then neither function exists, and the bear stays at level 0 */
        _mint(alice, 1);

        (bool setOk,) = address(activation).call(abi.encodeWithSignature("setCrediter(address)", address(this)));
        assertFalse(setOk, "setCrediter is absent");
        (bool creditOk,) = address(activation)
            .call(
                abi.encodeWithSignature(
                    "credit(uint256,address,uint128,uint64,bytes32)",
                    1,
                    alice,
                    uint128(41_666 * UNIT),
                    uint64(0),
                    bytes32(uint256(1))
                )
            );
        assertFalse(creditOk, "credit is absent");

        assertEq(activation.levelOf(1), 0, "no level without a burn");
        assertEq(activation.lifetimeBurned(1), 0);
    }
}
