// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

/**
 * @title IAssetPool
 * @dev Fund callbacks used by polling contracts
 */
interface IAssetPool {
    /**
     * @dev Check if an address is a pool member
     */
    function isMember(address) external view returns (bool);

    function isManager(address) external view returns (bool);

    /**
     * @dev RewardPoll callback
     * @param _id The referenced reward
     * @param _withdrawAmount The proposed reward size
     * @param _withdrawDuration The proposed reward size
     * @param _agree True if the reward should apply or change
     */
    function onRewardPollFinish(
        uint256 _id,
        uint256 _withdrawAmount,
        uint256 _withdrawDuration,
        bool _agree
    ) external;

    /**
     * @dev Withdrawal callback
     * @param _beneficiary Receiver of the reward
     * @param _amount Size of the reward
     * @param _agree True if the reward should apply or change
     */
    function onWithdrawalPollFinish(
        address _beneficiary,
        uint256 _amount,
        bool _agree
    ) external;
}
