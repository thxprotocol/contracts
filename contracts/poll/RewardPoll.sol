// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./BasePoll.sol";

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
     * @param _endtime Poll end time
     * @param _poolAddress Asset Pool contract address
     * @param _gasStation Address of the gas station
     */
    constructor(
        uint256 _id,
        uint256 _withdrawAmount,
        uint256 _withdrawDuration,
        uint256 _endtime,
        address _poolAddress,
        address _gasStation
    ) public BasePoll(_poolAddress, _gasStation, now, _endtime) {
        id = _id;
        withdrawAmount = _withdrawAmount;
        withdrawDuration = _withdrawDuration;
    }

    /**
     * @dev callback called after poll finalization
     */
    function onPollFinish(bool _agree) internal override {
        pool.onRewardPollFinish(id, withdrawAmount, withdrawDuration, _agree);
    }

    /**
     * @dev callback called after poll finalization
     * @param _agree True if user endorses the proposal else False
     */
    function vote(bool _agree) external override {
        address _voter = _msgSigner();
        require(pool.isMember(_voter), "NO_MEMBER");
        _vote(_agree, _voter);
    }

    /**
     * @dev Revoke user`s vote
     */
    function revokeVote() external override {
        address _voter = _msgSigner();
        require(pool.isMember(_voter), "NO_MEMBER");
        _revokeVote(_voter);
    }
}
