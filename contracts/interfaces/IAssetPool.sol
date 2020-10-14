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
     * @param _reward Address of the reward
     * @param _beneficiary Receiver of the reward
     * @param _amount Size of the reward
     */
    function onWithdrawal(
        address _reward,
        address _beneficiary,
        uint256 _amount
    ) external;

    /**
     * @dev Validate a given nonce, reverts if nonce is not right
     * @param _member Address of the voter
     * @param _nonce Nonce of the voter
     */
    function validateNonce(address _member, uint256 _nonce) external;

    /**
     * @dev Get the latest nonce of a given voter
     * @param _member Address of the voter
     */
    function getLatestNonce(address _member) external view returns (uint256);
}
