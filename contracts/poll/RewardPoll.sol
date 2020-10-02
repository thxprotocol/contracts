// contracts/poll/RewardPoll.sol
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

import './BasePoll.sol';

contract RewardPoll is BasePoll {
    using SafeMath for uint256;

    uint256 public id;
    uint256 public withdrawAmount;
    uint256 public withdrawDuration;

    /**
     * @dev RewardPoll constructor
     * @param _id Id of the referenced reward
     * @param _withdrawAmount Total amount of the withdraw linked to the reward
     * @param _withdrawDuration Duration for voting of the withdrawal
     * @param _duration Duration of this the reward poll
     * @param _poolAddress Asset Pool contract address
     * @param _voteAdmin Address that is able to send signed message to vote and revokeVote
     */
    constructor(
        uint256 _id,
        uint256 _withdrawAmount,
        uint256 _withdrawDuration,
        uint256 _duration,
        address _poolAddress,
        address _voteAdmin
    ) public BasePoll(_poolAddress, _voteAdmin, now, now + _duration) {
        id = _id;
        withdrawAmount = _withdrawAmount;
        withdrawDuration = _withdrawDuration;
    }

    /**
     * @dev callback called after poll finalization
     */
    function onPollFinish(bool agree) internal override {
        pool.onRewardPollFinish(id, withdrawAmount, withdrawDuration, agree);
    }
}
