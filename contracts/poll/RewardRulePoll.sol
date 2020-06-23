pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

import '../IRewardPool.sol';
import './BasePoll.sol';

contract RulePoll is BasePoll {
    using SafeMath for uint256;

    uint256 public minTokensPerc = 0;
    uint256 public ruleId;
    uint256 public proposal;

    /**
     * @dev RewardRulePoll constructor
     * @param _ruleId Id of the referenced Rule
     * @param _proposal Id of the referenced Rule
     * @param _tokenAddress ERC20 compatible token contract address
     * @param _startTime Poll start time
     * @param _endTime Poll end time
     * @param _minTokensPerc Minimum token percentage for this vote
     * @param _poolAddress Reward Pool contract address
     */
    constructor(
        uint256 _ruleId,
        uint256 _proposal,
        address _tokenAddress,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minTokensPerc,
        address _poolAddress
    ) public {
        ruleId = _ruleId;
        proposal = _proposal;
        minTokensPerc = _minTokensPerc;

        __BasePoll_init(_tokenAddress, _poolAddress, _startTime, _endTime, false);
    }

    /**
     * @dev calculate the new votedTokensPercentage based on the last votes compared to the total supply.
     */
    function getVotedTokensPerc() public view returns (uint256) {
        uint256 totalVotes = yesCounter.add(noCounter);
        return totalVotes.mul(100).div(token.totalSupply());
    }

    /**
     * @dev override default approval check and implements the new votedTokensPercentage
     */
    function isSubjectApproved() internal override view returns (bool) {
        return yesCounter > noCounter && getVotedTokensPerc() >= minTokensPerc;
    }

    /**
     * @dev callback called after poll finalization
     */
    function onPollFinish(bool agree) internal override {
        pool.onRulePollFinish(ruleId, agree, proposal);
    }
}
