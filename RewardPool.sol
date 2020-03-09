pragma solidity ^0.5.0;

import './reward/Reward.sol';
import './rule/Rules.sol';
import './THXToken.sol';

contract RewardPool is Rules {

    event Deposited(address indexed sender, uint256 amount);
    event Withdrawn(address indexed beneficiary, uint256 reward);

    event RewardPollCreated(uint256 reward);
    event RewardPollFinished(uint256 reward, bool approved);

    THXToken public token;
    string public name;
    address public creator;

    Reward[] public rewards;

    struct Deposit {
        uint256 amount;
        address sender;
        uint256 created;
    }

    struct Withdrawel {
        uint256 amount;
        address receiver;
        uint256 created;
    }

    mapping (address => Deposit[]) public deposits;
    mapping (address => Withdrawel[]) public withdrawels;
    mapping (address => Reward[]) public rewardsOf;

    constructor(
        string memory _name,
        address _tokenAddress
    ) public
        Rules(_tokenAddress)
    {
        name = _name;
        token = THXToken(_tokenAddress);
        creator = msg.sender;
    }

    /**
    * @dev Updates the pool name set initially through the constructor.
    * @param value The new pool name.
    */
    function updatePoolName(string memory value) public onlyManager {
        name = value;
    }

    /**
    * @dev Stores the sent amount as tokens in the Reward Pool.
    * @param amount The amount the sender deposited.
    */
    function deposit(uint256 amount) public {
        require(token.balanceOf(msg.sender) > 0);
        require(amount > 0);

        // Approve the token transaction.
        token.approveDeposit(msg.sender, address(this), amount);

        // Transfer the tokens from the sender to the pool
        token.transferDeposit(msg.sender, address(this), amount);

        Deposit memory d;
        d.amount = amount;
        d.sender = msg.sender;
        d.created = now;

        deposits[msg.sender].push(d);

        emit Deposited(d.sender, d.amount);
    }

    /**
    * @dev Counts the amount of Rewards.
    */
    function countRewards() public view returns (uint256) {
        return rewards.length;
    }

    /**
    * @dev Counts the amount of Deposits for an address.
    */
    function countDeposits(address sender) public view returns (uint256) {
        return deposits[sender].length;
    }

    /**
    * @dev Counts the amount of Withdrawels for an address.
    */
    function countWithdrawels(address receiver) public view returns (uint256) {
        return withdrawels[receiver].length;
    }

    /**
    * @dev Creates the suggested reward.
    * @param rule Reference id of the rule
    */
    function createReward(uint256 rule) public {
        Reward reward = new Reward(rewards.length, rule, msg.sender, rules[rule].amount, address(token), address(this));

        rewards.push(reward);
        rewardsOf[msg.sender].push(reward);

        emit RewardPollCreated(rewards.length);
    }

    /**
    * @dev Vote for the suggested reward.
    * @param id Referenced Reward
    * @param agree Approve or reject reward.
    */
    function voteForReward(uint256 id, bool agree) public onlyManager {
        rewards[id].vote(msg.sender, agree);
    }

    /**
    * @dev Vote for the suggested reward.
    * @param id Reference to thte reward
    */
    function revokeVoteForReward(uint256 id) public onlyManager {
        rewards[id].revokeVote(msg.sender);
    }

    /**
    * @dev Called when poll is finished
    * @param id Reference to the reward rule
    * @param agree Bool for checking the result of the poll.
    */
    function onRewardPollFinish(uint256 id, bool agree) external {
        emit RewardPollFinished(id, agree);
    }

    /**
    * @dev callback called after reward is withdrawn
    */
    function onWithdrawel(address receiver, uint256 amount, uint256 created) external {
        token.transfer(receiver, amount);

        Withdrawel memory w;
        w.amount = amount;
        w.receiver = receiver;
        w.created = created;

        withdrawels[receiver].push(w);

        emit Withdrawn(w.receiver, w.amount);
    }

}
