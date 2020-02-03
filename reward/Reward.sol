pragma solidity ^0.5.0;

import '../access/roles/MemberRole.sol';
import '../math/SafeMath.sol';
import '../token/ERC20/IERC20.sol';
import '../poll/BasePoll.sol';

contract Reward is BasePoll, MemberRole {
    using SafeMath for uint256;

    enum RewardState { Pending, Approved, Rejected, Withdrawn }

    event RewardStateChanged(uint256 id, RewardState state);

    uint256 public constant REWARD_POLL_DURATION = 1 minutes;

    uint256 public id;
    uint256 public rule;
    address public beneficiary;
    uint256 public amount;
    RewardState public state;
    uint256 public created;

    mapping (address => uint256[]) public voters;

    constructor(
        uint256 _id,
        uint256 _rule,
        address _beneficiary,
        uint256 _amount,
        address _tokenAddress,
        address _poolAddress
    ) public onlyMember
        BasePoll(_tokenAddress, _poolAddress, now, now + REWARD_POLL_DURATION, false)
    {
        id = _id;
        rule = _rule;
        beneficiary = _beneficiary;
        amount = _amount;
        state = RewardState.Pending;
        created = now;

        emit RewardStateChanged(id, state);
    }

    /**
    * @dev Check if the reward is approved.
    */
    function withdrawalAllowed() public view returns (bool) {
        return state == RewardState.Approved;
    }

    /**
    * @dev Withdraw accumulated balance for a beneficiary.
    */
    function withdraw() public {
        uint256 poolBalance = token.balanceOf(address(pool));

        require(withdrawalAllowed());
        require(msg.sender == beneficiary);
        require(amount > 0);
        require(poolBalance >= amount);

        pool.onWithdrawel(beneficiary, amount, created);

        state = RewardState.Withdrawn;
    }

    /**
    * @dev callback called after poll finalization
    */
    function onPollFinish(bool agree) internal {
        if (agree && finalized) {
            _onApproval();
        }
        else {
            _onRejection();
        }

        pool.onRewardPollFinish(id, agree);
    }

    /**
    * @dev callback called after reward is withdrawn
    */
    function _onApproval() internal {
        state = RewardState.Approved;
        emit RewardStateChanged(id, state);
    }

    /**
    * @dev callback called after reward is rejected
    */
    function _onRejection() internal {
        state = RewardState.Rejected;
        emit RewardStateChanged(id, state);
    }

}
