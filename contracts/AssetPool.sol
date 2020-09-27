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

    struct Withdrawal {
        address withdraw;
        address beneficiary;
        uint256 timestamp;
    }

    struct Deposit {
        address member;
        uint256 amount;
        uint256 timestamp;
    }

    Reward[] public rewards;
    WithdrawPoll[] public withdraws;
    Deposit[] public deposits;

    uint256 public withdrawPollDuration = 0;
    uint256 public rewardPollDuration = 0;

    mapping(address => Deposit[]) public depositsOf;
    mapping(address => Withdrawal[]) public withdrawalsOf;
    mapping(address => WithdrawPoll[]) public withdrawalPollsOf;

    IERC20 public token;

    /*==== IMPORTANT: Do not alter (only extend) the storage layout above this line! ====*/

    enum RewardState { Disabled, Enabled }

    event Withdrawn(address indexed beneficiary, uint256 reward);
    event Deposited(address indexed sender, uint256 amount);
    event RewardPollCreated(uint256 id, uint256 proposal, address account);
    event RewardPollFinished(uint256 id, uint256 proposal, bool agree);
    event RewardUpdated(uint256 id, RewardState state, uint256 amount);
    event WithdrawPollCreated(address reward);
    event WithdrawPollFinished(address reward, bool agree);

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
     * @dev Get the total amount of deposits in this pool
     */
    function getDepositCount() public view returns (uint256) {
        return deposits.length;
    }

    /**
     * @dev Get the total amount of withdraws in this pool
     */
    function getWithdrawCount() public view returns (uint256) {
        return withdraws.length;
    }

    /**
     * @dev Get the total amount of rewards in this pool
     */
    function getRewardCount() public view returns (uint256) {
        return rewards.length;
    }

    /**
     * @dev Get the amount of deposits for a given address
     * @param _member Address of the sender of deposits
     */
    function getDepositCountOf(address _member) public view returns (uint256) {
        return depositsOf[_member].length;
    }

    /**
     * @dev Get the amount of withdraws for a given address
     * @param _member Address of the sender of withdraws
     */
    function getWithdrawalCount(address _member) public view returns (uint256) {
        return withdrawalsOf[_member].length;
    }

    /**
     * @dev Get the amount of withdrawalPolls for a given address
     * @param _member Address of the sender of deposits
     */
    function getWithdrawPollsCountOf(address _member) public view returns (uint256) {
        return withdrawalPollsOf[_member].length;
    }

    /**
     * @dev Store a deposit in the contract. The tx should be approved prior to calling this method.
     * @param _amount Size of the deposit
     */
    function deposit(uint256 _amount) public onlyMember {
        require(token.balanceOf(_msgSender()) >= _amount, 'INSUFFICIENT_BALANCE');

        token.transferFrom(_msgSender(), address(this), _amount);

        Deposit memory d;

        d.amount = _amount;
        d.member = _msgSender();
        d.timestamp = now;

        deposits.push(d);
        depositsOf[_msgSender()].push(d);

        emit Deposited(_msgSender(), _amount);
    }

    /**
     * @dev Set the duration for a withdraw poll poll.
     * @param _duration Duration in seconds
     */
    function setWithdrawPollDuration(uint256 _duration) public {
        require(_msgSender() == owner(), 'IS_NOT_OWNER');

        withdrawPollDuration = _duration;
    }

    /**
     * @dev Set the reward poll duration
     * @param _duration Duration in seconds
     */
    function setRewardPollDuration(uint256 _duration) public {
        require(_msgSender() == owner(), 'IS_NOT_OWNER');

        rewardPollDuration = _duration;
    }

    /**
     * @dev Creates a reward.
     * @param _amount Initial size for the reward.
     */
    function addReward(uint256 _amount) public {
        require(_msgSender() == owner(), 'IS_NOT_OWNER');

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
    function updateReward(uint256 _id, uint256 _amount) public {
        require(rewards[_id].poll.finalized(), 'IS_NOT_FINALIZED');
        require(isMember(_msgSender()), 'IS_NOT_MEMBER');
        require(_amount != rewards[_id].amount, 'IS_EQUAL');

        rewards[_id].poll = _createRewardPoll(_id, _amount);
    }

    /**
     * @dev Creates a withdraw poll for a reward.
     * @param _id Reference id of the reward
     */
    function claimWithdraw(uint256 _id) public onlyMember {
        require(rewards[_id].state == RewardState.Enabled, 'IS_NOT_ENABLED');

        WithdrawPoll withdraw = _createWithdrawPoll(rewards[_id].amount, _msgSender());

        withdraws.push(withdraw);
        withdrawalPollsOf[_msgSender()].push(withdraw);
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
        withdrawalPollsOf[_beneficiary].push(withdraw);
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
            address(token)
        );

        emit WithdrawPollCreated(address(poll));

        return poll;
    }

    /**
     * @dev Starts a reward poll and stores the address of the poll.
     * @param _id Referenced reward
     * @param _amount Size of the reward
     */
    function _createRewardPoll(uint256 _id, uint256 _amount) internal returns (RewardPoll) {
        RewardPoll poll = new RewardPoll(_id, _amount, rewardPollDuration, address(this));

        emit RewardPollCreated(_id, _amount, _msgSender());

        return poll;
    }

    /**
     * @dev Called when poll is finished
     * @param _withdraw Address of withdrawPoll
     * @param _agree Bool for checking the result of the poll
     */
    function onWithdrawPollFinish(address _withdraw, bool _agree) external {
        require(_withdraw == _msgSender());

        emit WithdrawPollFinished(_withdraw, _agree);
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
        require(address(rewards[_id].poll) == _msgSender());

        if (_agree) {
            rewards[_id].amount = _amount;

            if (_amount > 0) {
                rewards[_id].state = RewardState.Enabled;
            } else {
                rewards[_id].state = RewardState.Disabled;
            }
        }

        emit RewardPollFinished(_id, _amount, _agree);
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
        require(_withdraw == _msgSender());

        token.transfer(_beneficiary, _amount);

        Withdrawal memory w;

        w.beneficiary = _beneficiary;
        w.withdraw = _withdraw;
        w.timestamp = now;

        withdrawalsOf[_beneficiary].push(w);

        emit Withdrawn(_beneficiary, _amount);
    }
}
