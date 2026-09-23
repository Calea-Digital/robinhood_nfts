// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Script, console2} from "forge-std/Script.sol";

import {ERC721ContractMetadata} from "seadrop/ERC721ContractMetadata.sol";

import {MintABear} from "../src/MintABear.sol";

/**
 * @title  Enforcement
 * @notice Lifts or restores royalty enforcement on `MintABear` with one owner call each (OPS-6):
 *         `setTransferValidator(address(0))` lifts it, `setTransferValidator(V3)` restores
 *         Limit Break V3 with its zero-state policy. Both are reversible and emit
 *         `TransferValidatorUpdated`.
 *
 *             forge script script/Enforcement.s.sol --rpc-url $RPC --sig "status(address)" $BEARS
 *             forge script script/Enforcement.s.sol --rpc-url $RPC --broadcast --sig "disable(address)" $BEARS
 *             forge script script/Enforcement.s.sol --rpc-url $RPC --broadcast --sig "enable(address)" $BEARS
 *             forge script script/Enforcement.s.sol --rpc-url $RPC --sig "safeTransaction(address,bool)" $BEARS false
 *
 *         `disable` and `enable` broadcast from the signer passed to forge, which must be the
 *         collection's owner. A Safe admin cannot sign a forge broadcast: `safeTransaction` prints
 *         the `to`, `value` and `data` to propose in the Safe instead. See `docs/RUNBOOK.md`,
 *         "Transfer enforcement".
 */
contract Enforcement is Script {
    /// @notice Limit Break transfer validator V3 on Robinhood Chain (verified 2026-09-15; COL-7).
    address public constant TRANSFER_VALIDATOR_V3 = 0x721C002B0059009a671D00aD1700c9748146cd1B;

    /// @notice Enforcement is already in the requested state; nothing is sent.
    error AlreadyInState(bool enforced);

    /// @notice Whether enforcement is on, and through which validator.
    function status(address bears) public view returns (bool enforced, address validator) {
        validator = MintABear(bears).getTransferValidator();
        enforced = validator != address(0);
        console2.log("transfer validator", validator);
        console2.log(enforced ? "enforcement: on" : "enforcement: off");
    }

    /// @notice Lifts enforcement: `setTransferValidator(address(0))`.
    function disable(address bears) external {
        _set(bears, false);
    }

    /// @notice Restores enforcement: `setTransferValidator(V3)`.
    function enable(address bears) external {
        _set(bears, true);
    }

    /// @notice The transaction a Safe admin proposes to lift (`enable == false`) or restore it.
    function safeTransaction(address bears, bool enable_)
        public
        pure
        returns (address to, uint256 value, bytes memory data)
    {
        to = bears;
        value = 0;
        data =
            abi.encodeCall(ERC721ContractMetadata.setTransferValidator, (enable_ ? TRANSFER_VALIDATOR_V3 : address(0)));
        console2.log("to", to);
        console2.log("value", value);
        console2.logBytes(data);
    }

    function _set(address bears, bool enable_) private {
        (bool enforced,) = status(bears);
        if (enforced == enable_) revert AlreadyInState(enforced);
        vm.startBroadcast();
        MintABear(bears).setTransferValidator(enable_ ? TRANSFER_VALIDATOR_V3 : address(0));
        vm.stopBroadcast();
        status(bears);
    }
}
