pragma solidity ^0.4.24;

import './token/TransferLimitedToken.sol';


contract THXToken is TransferLimitedToken {
    uint256 public constant SALE_END_TIME = 1538344800; // Mon, 01 Oct 2018 00:00:00 +0200

    constructor(address _listener, address[] _owners, address manager) public
        TransferLimitedToken(SALE_END_TIME, _listener, _owners, manager)
    {
        name = "THX Token";
        symbol = "THX";
        decimals = 18;
    }
}
