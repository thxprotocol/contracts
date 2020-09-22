// contracts/poll/WithdrawPoll.sol
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol';

import './BasePoll.sol';
import '../access/Roles.sol';

contract WithdrawPoll is BasePoll, Roles {
    using SafeMath for uint256;

    enum RewardState { Pending, Approved, Rejected, Withdrawn }

    address public beneficiary;
    uint256 public amount;
    IERC20 public token;
    RewardState public state;

    /**
     * @dev WithdrawPoll Constructor
     * @param _beneficiary Beneficiary of the reward
     * @param _amount Size of the reward
     * @param _duration Poll duration
     * @param _poolAddress Asset Pool contract address
     * @param _tokenAddress ERC20 compatible token contract address
     */
    constructor(
        address _beneficiary,
        uint256 _amount,
        uint256 _duration,
        address _poolAddress,
        address _tokenAddress
    // warning: the length of the poll is dependent on the time the block is mined.
    // could lead to unexpected business logic.
    ) public BasePoll(_poolAddress, now, now + _duration) {
        require(address(_beneficiary) != address(0), 'IS_INVALID_ADDRESS');

        beneficiary = _beneficiary;
        amount = _amount;
        token = IERC20(_tokenAddress);
        state = RewardState.Pending;
    }

    /**
     * @dev Withdraw accumulated balance for a beneficiary.
     */
    function withdraw() public {
        require(state == RewardState.Approved, 'IS_NOT_APPROVED');
        require(_msgSender() == beneficiary, 'IS_NOT_BENEFICIARY');
        // check below could be deleted to save gast costs, as onWithdrawal will fail
        // if the balance is insufficient.
        require(token.balanceOf(address(pool)) >= amount, 'INSUFFICIENT_BALANCE');

        state = RewardState.Withdrawn;

        pool.onWithdrawal(address(this), beneficiary, amount);
    }

    /**
     * @dev callback called after poll finalization
     */
    function onPollFinish(bool agree) internal override {
        if (agree && finalized) {
            state = RewardState.Approved;
        } else {
            state = RewardState.Rejected;
        }

        pool.onWithdrawPollFinish(address(this), agree);
    }
}
