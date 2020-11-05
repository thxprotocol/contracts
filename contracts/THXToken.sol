// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract THXToken is ERC20 {
    constructor(address to, uint256 amount) public ERC20('THX Token', 'THX') {
        _mint(to, amount);
    }
}
