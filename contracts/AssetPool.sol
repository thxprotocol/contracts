// contracts/AssetPool.sol
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol';

import './access/Roles.sol';
import './poll/WithdrawPoll.sol';
import './poll/RewardPoll.sol';

contract AssetPool is Initializable, OwnableUpgradeSafe, Roles {
    using SafeMath for uint256;

    struct Reward {
        uint256 id;
        uint256 amount;
        RewardState state;
        RewardPoll poll;
        uint256 updated;
    }

    Reward[] public rewards;
    WithdrawPoll[] public withdraws;

    uint256 public withdrawPollDuration = 0;
    uint256 public rewardPollDuration = 0;

    IERC20 public token;

    /*==== IMPORTANT: Do not alter (only extend) the storage layout above this line! ====*/

    enum RewardState { Disabled, Enabled }

    event Withdrawn(address indexed member, uint256 reward);
    event Deposited(address indexed member, uint256 amount);
    event RewardPollCreated(address indexed member, address poll, uint256 id, uint256 proposal);
    event WithdrawPollCreated(address indexed member, address poll);

    /**
     * @dev Initializes the asset pool and sets the owner. Called when contract upgrades are available.
     * @param _owner Address of the owner of the asset pool
     * @param _tokenAddress Address of the ERC20 token used for this pool
     */
    function initialize(address _owner, address _tokenAddress) public initializer {
        __Ownable_init();
        __Roles_init(_owner);

        transferOwnership(_owner);

        token = IERC20(_tokenAddress);
    }

    /**
     * @dev Store a deposit in the contract. The tx should be approved prior to calling this method.
     * @param _amount Size of the deposit
     */
    function deposit(uint256 _amount) public onlyMember {
        require(token.balanceOf(msg.sender) >= _amount, 'INSUFFICIENT_BALANCE');

        token.transferFrom(msg.sender, address(this), _amount);

        emit Deposited(msg.sender, _amount);
    }

    /**
     * @dev Set the duration for a withdraw poll poll.
     * @param _duration Duration in seconds
     */
    function setWithdrawPollDuration(uint256 _duration) public onlyOwner {
        withdrawPollDuration = _duration;
    }

    /**
     * @dev Set the reward poll duration
     * @param _duration Duration in seconds
     */
    function setRewardPollDuration(uint256 _duration) public onlyOwner {
        rewardPollDuration = _duration;
    }

    /**
     * @dev Creates a reward.
     * @param _amount Initial size for the reward.
     */
    function addReward(uint256 _amount) public onlyOwner {
        Reward memory reward;

        reward.id = rewards.length;
        reward.amount = 0;
        reward.state = RewardState.Disabled;
        reward.poll = _createRewardPoll(rewards.length, _amount);
        reward.updated = now;

        rewards.push(reward);
    }

    /**
     * @dev Updates a reward poll
     * @param _id References reward
     * @param _amount New size for the reward.
     */
    function updateReward(uint256 _id, uint256 _amount) public onlyMember {
        require(rewards[_id].poll.finalized(), 'IS_NOT_FINALIZED');
        require(_amount != rewards[_id].amount, 'IS_EQUAL');

        rewards[_id].poll = _createRewardPoll(_id, _amount);
    }

    /**
     * @dev Creates a withdraw poll for a reward.
     * @param _id Reference id of the reward
     */
    function claimWithdraw(uint256 _id) public onlyMember {
        require(rewards[_id].state == RewardState.Enabled, 'IS_NOT_ENABLED');

        WithdrawPoll withdraw = _createWithdrawPoll(rewards[_id].amount, msg.sender);

        withdraws.push(withdraw);
    }

    /**
     * @dev Creates a custom withdraw proposal.
     * @param _amount Size of the withdrawal
     * @param _beneficiary Address of the beneficiary
     */
    function proposeWithdraw(uint256 _amount, address _beneficiary) public {
        require(isMember(_beneficiary), 'IS_NOT_MEMBER');

        WithdrawPoll withdraw = _createWithdrawPoll(_amount, _beneficiary);
        withdraws.push(withdraw);
    }

    /**
     * @dev Starts a withdraw poll.
     * @param _amount Size of the withdrawal
     * @param _beneficiary Address of the receiver of the withdrawal
     */
    function _createWithdrawPoll(uint256 _amount, address _beneficiary) internal returns (WithdrawPoll) {
        WithdrawPoll poll = new WithdrawPoll(
            _beneficiary,
            _amount,
            withdrawPollDuration,
            address(this),
            owner(),
            address(token)
        );

        emit WithdrawPollCreated(_beneficiary, address(poll));

        return poll;
    }

    /**
     * @dev Starts a reward poll and stores the address of the poll.
     * @param _id Referenced reward
     * @param _amount Size of the reward
     */
    function _createRewardPoll(uint256 _id, uint256 _amount) internal returns (RewardPoll) {
        RewardPoll poll = new RewardPoll(_id, _amount, rewardPollDuration, address(this), owner());

        emit RewardPollCreated(msg.sender, address(poll), _id, _amount);

        return poll;
    }

    /**
     * @dev Called when poll is finished
     * @param _id id of reward
     * @param _amount New amount for the reward
     * @param _agree Bool for checking the result of the poll
     */
    function onRewardPollFinish(
        uint256 _id,
        uint256 _amount,
        bool _agree
    ) external {
        require(address(rewards[_id].poll) == msg.sender);

        if (_agree) {
            rewards[_id].amount = _amount;

            if (_amount > 0) {
                rewards[_id].state = RewardState.Enabled;
            } else {
                rewards[_id].state = RewardState.Disabled;
            }
        }
    }

    /**
     * @dev callback called after a withdraw
     * @param _withdraw Address of the withdrawal
     * @param _beneficiary Receiver of the reward
     * @param _amount Size of the reward
     */
    function onWithdrawal(
        address _withdraw,
        address _beneficiary,
        uint256 _amount
    ) external {
        require(_withdraw == msg.sender);

        token.transfer(_beneficiary, _amount);

        emit Withdrawn(_beneficiary, _amount);
    }
}
