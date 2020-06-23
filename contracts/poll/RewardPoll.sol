// contracts/rewards/Rewards.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol';

import './BasePoll.sol';
import '../access/Roles.sol';

contract RewardPoll is BasePoll, Roles {
    using SafeMath for uint256;

    enum RewardState { Pending, Approved, Rejected, Withdrawn }

    RewardState public state;

    mapping(address => uint256[]) public voters;

    uint256 public id;
    address public beneficiary;
    uint256 public amount;
    uint256 public duration;

    constructor(
        uint256 _id,
        address _beneficiary,
        uint256 _amount,
        uint256 _duration,
        address _tokenAddress,
        address _poolAddress
    ) public {
        require(address(_poolAddress) == msg.sender, 'caller is not the reward pool');

        id = _id;
        beneficiary = _beneficiary;
        amount = _amount;
        state = RewardState.Pending;
        duration = _duration;

        __BasePoll_init(_tokenAddress, _poolAddress, now, now + _duration, false);
    }

    /**
     * @dev Withdraw accumulated balance for a beneficiary.
     */
    function withdraw() public {
        uint256 poolBalance = token.balanceOf(address(pool));

        require(state == RewardState.Approved, 'reward is not approved');
        require(msg.sender == beneficiary, 'claimer is not the beneficiary');
        require(poolBalance >= amount, 'pool balance is not sufficient');

        tryToFinalize();

        pool.onWithdrawel(beneficiary, amount, startTime);

        state = RewardState.Withdrawn;
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

        pool.onRewardPollFinish(id, agree);
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
