pragma solidity ^0.5.0;

import './token/ERC20/ERC20Mintable.sol';

contract THXToken is ERC20Mintable {
    string public name;
    string public symbol;
    uint256 public decimals;

    mapping (address => mapping (address => uint256)) private _allowedDeposits;

    constructor() public
    {
        name = "THX Token";
        symbol = "THX";
        decimals = 18;
    }

    function approveDeposit(address from, address to, uint256 value) public returns (bool) {
        require(to != address(0));

        _allowedDeposits[from][to] = value;
        emit Approval(from, to, value);
        return true;
    }

    function transferDeposit(address from, address to, uint256 value) public returns (bool) {
        _allowedDeposits[from][to] = _allowedDeposits[from][to].sub(value);
        _transfer(from, to, value);
        emit Approval(from, to, _allowedDeposits[from][to]);
        return true;
    }

}
