// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts/math/SafeMath.sol';

import '../interfaces/IAssetPool.sol';
import '../gas_station/RelayReceiver.sol';

contract BasePoll is RelayReceiver {
    using SafeMath for uint256;

    struct Vote {
        uint256 time;
        uint256 weight;
        bool agree;
    }

    IAssetPool public pool;
    address public gasStation;

    uint256 public startTime;
    uint256 public endTime;

    uint256 public yesCounter = 0;
    uint256 public noCounter = 0;
    uint256 public totalVoted = 0;

    bool public bypassVotes = false;

    mapping(address => Vote) public votesByAddress;

    modifier checkTime() {
        require(now >= startTime && now <= endTime, 'IS_NO_VALID_TIME');
        _;
    }

    modifier onlyGasStation() {
        require(msg.sender == gasStation, 'caller is not the gasStation');
        _;
    }

    /**
     * @dev BasePoll Constructor
     * @param _poolAddress Asset Pool contract address
     * @param _gasStation Address of the gas station
     * @param _startTime Poll start time
     * @param _endTime Poll end time
     */
    // TODO WARNING: public constructor anyone can make a basepoll directly
    // Only AssetPool should be able to create polls, (verify msg.sender)
    constructor(
        address _poolAddress,
        address _gasStation,
        uint256 _startTime,
        uint256 _endTime
    ) public {
        require(_poolAddress != address(0), 'IS_INVALID_ADDRESS');
        require(_startTime >= now, 'IS_NO_VALID_TIME');
        require(_endTime >= _startTime, 'IS_NO_VALID_TIME');

        pool = IAssetPool(_poolAddress);

        startTime = _startTime;
        endTime = _endTime;
        gasStation = _gasStation;

        if (_startTime == _endTime) {
            bypassVotes = true;
        }
    }

    /**
     * @dev callback called after poll finalization
     * @param _agree True if user endorses the proposal else False
     */
    function vote(bool _agree) external virtual {}

    /**
     * @dev Process user`s vote
     * @param _agree True if user endorses the proposal else False
     * @param _voter The address of the voter
     */
    function _vote(bool _agree, address _voter) internal checkTime onlyGasStation {
        require(votesByAddress[_voter].time == 0, 'HAS_VOTED');
        uint256 voiceWeight = 1;

        if (_agree) {
            yesCounter = yesCounter.add(voiceWeight);
        } else {
            noCounter = noCounter.add(voiceWeight);
        }

        votesByAddress[_voter].time = now;
        votesByAddress[_voter].weight = voiceWeight;
        votesByAddress[_voter].agree = _agree;

        totalVoted = totalVoted.add(1);
    }

    /**
     * @dev Revoke user`s vote
     */
    function revokeVote() external checkTime onlyGasStation {
        address _voter = _msgSigner();
        require(votesByAddress[_voter].time > 0, 'HAS_NOT_VOTED');

        uint256 voiceWeight = votesByAddress[_voter].weight;
        bool agree = votesByAddress[_voter].agree;

        votesByAddress[_voter].time = 0;
        votesByAddress[_voter].weight = 0;
        votesByAddress[_voter].agree = false;

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
    function finalize() public {
        require(now >= endTime || bypassVotes == true, 'WRONG_STATE');
        onPollFinish(getCurrentApprovalState());
        selfdestruct(payable(gasStation));
    }

    function getCurrentApprovalState() public view returns (bool) {
        return yesCounter > noCounter || bypassVotes == true;
    }

    /**
     * @dev callback called after poll finalization
     */
    function onPollFinish(bool _agree) internal virtual {}
}
