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
     * @param _endtime Poll end time
     * @param _poolAddress Asset Pool contract address
     * @param _voteAdmin Address that is able to send signed message to vote and revokeVote
     * @param _tokenAddress ERC20 compatible token contract address
     */
    constructor(
        address _beneficiary,
        uint256 _amount,
        uint256 _endtime,
        address _poolAddress,
        address _voteAdmin,
        address _tokenAddress
    ) public BasePoll(_poolAddress, _voteAdmin, now, _endtime) {
        // TODO, to discuss, Could be a valid address if pools decide to burn tokens?
        require(address(_beneficiary) != address(0), 'IS_INVALID_ADDRESS');

        beneficiary = _beneficiary;
        amount = _amount;
        token = IERC20(_tokenAddress);
        state = WithdrawState.Pending;
    }

    /**
     * @dev Withdraw accumulated balance for a beneficiary.
     * @param _member The address of the member
     * @param _nonce Number only used once
     * @param _sig The signed parameters
     */
    function withdraw(
        uint256 _nonce,
        address _member,
        bytes calldata _sig
    ) public onlyVoteAdmin useNonce(_member, _nonce) {
        bytes32 message = Signature.prefixed(keccak256(abi.encodePacked(_nonce, voteAdmin, this)));
        require(Signature.recoverSigner(message, _sig) == _member, 'WRONG_SIG');

        require(state == WithdrawState.Approved, 'IS_NOT_APPROVED');
        require(_member == beneficiary, 'IS_NOT_BENEFICIARY');
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
