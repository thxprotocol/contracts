// contracts/poll/RulePoll.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

import './BasePoll.sol';

contract RewardRulePoll is BasePoll {
    using SafeMath for uint256;

    uint256 public minTokensPerc = 0;
    uint256 public ruleId;
    uint256 public proposal;

    /**
     * @dev RewardRulePoll constructor
     * @param _ruleId Id of the referenced Rule
     * @param _proposal Id of the referenced Rule
     * @param _duration Poll start time
     * @param _tokenAddress ERC20 compatible token contract address
     * @param _poolAddress Reward Pool contract address
     * @param _minTokensPerc Minimum token percentage for this poll
     */
    constructor(
        uint256 _ruleId,
        uint256 _proposal,
        uint256 _duration,
        address _tokenAddress,
        address _poolAddress,
        uint256 _minTokensPerc
    ) public BasePoll(_tokenAddress, _poolAddress, now, now + _duration, false) {
        ruleId = _ruleId;
        proposal = _proposal;
        minTokensPerc = _minTokensPerc;
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
        pool.onRewardRulePollFinish(ruleId, proposal, agree);
    }
}
