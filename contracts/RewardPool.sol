// contracts/RewardPool.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./rewards/Rewards.sol";
import "./rules/RewardRules.sol";


contract RewardPool is Ownable, AccessControl {
    using SafeMath for uint256;

    enum RuleState {Active, Disabled}

    constructor() public Ownable() {}
}
