// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Script, console2} from "forge-std/Script.sol";

import {ERC721ContractMetadata} from "seadrop/ERC721ContractMetadata.sol";

import {MintABear} from "../src/MintABear.sol";

/**
 * @title  Enforcement
 * @notice Lifts or restores royalty enforcement on `MintABear` with one owner call each (OPS-6):
 *         `setTransferValidator(address(0))` lifts it, `setTransferValidator(V3)` restores
 *         Limit Break V3 with its zero-state policy — over any other validator too. Both are
 *         reversible and emit `TransferValidatorUpdated`.
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

    /// @notice The collection already has the validator requested; nothing is sent.
    error AlreadyInState(address validator);

    /// @notice Whether enforcement is on, and through which validator.
    function status(address bears) public view returns (bool enforced, address validator) {
        validator = MintABear(bears).getTransferValidator();
        enforced = validator != address(0);
        console2.log("transfer validator", validator);
        if (validator == TRANSFER_VALIDATOR_V3) console2.log("enforcement: on (Limit Break V3)");
        else if (enforced) console2.log("enforcement: on (another validator; enable restores V3)");
        else console2.log("enforcement: off");
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

    /// @dev Compares with the target, not with on/off, so `enable` also replaces a validator
    ///      other than V3.
    function _set(address bears, bool enable_) private {
        address target = enable_ ? TRANSFER_VALIDATOR_V3 : address(0);
        (, address validator) = status(bears);
        if (validator == target) revert AlreadyInState(validator);
        vm.startBroadcast();
        MintABear(bears).setTransferValidator(target);
        vm.stopBroadcast();
        status(bears);
    }
}
