pragma solidity ^0.5.0;

/**
 * @title IRewardPool
 * @dev Fund callbacks used by polling contracts
 */
interface IRewardPool {
    /**
     * @dev RulePoll callback
     * @param id The referenced reward
     * @param agree True if the rule should apply or change
     * @param proposedAmount The proposed reward size
     */
    function onRulePollFinish(uint256 id, bool agree, uint256 proposedAmount) external;

    /**
     * @dev RewardPoll callback
     * @param id The referenced reward
     * @param agree True if the rule should apply or change
     */
    function onRewardPollFinish(uint256 id, bool agree) external;

}
