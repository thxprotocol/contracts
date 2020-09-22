// contracts/poll/RulePoll.sol
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

import './BasePoll.sol';

contract RewardRulePoll is BasePoll {
    using SafeMath for uint256;

    uint256 public ruleId;
    uint256 public amount;

    /**
     * @dev RewardRulePoll constructor
     * @param _ruleId Id of the referenced Rule
     * @param _amount Total amount of the reward Rule
     * @param _duration Poll start time
     * @param _poolAddress Reward Pool contract address
     */
    constructor(
        uint256 _ruleId,
        uint256 _amount,
        uint256 _duration,
        address _poolAddress
    ) public BasePoll(_poolAddress, now, now + _duration) {
        ruleId = _ruleId;
        amount = _amount;
    }

    /**
     * @dev callback called after poll finalization
     */
    function onPollFinish(bool agree) internal override {
        pool.onRewardRulePollFinish(ruleId, amount, agree);
    }
}
