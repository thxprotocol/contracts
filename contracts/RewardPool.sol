// contracts/RewardPool.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./rewards/Rewards.sol";
import "./rules/RewardRules.sol";


contract RewardPool is Ownable, AccessControl, Reward, RewardRules {
    using SafeMath for uint256;

    enum RuleState {Active, Disabled}

    event Deposited(address indexed sender, uint256 amount);
    event Withdrawn(address indexed beneficiary, uint256 reward);
    event RewardPollCreated(uint256 id, address reward);
    event RewardPollFinished(uint256 id, address reward, bool approved);
    event RulePollCreated(uint256 id, uint256 proposedAmount, address sender);
    event RulePollFinished(uint256 id, bool approved, address sender);
    event RuleStateChanged(uint256 id, RuleState state, address sender);

    struct Rule {
        uint256 id;
        uint256 amount;
        RuleState state;
        RulePoll poll;
        address creator;
        uint256 created;
    }

    struct Deposit {
        uint256 amount;
        address sender;
        uint256 created;
    }

    struct Withdrawel {
        uint256 amount;
        address receiver;
        uint256 created;
    }
}
