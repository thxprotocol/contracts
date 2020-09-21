// contracts/THXToken.sol
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

import '../IRewardPool.sol';

contract BasePoll {
    using SafeMath for uint256;

    struct Vote {
        uint256 time;
        uint256 weight;
        bool agree;
    }

    IRewardPool public pool;

    uint256 public startTime;
    uint256 public endTime;

    uint256 public yesCounter = 0;
    uint256 public noCounter = 0;
    uint256 public totalVoted = 0;

    bool public bypassVotes = true;
    bool public finalized = false;

    mapping(address => Vote) public votesByAddress;

    modifier checkTime() {
        require(now >= startTime && now <= endTime, 'IS_NO_VALID_TIME');
        _;
    }

    modifier notFinalized() {
        require(!finalized, 'IS_FINALIZED');
        _;
    }

    /**
     * @dev BasePoll Constructor
     * @param _poolAddress Reward Pool contract address
     * @param _startTime Poll start time
     * @param _endTime Poll end time
     */
    constructor(
        address _poolAddress,
        uint256 _startTime,
        uint256 _endTime
    ) public {
        require(_poolAddress != address(0), 'IS_INVALID_ADDRESS');
        require(_startTime >= now, 'IS_NO_VALID_TIME');

        pool = IRewardPool(_poolAddress);

        startTime = _startTime;
        endTime = _endTime;

        if (_startTime == _endTime) {
            bypassVotes = true;
        }
    }

    /**
     * @dev Process user`s vote
     * @param voter The address of the user voting
     * @param agree True if user endorses the proposal else False
     */
    function vote(address voter, bool agree) external checkTime {
        require(voter != address(0), 'IS_INVALID_ADDRESS');
        require(votesByAddress[voter].time == 0, 'HAS_VOTED');

        uint256 voiceWeight = 1;

        if (agree) {
            yesCounter = yesCounter.add(voiceWeight);
        } else {
            noCounter = noCounter.add(voiceWeight);
        }

        votesByAddress[voter].time = now;
        votesByAddress[voter].weight = voiceWeight;
        votesByAddress[voter].agree = agree;

        totalVoted = totalVoted.add(1);
    }

    /**
     * @dev Revoke user`s vote
     * @param voter The address of the user voting
     */
    function revokeVote(address voter) external checkTime {
        require(votesByAddress[voter].time > 0, 'HAS_NOT_VOTED');

        uint256 voiceWeight = votesByAddress[voter].weight;
        bool agree = votesByAddress[voter].agree;

        votesByAddress[voter].time = 0;
        votesByAddress[voter].weight = 0;
        votesByAddress[voter].agree = false;

        totalVoted = totalVoted.sub(1);
        if (agree) {
            yesCounter = yesCounter.sub(voiceWeight);
        } else {
            noCounter = noCounter.sub(voiceWeight);
        }
    }

    /**
     * Finalize poll and call onPollFinish callback with result
     */
    function tryToFinalize() public notFinalized returns (bool) {
        if (now < endTime && bypassVotes == false) {
            return false;
        }
        finalized = true;
        onPollFinish(isSubjectApproved());
        return true;
    }

    function isNowApproved() public view returns (bool) {
        return isSubjectApproved();
    }

    function isSubjectApproved() internal virtual view returns (bool) {
        return yesCounter > noCounter || bypassVotes == true;
    }

    /**
     * @dev callback called after poll finalization
     */
    function onPollFinish(bool agree) internal virtual {}
}
