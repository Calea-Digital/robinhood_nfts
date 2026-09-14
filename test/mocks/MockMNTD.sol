// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @dev Minimal $MNTD stand-in: the burnFrom + allowance shape the build assumes.
contract MockMNTD {
    string public constant name = "Mint Token";
    string public constant symbol = "MNTD";
    uint8 public immutable DECIMALS;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    error InsufficientAllowance();
    error InsufficientBalance();

    constructor(uint8 decimals_) {
        DECIMALS = decimals_;
    }

    function decimals() external view returns (uint8) {
        return DECIMALS;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    /// @dev Present so a bear's account can be shown moving $MNTD out through `execute`.
    function transfer(address to, uint256 amount) external returns (bool) {
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function burnFrom(address account, uint256 amount) external {
        uint256 allowed = allowance[account][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (balanceOf[account] < amount) revert InsufficientBalance();
        allowance[account][msg.sender] = allowed - amount;
        balanceOf[account] -= amount;
        totalSupply -= amount;
    }
}
