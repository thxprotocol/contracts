pragma solidity ^0.5.0;

import './escrow/Escrow.sol';

contract RewardPool is Escrow {
    string public name;
    string public symbol;

    constructor() public
    {
        name = "GreenPeace Greenwire";
        symbol = "THX";
    }
}
