// contracts/poll/RewardPoll.sol
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

import './BasePoll.sol';

contract RewardPoll is BasePoll {
    using SafeMath for uint256;

    uint256 public id;
    uint256 public amount;

    /**
     * @dev RewardPoll constructor
     * @param _id Id of the referenced reward
     * @param _amount Total amount of the reward
     * @param _duration Poll start time
     * @param _poolAddress Reward Pool contract address
     */
    constructor(
        uint256 _id,
        uint256 _amount,
        uint256 _duration,
        address _poolAddress
    ) public BasePoll(_poolAddress, now, now + _duration) {
        id = _id;
        amount = _amount;
    }

    /**
     * @dev callback called after poll finalization
     */
    function onPollFinish(bool agree) internal override {
        pool.onRewardPollFinish(id, amount, agree);
    }
}
