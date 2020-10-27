// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './BasePoll.sol';

contract WithdrawPoll is BasePoll {
    using SafeMath for uint256;

    address public beneficiary;
    uint256 public amount;

    /**
     * @dev WithdrawPoll Constructor
     * @param _beneficiary Beneficiary of the withdrawal
     * @param _amount Size of the withdrawal
     * @param _endtime Poll end time
     * @param _poolAddress Asset Pool contract address
     * @param _gasStation Address of the gas station
     */
    constructor(
        address _beneficiary,
        uint256 _amount,
        uint256 _endtime,
        address _poolAddress,
        address _gasStation
    ) public BasePoll(_poolAddress, _gasStation, now, _endtime) {
        // TODO, to discuss, Could be a valid address if pools decide to burn tokens?
        require(address(_beneficiary) != address(0), 'IS_INVALID_ADDRESS');

        beneficiary = _beneficiary;
        amount = _amount;
    }

    /**
     * @dev callback called after poll finalization
     */
    function onPollFinish(bool _agree) internal override {
        pool.onWithdrawalPollFinish(beneficiary, amount, _agree);
    }

    /**
     * @dev callback called after poll finalization
     * @param _agree True if user endorses the proposal else False
     */
    function vote(bool _agree) external override {
        address _voter = _msgSigner();
        require(pool.isManager(_voter), 'NO_MANAGER');
        _vote(_agree, _voter);
    }

    /**
     * @dev Revoke user`s vote
     */
    function revokeVote() external override {
        address _voter = _msgSigner();
        require(pool.isManager(_voter), 'NO_MANAGER');
        _revokeVote(_voter);
    }
}
