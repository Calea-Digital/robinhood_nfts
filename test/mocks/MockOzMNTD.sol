// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @dev $MNTD stand-in built on OpenZeppelin's `ERC20Burnable` (4.7, as vendored by SeaDrop): the
 *      shape `Activation` assumes of the real token. Unlike `MockMNTD` it emits the ERC-20
 *      `Transfer(holder, 0x0, amount)` on `burnFrom` and reverts with OpenZeppelin's strings. Used
 *      by the client library's tests (`packages/contracts-client`), where a burn transaction's
 *      logs must carry the token's own `Transfer` beside `BearActivated`.
 */
contract MockOzMNTD is ERC20Burnable {
    constructor() ERC20("Mint Token", "MNTD") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
