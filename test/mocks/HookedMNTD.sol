// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @dev Implemented by a holder contract that wants to act while its tokens are being burned.
interface IBurnHook {
    function onBurn() external;
}

/// @dev A hostile $MNTD stand-in: `burnFrom` calls back into the holder before burning, the way a
///      token with transfer hooks could. Used to show `Activation.burn` refuses the nested call.
contract HookedMNTD {
    function decimals() external pure returns (uint8) {
        return 18;
    }

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function burnFrom(address account, uint256 amount) external {
        if (account.code.length != 0) IBurnHook(account).onBurn();
        allowance[account][msg.sender] -= amount;
        balanceOf[account] -= amount;
        totalSupply -= amount;
    }
}
