// contracts/RewardPool.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol';

import './access/Roles.sol';
import './poll/BasePoll.sol';
import './poll/RewardPoll.sol';

contract RewardPool2 is Initializable, OwnableUpgradeSafe, Roles {
    using SafeMath for uint256;

    struct RewardRule {
        uint256 id;
        uint256 amount;
        RewardRuleState state;
        BasePoll poll;
        uint256 lastUpdated;
        uint256 created;
    }

    struct Withdrawal {
        address reward;
        address beneficiary;
    }

    RewardRule[] public rewardRules;
    RewardPoll[] public rewards;

    uint256 public rewardRulePollDuration;
    uint256 public rewardPollDuration;

    mapping(address => RewardPoll[]) public rewardsOf;
    mapping(address => Withdrawal[]) public withdrawals;

    IERC20 public token;

    /*==== IMPORTANT: Do not alter (only extend) the storage layout above this line! ====*/

    enum RewardRuleState { Active, Disabled }

    event RewardPollFinished(address reward, bool agree);
    event Withdrawn(address indexed beneficiary, uint256 reward);

    /**
     * @dev Initializes the reward pool and sets the owner. Called when contract upgrades are available.
     * @param _owner Address of the owner of the reward pool
     * @param _tokenAddress Address of the ERC20 token used for this pool
     */
    function initialize(address _owner, address _tokenAddress) public initializer {
        __Ownable_init();
        __Roles_init(_owner);

        transferOwnership(_owner);

        token = IERC20(_tokenAddress);

        setRewardPollDuration(3 minutes);
        setRewardRulePollDuration(3 minutes);
    }

    function setRewardPollDuration(uint256 time) public {
        require(msg.sender == owner(), 'caller is not owner');

        rewardPollDuration = time * 2;
    }

    function setRewardRulePollDuration(uint256 time) public {
        require(msg.sender == owner(), 'caller is not owner');
        rewardRulePollDuration = time * 2;
    }

    // /**
    //  * @dev Creates a reward claim for a rule.
    //  * @param _id Reference id of the rule
    //  */
    // function claimReward(uint256 _id) public {
    //     require(rewardRules[_id].state == RewardRuleState.Active, 'rule is not active');

    //     _createRewardProposal(rewardRules[_id].amount, msg.sender);
    // }

    // /**
    //  * @dev Creates a custom reward proposal.
    //  * @param _amount Size of the reward
    //  * @param _beneficiary Address of the beneficiary
    //  */
    // function proposeReward(uint256 _amount, address _beneficiary) public {
    //     _createRewardProposal(_amount, _beneficiary);
    // }

    /**
     * @dev Starts a reward poll and stores the reward.
     * @param _reward Reward Poll
     */
    function proposeReward(RewardPoll _reward) public {
        rewards.push(_reward);
    }

    /**
     * @dev Called when poll is finished
     * @param _reward Address of reward
     * @param _agree Bool for checking the result of the poll.
     */
    function onRewardPollFinish(address _reward, bool _agree) external {
        emit RewardPollFinished(_reward, _agree);
    }

    /**
     * @dev callback called after reward is withdrawn
     * @param _reward Address of the reward
     * @param _beneficiary Receiver of the reward
     * @param _amount Size of the reward
     */
    function onWithdrawal(
        address _reward,
        address _beneficiary,
        uint256 _amount
    ) external {
        token.transfer(_beneficiary, _amount);

        Withdrawal memory withdrawal;

        withdrawal.beneficiary = _beneficiary;
        withdrawal.reward = _reward;

        withdrawals[_beneficiary].push(withdrawal);

        emit Withdrawn(_beneficiary, _amount);
    }
}
