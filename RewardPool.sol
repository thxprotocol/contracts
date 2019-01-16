pragma solidity ^0.5.0;

import './payment/escrow/ConditionalEscrow.sol';
import './access/roles/ManagerRole.sol';
import './token/ERC20/ERC20Mintable.sol';

contract RewardPool is ConditionalEscrow, ManagerRole {
    enum State { Pending, Approved, Rejected, Withdrawn }

    event RewardWithdrawn(address indexed beneficiary, uint256 amount);

    struct Reward {
        string slug;
        address beneficiary;
        uint256 amount;
        State state;
    }

    mapping (address => Reward) public rewards;
    address[] public beneficiaries;

    string public name;
    ERC20Mintable public token;

    constructor(string memory _name, address _tokenAddress) public
    {
        name = _name;
        token = ERC20Mintable(_tokenAddress);
    }

    /**
    * @dev Checks if the reward is approved.
    * @param payee The destination address of the reward.
    */
    function withdrawalAllowed(address payee) public view returns (bool) {
        return rewards[payee].state == State.Approved;
    }

    /**
    * @dev Creates the suggested reward.
    * @param _slug Short name for the reward.
    * @param _amount Reward size suggested for the beneficiary.
    */
    function add(string memory _slug, uint256 _amount) public {
        Reward memory reward;

        reward.slug = _slug;
        reward.beneficiary = msg.sender;
        reward.amount = _amount;
        reward.state = State.Pending;

        rewards[msg.sender] = reward;

        beneficiaries.push(msg.sender);
    }

    function count() public view returns (uint256 rewardCount) {
        return beneficiaries.length;
    }

    /**
    * @dev Approves the suggested reward.
    * @param _beneficiary The destination address of the reward.
    */
    function approve(address _beneficiary) public onlyManager {
        rewards[_beneficiary].state = State.Approved;

        withdrawReward(_beneficiary);
    }

    /**
    * @dev Rejects the suggested reward.
    * @param _beneficiary The destination address of the reward.
    */
    function reject(address _beneficiary) public onlyManager {
        rewards[_beneficiary].state = State.Rejected;
    }

    /**
    * @dev Withdraw accumulated balance for a payee.
    * @param _beneficiary The destination address of the reward.
    */
    function withdrawReward(address _beneficiary) public {
        address pool = address(this);

        // Verify that reward is approved.
        require(withdrawalAllowed(_beneficiary));

        // Verify that the pool address is set
        require(pool != address(0));

        // Verify that the pool holds at least the reward size
        uint256 payment = rewards[_beneficiary].amount;
        require(payment > 0);

        uint256 tokenBalance = token.balanceOf(pool);
        require(tokenBalance >= payment);

        // Approve the token transaction.
        token.approve(pool, payment);

        // Transfer the tokens from the pool to the beneficiary.
        token.transferFrom(pool, _beneficiary, payment);

        rewards[_beneficiary].state = State.Withdrawn;

        emit RewardWithdrawn(_beneficiary, payment);
    }
}
