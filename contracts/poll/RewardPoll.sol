// contracts/poll/RewardPoll.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol';

import './BasePoll.sol';
import '../access/Roles.sol';

contract RewardPoll is BasePoll, Roles {
    using SafeMath for uint256;

    enum RewardState { Pending, Approved, Rejected, Withdrawn }

    RewardState public state;

    mapping(address => uint256[]) public voters;

    address public beneficiary;
    uint256 public amount;

    constructor(
        address _beneficiary,
        uint256 _amount,
        uint256 _duration,
        address _tokenAddress,
        address _poolAddress
    ) public BasePoll(_tokenAddress, _poolAddress, now, now + _duration, false) {
        require(_amount > 0, 'amount is not larger than zero');
        require(address(_beneficiary) != address(0), 'not a valid address');

        beneficiary = _beneficiary;
        amount = _amount;
        state = RewardState.Pending;
    }

    /**
     * @dev Withdraw accumulated balance for a beneficiary.
     */
    function withdraw() public {
        uint256 poolBalance = token.balanceOf(address(pool));

        require(state == RewardState.Approved, 'reward is not approved');
        require(msg.sender == beneficiary, 'claimer is not the beneficiary');
        require(poolBalance >= amount, 'pool balance is not sufficient');

        state = RewardState.Withdrawn;

        pool.onWithdrawal(address(this), beneficiary, amount);
    }

    /**
     * @dev callback called after poll finalization
     */
    function onPollFinish(bool agree) internal override {
        if (agree && finalized) {
            _onApproval();
        } else {
            _onRejection();
        }

        pool.onRewardPollFinish(address(this), agree);
    }

    /**
     * @dev callback called after reward is withdrawn
     */
    function _onApproval() internal {
        state = RewardState.Approved;
    }

    /**
     * @dev callback called after reward is rejected
     */
    function _onRejection() internal {
        state = RewardState.Rejected;
    }
}
