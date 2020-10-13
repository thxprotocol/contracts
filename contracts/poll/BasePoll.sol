// contracts/THXToken.sol
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

import '../IAssetPool.sol';
import '../lib/Signature.sol';

contract BasePoll {
    using SafeMath for uint256;

    struct Vote {
        uint256 time;
        uint256 weight;
        bool agree;
    }

    IAssetPool public pool;
    address public voteAdmin;

    uint256 public startTime;
    uint256 public endTime;

    uint256 public yesCounter = 0;
    uint256 public noCounter = 0;
    uint256 public totalVoted = 0;

    bool public bypassVotes = false;
    bool public finalized = false;

    mapping(address => Vote) public votesByAddress;

    modifier checkTime() {
        require(now >= startTime && now <= endTime, 'IS_NO_VALID_TIME');
        _;
    }

    modifier onlyVoteAdmin() {
        require(msg.sender == voteAdmin, 'caller is not the voteAdmin');
        _;
    }

    modifier notFinalized() {
        require(!finalized, 'IS_FINALIZED');
        _;
    }

    modifier useNonce(address _voter, uint256 _nonce) {
        pool.validateNonce(_voter, _nonce);
        _;
    }

    /**
     * @dev BasePoll Constructor
     * @param _poolAddress Asset Pool contract address
     * @param _voteAdmin Address that is able to send signed message to vote and revokeVote
     * @param _startTime Poll start time
     * @param _endTime Poll end time
     */
    constructor(
        address _poolAddress,
        address _voteAdmin,
        uint256 _startTime,
        uint256 _endTime
    ) public {
        require(_poolAddress != address(0), 'IS_INVALID_ADDRESS');
        require(_startTime >= now, 'IS_NO_VALID_TIME');
        require(_endTime >= _startTime, 'IS_NO_VALID_TIME');

        pool = IAssetPool(_poolAddress);

        startTime = _startTime;
        endTime = _endTime;
        voteAdmin = _voteAdmin;

        if (_startTime == _endTime) {
            bypassVotes = true;
        }
    }

    /**
     * @dev Process user`s vote
     * @param _voter The address of the user voting
     * @param _agree True if user endorses the proposal else False
     * @param _nonce Number only used once
     * @param _sig The signed parameters
     */
    function vote(
        address _voter,
        bool _agree,
        uint256 _nonce,
        bytes calldata _sig
    )
        external
        // _voter parameter can be removed. as _voter is recoverd with recoverSigner.
        // but _voter is currently used by useNonce for readability.
        checkTime
        onlyVoteAdmin
        useNonce(_voter, _nonce)
    {
        bytes32 message = Signature.prefixed(keccak256(abi.encodePacked(voteAdmin, _agree, _nonce, this)));
        require(Signature.recoverSigner(message, _sig) == _voter, 'WRONG_SIG');
        require(votesByAddress[_voter].time == 0, 'HAS_VOTED');
        require(pool.isMember(_voter), 'NO_MEMBER');

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
     * @param _voter The address of the user voting
     * @param _nonce Number only used once
     * @param _sig The signed parameters
     */
    function revokeVote(
        address _voter,
        uint256 _nonce,
        bytes calldata _sig
    ) external checkTime onlyVoteAdmin useNonce(_voter, _nonce) {
        bytes32 message = Signature.prefixed(keccak256(abi.encodePacked(voteAdmin, _nonce, this)));
        require(Signature.recoverSigner(message, _sig) == _voter);
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
    function tryToFinalize() public notFinalized returns (bool) {
        if (now < endTime && bypassVotes == false) {
            return false;
        }
        finalized = true;
        onPollFinish(isSubjectApproved());
        return true;
    }

    // why are there 2 view methods with the same return value?
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
