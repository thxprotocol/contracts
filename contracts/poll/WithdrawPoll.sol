// contracts/poll/WithdrawPoll.sol
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol';

import './BasePoll.sol';
import '../access/Roles.sol';

contract WithdrawPoll is BasePoll, Roles {
    using SafeMath for uint256;

    enum WithdrawState { Pending, Approved, Rejected, Withdrawn }

    address public beneficiary;
    uint256 public amount;
    IERC20 public token;
    WithdrawState public state;

    /**
     * @dev WithdrawPoll Constructor
     * @param _beneficiary Beneficiary of the withdrawal
     * @param _amount Size of the withdrawal
     * @param _duration Poll duration
     * @param _poolAddress Asset Pool contract address
     * @param _voteAdmin Address that is able to send signed message to vote and revokeVote
     * @param _tokenAddress ERC20 compatible token contract address
     */
    constructor(
        address _beneficiary,
        uint256 _amount,
        uint256 _duration,
        address _poolAddress,
        address _voteAdmin,
        address _tokenAddress
    )
        public
        // warning: the length of the poll is dependent on the time the block is mined.
        // could lead to unexpected business logic.
        BasePoll(_poolAddress, _voteAdmin, now, now + _duration)
    {
        // TODO, to discuss, Could be a valid address if pools decide to burn tokens?
        require(address(_beneficiary) != address(0), 'IS_INVALID_ADDRESS');

        beneficiary = _beneficiary;
        amount = _amount;
        token = IERC20(_tokenAddress);
        state = WithdrawState.Pending;
    }

    /**
     * @dev Withdraw accumulated balance for a beneficiary.
     */
    function withdraw() public {
        require(state == WithdrawState.Approved, 'IS_NOT_APPROVED');
        require(msg.sender == beneficiary, 'IS_NOT_BENEFICIARY');
        // check below could be deleted to save gast costs, as onWithdrawal will fail
        // if the balance is insufficient.
        require(token.balanceOf(address(pool)) >= amount, 'INSUFFICIENT_BALANCE');

        state = WithdrawState.Withdrawn;

        pool.onWithdrawal(address(this), beneficiary, amount);
    }

    /**
     * @dev callback called after poll finalization
     */
    function onPollFinish(bool agree) internal override {
        if (agree && finalized) {
            state = WithdrawState.Approved;
        } else {
            state = WithdrawState.Rejected;
        }
    }
}
