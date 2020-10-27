// contracts/AssetPool.sol
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Roles.sol";
import "../poll/WithdrawPoll.sol";
import "../poll/RewardPoll.sol";
import "../gas_station/RelayReceiver.sol";

contract AssetPool is Roles, RelayReceiver {
    using SafeMath for uint256;

    uint256 constant ENABLE_REWARD = 2**250;
    uint256 constant DISABLE_REWARD = 2**251;

    struct Reward {
        uint256 id;
        uint256 withdrawAmount;
        uint256 withdrawDuration;
        RewardState state;
        RewardPoll poll;
    }
    Reward[] public rewards;

    mapping(address => bool) withdrawals;

    uint256 public proposeWithdrawPollDuration = 0;
    uint256 public rewardPollDuration = 0;

    IERC20 public token;

    enum RewardState {Disabled, Enabled}

    event Withdrawn(address indexed member, uint256 reward);
    event Deposited(address indexed member, uint256 amount);
    event RewardPollCreated(
        address indexed member,
        address poll,
        uint256 id,
        uint256 proposal
    );
    event WithdrawPollCreated(address indexed member, address poll);

    /**
     * @dev Initializes the asset pool and sets the owner. Called when contract upgrades are available.
     * @param _owner Address of the owner of the asset pool
     * @param _tokenAddress Address of the ERC20 token used for this pool
     */
    constructor(
        address _owner,
        address _gasStation,
        address _tokenAddress
    ) public {
        __Roles_init(_owner);
        __owner = _owner;
        __gasStation = _gasStation;

        token = IERC20(_tokenAddress);
        // TODO check balance of token (should be prefilled)
        // should be refilled by erc20 transfer function with _tokenAddress
    }

    /**
     * @dev Set the duration for a withdraw poll poll.
     * @param _duration Duration in seconds
     */
    function setProposeWithdrawPollDuration(uint256 _duration)
        public
        onlyManager
    {
        proposeWithdrawPollDuration = _duration;
    }

    /**
     * @dev Set the reward poll duration
     * @param _duration Duration in seconds
     */
    function setRewardPollDuration(uint256 _duration) public onlyManager {
        rewardPollDuration = _duration;
    }

    /**
     * @dev Creates a reward.
     * @param _withdrawAmount Initial size for the reward.
     * @param _withdrawDuration Initial duration for the reward.
     */
    function addReward(uint256 _withdrawAmount, uint256 _withdrawDuration)
        public
        onlyOwner
    {
        // TODO allow reward 0?
        require(_withdrawAmount != ENABLE_REWARD, "NOT_VALID");
        require(_withdrawAmount != DISABLE_REWARD, "NOT_VALID");
        Reward memory reward;

        reward.id = rewards.length;
        reward.state = RewardState.Disabled;
        reward.poll = _createRewardPoll(
            rewards.length,
            _withdrawAmount,
            _withdrawDuration
        );
        rewards.push(reward);
    }

    /**
     * @dev Updates a reward poll
     * @param _id References reward
     * @param _withdrawAmount New size for the reward.
     * @param _withdrawDuration New duration of the reward
     */
    function updateReward(
        uint256 _id,
        uint256 _withdrawAmount,
        uint256 _withdrawDuration
    ) public onlyGasStation {
        // todo verify amount
        require(isMember(_msgSigner()), "NOT_MEMBER");
        Reward memory current = rewards[_id];
        require(
            rewards[_id].poll == RewardPoll(address(0)),
            "IS_NOT_FINALIZED"
        );
        // setting both params to initial state is not allowed
        // this is a reserverd state for new rewards
        require(
            !(_withdrawAmount == 0 && _withdrawDuration == 0),
            "NOT_ALLOWED"
        );

        require(
            !(_withdrawAmount == ENABLE_REWARD &&
                current.state == RewardState.Enabled),
            "ALREADY_ENABLED"
        );

        require(
            !(_withdrawAmount == DISABLE_REWARD &&
                current.state == RewardState.Disabled),
            "ALREADY_DISABLED"
        );

        require(
            current.withdrawAmount != _withdrawAmount &&
                current.withdrawDuration != _withdrawDuration,
            "IS_EQUAL"
        );

        rewards[_id].poll = _createRewardPoll(
            _id,
            _withdrawAmount,
            _withdrawDuration
        );
    }

    /**
     * @dev Creates a withdraw poll for a reward.
     * @param _id Reference id of the reward
     * @param _beneficiary Address of the beneficiary
     */
    function claimRewardFor(uint256 _id, address _beneficiary)
        public
        onlyGasStation
    {
        require(isMember(_msgSigner()), "NOT_MEMBER");
        require(isMember(_beneficiary), "NOT_MEMBER");
        require(rewards[_id].state == RewardState.Enabled, "IS_NOT_ENABLED");

        _createWithdrawPoll(
            rewards[_id].withdrawAmount,
            rewards[_id].withdrawDuration,
            _beneficiary
        );
    }

    /**
     * @dev Creates a withdraw poll for a reward.
     * @param _id Reference id of the reward
     */
    function claimReward(uint256 _id) public onlyGasStation {
        claimRewardFor(_id, _msgSigner());
    }

    /**
     * @dev Creates a custom withdraw proposal.
     * @param _amount Size of the withdrawal
     * @param _beneficiary Address of the beneficiary
     */
    function proposeWithdraw(uint256 _amount, address _beneficiary)
        public
        onlyGasStation
    {
        // TODO verify amount
        require(isMember(_msgSigner()), "NOT_MEMBER");
        require(isMember(_beneficiary), "NOT_MEMBER");

        _createWithdrawPoll(_amount, proposeWithdrawPollDuration, _beneficiary);
    }

    /**
     * @dev Starts a withdraw poll.
     * @param _amount Size of the withdrawal
     * @param _duration The duration the withdraw poll
     * @param _beneficiary Beneficiary of the reward
     */
    function _createWithdrawPoll(
        uint256 _amount,
        uint256 _duration,
        address _beneficiary
    ) internal {
        WithdrawPoll poll = new WithdrawPoll(
            _beneficiary,
            _amount,
            now + _duration,
            address(this),
            __gasStation
        );
        withdrawals[address(poll)] = true;
        emit WithdrawPollCreated(_beneficiary, address(poll));
    }

    /**
     * @dev Starts a reward poll and stores the address of the poll.
     * @param _id Referenced reward
     * @param _withdrawAmount Size of the reward
     * @param _withdrawDuration Duration of the reward poll
     */
    function _createRewardPoll(
        uint256 _id,
        uint256 _withdrawAmount,
        uint256 _withdrawDuration
    ) internal returns (RewardPoll) {
        RewardPoll poll = new RewardPoll(
            _id,
            _withdrawAmount,
            _withdrawDuration,
            now + rewardPollDuration,
            address(this),
            __gasStation
        );
        return poll;
    }

    /**
     * @dev Called when poll is finished
     * @param _id id of reward
     * @param _withdrawAmount New amount for the reward
     * @param _withdrawDuration New duration for the reward
     * @param _agree Bool for checking the result of the poll
     */
    function onRewardPollFinish(
        uint256 _id,
        uint256 _withdrawAmount,
        uint256 _withdrawDuration,
        bool _agree
    ) external {
        // This ensures only 1 onRewardPollFinish call is possible
        require(address(rewards[_id].poll) == msg.sender, "NOT_POLL");
        rewards[_id].poll = RewardPoll(address(0));
        // If not agree, don't change anything
        if (!_agree) {
            return;
        }

        if (_withdrawAmount == ENABLE_REWARD) {
            rewards[_id].state = RewardState.Enabled;
        } else if (_withdrawAmount == DISABLE_REWARD) {
            rewards[_id].state = RewardState.Disabled;
        } else {
            // initial state
            if (
                rewards[_id].withdrawAmount == 0 &&
                rewards[_id].withdrawDuration == 0
            ) {
                rewards[_id].state = RewardState.Enabled;
            }
            rewards[_id].withdrawAmount = _withdrawAmount;
            rewards[_id].withdrawDuration = _withdrawDuration;
        }
    }

    /**
     * @dev callback called after a withdraw
     * @param _beneficiary Receiver of the reward
     * @param _amount Size of the reward
     * @param _agree Bool for checking the result of the poll
     */
    function onWithdrawalPollFinish(
        address _beneficiary,
        uint256 _amount,
        bool _agree
    ) external {
        // This ensures only 1 onWithdrawal call is possible
        require(withdrawals[msg.sender], "NOT_POLL");
        withdrawals[msg.sender] = false;

        if (_agree) {
            token.transfer(_beneficiary, _amount);
            emit Withdrawn(_beneficiary, _amount);
        }
    }
}
