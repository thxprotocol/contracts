pragma solidity ^0.5.0;

import './reward/Reward.sol';
import './rule/Rules.sol';
import './THXToken.sol';

contract RewardPool is Rules {

    event Deposited(address indexed sender, uint256 amount, uint256 created);
    event Withdrawn(address indexed beneficiary, uint256 amount, uint256 id, uint256 created);

    event RewardPollFinished(uint256 id, bool approved);

    THXToken public token;
    string public name;
    address public creator;

    Reward[] public rewards;

    constructor(string memory _name, address _tokenAddress) public {
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

        emit Deposited(msg.sender, amount, now);
    }

    /**
    * @dev Counts the amount of rewards.
    */
    function countRewards() public view returns (uint256) {
        return rewards.length;
    }

    /**
    * @dev Creates the suggested reward.
    * @param slug Short readable description of reward.
    * @param amount Reward size suggested for the beneficiary.
    */
    function createReward(string memory slug, uint256 amount) public {
        Reward reward = new Reward(rewards.length, slug, msg.sender, amount, address(token), address(this));
        rewards.push(reward);
    }

    /**
    * @dev Vote for the suggested reward.
    * @param id Referenced Reward
    * @param agree Approve or reject reward.
    */
    function voteForReward(uint256 id, bool agree) public onlyManager {
        rewards[id].vote(agree);
    }

    /**
    * @dev Vote for the suggested reward.
    * @param id Reference to thte reward
    */
    function revokeVoteForReward(uint256 id) public onlyManager {
        rewards[id].revokeVote();
    }

    /**
    * @dev Called when poll is finished
    * @param agree Bool for checking the result of the poll.
    */
    function onRewardPollFinish(uint256 id, bool agree) internal {
        require(rewards[id].finalized());
        if(agree) {
            _withdraw(id);
        }
        emit RewardPollFinished(id, agree);
    }

    /**
    * @dev Withdraw accumulated balance for a beneficiary.
    */
    function _withdraw(uint256 id) internal onlyMember {
        uint256 tokenBalance = token.balanceOf(address(this));

        require(rewards[id].withdrawalAllowed());
        require(rewards[id].amount() > 0);
        require(tokenBalance >= rewards[id].amount());

        // Approve the token transaction.
        token.approve(address(this), rewards[id].amount());
        // Transfer the tokens from the pool to the beneficiary.
        token.transferFrom(address(this), rewards[id].beneficiary(), rewards[id].amount());

        emit Withdrawn(rewards[id].beneficiary(), rewards[id].amount(), id, now);

        delete rewards[id];
    }

}
