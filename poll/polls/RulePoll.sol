pragma solidity ^0.5.0;

import '../../IRewardPool.sol';
import '../../math/SafeMath.sol';
import '../BasePoll.sol';

contract RulePoll is BasePoll {
    using SafeMath for uint256;

    uint256 public minTokensPerc = 0;
    uint256 public id;
    uint256 public proposedAmount;

    IRewardPool public pool;

    /**
     * @dev RulePoll constructor
     * @param _id Id of the referenced Reward
     * @param _tokenAddress ERC20 compatible token contract address
     * @param _startTime Poll start time
     * @param _endTime Poll end time
     * @param _minTokensPerc Minimum token percentage for this vote
     * @param _poolAddress Reward Pool contract address
     */
    constructor(
        uint256 _id,
        uint256 _proposedAmount,
        address _tokenAddress,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minTokensPerc,
        address _poolAddress
    ) public
        BasePoll(_tokenAddress, _poolAddress, _startTime, _endTime, false)
    {
        id = _id;
        minTokensPerc = _minTokensPerc;
        proposedAmount = _proposedAmount;

        pool = IRewardPool(_poolAddress);
    }

    /**
     * @dev calculate the new votedTokensPercentage based on the last votes compared to the total supply.
     */
    function getVotedTokensPerc() public view returns(uint256) {
        uint256 totalVotes = yesCounter.add(noCounter);
        return totalVotes.mul(100).div(token.totalSupply());
    }

    /**
     * @dev override default approval check and implements the new votedTokensPercentage
     */
    function isSubjectApproved() internal view returns(bool) {
        return yesCounter > noCounter && getVotedTokensPerc() >= minTokensPerc;
    }

    /**
     * @dev callback called after poll finalization
     */
     function onPollFinish(bool agree) internal {
         pool.onRulePollFinish(id, agree, proposedAmount);
     }

}
