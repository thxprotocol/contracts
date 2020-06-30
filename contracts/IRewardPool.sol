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
     * @param _id The referenced rule
     * @param _agree True if the rule should apply or change
     * @param _proposedAmount The proposed reward size
     */
    function onRulePollFinish(
        uint256 _id,
        bool _agree,
        uint256 _proposedAmount
    ) external;

    /**
     * @dev RewardPoll callback
     * @param _reward Address of the referenced reward
     * @param _agree True if the rule should apply or change
     */
    function onRewardPollFinish(address _reward, bool _agree) external;

    /**
     * @dev Withdrawal callback
     * @param _reward Address of the reward
     * @param _beneficiary Receiver of the reward
     * @param _amount Size of the reward
     */
    function onWithdrawal(
        address _reward,
        address _beneficiary,
        uint256 _amount
    ) external;
}
