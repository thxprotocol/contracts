// contracts/rewards/Rewards.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.4;

/**
 * @title IRewardPool
 * @dev Fund callbacks used by polling contracts
 */
interface IRewardPool {
    /**
     * @dev RulePoll callback
     * @param id The referenced rule
     * @param agree True if the rule should apply or change
     * @param proposedAmount The proposed reward size
     */
    function onRulePollFinish(
        uint256 id,
        bool agree,
        uint256 proposedAmount
    ) external;

    /**
     * @dev RewardPoll callback
     * @param id The referenced reward
     * @param agree True if the rule should apply or change
     */
    function onRewardPollFinish(uint256 id, bool agree) external;

    /**
     * @dev Withdrawal callback
     * @param _id Reference to the reward
     * @param _beneficiary Receiver of the reward
     * @param _amount Size of the reward
     */
    function onWithdrawal(
        uint256 _id,
        address _beneficiary,
        uint256 _amount
    ) external;
}
