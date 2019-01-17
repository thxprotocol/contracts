pragma solidity ^0.5.0;

import './payment/escrow/ConditionalEscrow.sol';
import './access/roles/ManagerRole.sol';
import './token/ERC20/ERC20Mintable.sol';

contract RewardPool is ConditionalEscrow, ManagerRole {
    enum State { Pending, Approved, Rejected, Withdrawn }

    event RewardWithdrawn(uint256 indexed _id, uint256 payment);

    struct Reward {
        uint256 id;
        string slug;
        address beneficiary;
        uint256 amount;
        State state;
    }

    mapping (address => uint256[]) public beneficiaries;
    Reward[] public rewards;

    string public name;
    ERC20Mintable public token;

    constructor(string memory _name, address _tokenAddress) public
    {
        name = _name;
        token = ERC20Mintable(_tokenAddress);
    }

    /**
    * @dev Checks if the reward is approved.
    * @param _id The id of the reward.
    */
    function withdrawalAllowed(uint256 _id) public view returns (bool) {
        return rewards[_id].state == State.Approved;
    }

    /**
    * @dev Creates the suggested reward.
    * @param _slug Short name for the reward.
    * @param _amount Reward size suggested for the beneficiary.
    */
    function add(string memory _slug, uint256 _amount) public {
        Reward memory reward;

        reward.id = rewards.length;
        reward.slug = _slug;
        reward.beneficiary = msg.sender;
        reward.amount = _amount;
        reward.state = State.Pending;

        beneficiaries[msg.sender].push(reward.id);

        rewards.push(reward);
    }

    /**
    * @dev Counts the amount of rewards.
    */
    function count() public view returns (uint256 rewardCount) {
        return rewards.length;
    }

    /**
    * @dev Approves the suggested reward.
    * @param _id The id of the reward.
    */
    function approve(uint256 _id) public onlyManager {
        require(rewards[_id].state == State.Pending || rewards[_id].state == State.Rejected);
        rewards[_id].state = State.Approved;

        withdrawReward(_id);
    }

    /**
    * @dev Rejects the suggested reward.
    * @param _id The id of the reward.
    */
    function reject(uint256 _id) public onlyManager {
        require(rewards[_id].state == State.Pending || rewards[_id].state == State.Approved);
        rewards[_id].state = State.Rejected;
    }

    /**
    * @dev Withdraw accumulated balance for a payee.
    * @param _id The id of the reward.
    */
    function withdrawReward(uint256 _id) public {
        // Verify that reward is approved.
        require(withdrawalAllowed(_id));

        // Verify that the pool address is set
        require(address(this) != address(0));

        // Verify that the pool holds at least the reward size
        uint256 payment = rewards[_id].amount;
        require(payment > 0);

        uint256 tokenBalance = token.balanceOf(address(this));
        require(tokenBalance >= payment);

        // Approve the token transaction.
        token.approve(address(this), payment);

        // Transfer the tokens from the pool to the beneficiary.
        token.transferFrom(address(this), rewards[_id].beneficiary, payment);

        rewards[_id].state = State.Withdrawn;

        emit RewardWithdrawn(_id, payment);
    }
}
