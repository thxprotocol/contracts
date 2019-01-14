pragma solidity ^0.5.0;

import './token/ERC20/ERC20Mintable.sol';

contract THXToken is ERC20Mintable {
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
