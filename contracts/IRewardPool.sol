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
     * @dev Withdrawel callback
     * @param beneficiary The addres of the account receiving the reward
     * @param amount The amount the beneficiary will receive
     * @param created The timestamp of the moment the reward was claimed
     */
    function onWithdrawel(
        address beneficiary,
        uint256 amount,
        uint256 created
    ) external;
}
