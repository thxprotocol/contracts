pragma solidity ^0.6.4;

import './token/ERC20/ERC20Mintable.sol';

contract THXTokenRinkeby is ERC20Mintable {
    string public name;
    string public symbol;
    uint256 public decimals;

    constructor() public
    {
        name = "THX Token";
        symbol = "THX";
        decimals = 18;
    }
}
