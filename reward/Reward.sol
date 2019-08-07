pragma solidity ^0.5.0;

import '../access/roles/MemberRole.sol';
import '../math/SafeMath.sol';
import '../token/ERC20/IERC20.sol';
import '../poll/BasePoll.sol';
import '../IRewardPool.sol';

contract Reward is MemberRole, BasePoll {
    using SafeMath for uint256;

    enum RewardState { Pending, Approved, Rejected, Withdrawn }

    event RewardPollCreated();
    event RewardStateChanged(uint256 id, RewardState state);

    uint256 public constant REWARD_POLL_DURATION = 7 days;

    uint256 public id;
    string public slug;
    address public beneficiary;
    uint256 public amount;
    RewardState public state;
    uint256 public created;

    IERC20 public token;
    IRewardPool public pool;

    mapping (address => uint256[]) public voters;

    constructor(
        uint256 _id,
        string memory _slug,
        address _beneficiary,
        uint256 _amount,
        address _tokenAddress,
        address _poolAddress
    ) public onlyMember
        BasePoll(_tokenAddress, now, now + 7 days, false)
    {
        id = _id;
        slug = _slug;
        beneficiary = _beneficiary;
        amount = _amount;
        state = RewardState.Pending;
        created = now;
        token = IERC20(_tokenAddress);
        pool = IRewardPool(_poolAddress);

        emit RewardStateChanged(id, state);
    }

    /**
    * @dev Check if the reward is approved.
    */
    function withdrawalAllowed() public view returns (bool) {
        return state == RewardState.Approved;
    }

    /**
    * @dev callback called after poll finalization
    */
    function onPollFinish(bool agree) internal {
        pool.onRewardPollFinish(id, agree);
    }

}
