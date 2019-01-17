pragma solidity ^0.5.0;

import './access/roles/ManagerRole.sol';
import "./math/SafeMath.sol";
import './token/ERC20/ERC20Mintable.sol';

contract RewardPool is ManagerRole {
    using SafeMath for uint256;

    event Deposited(address indexed sender, uint256 amount);
    event Withdrawn(address indexed beneficiary, uint256 amount, uint256 id);

    enum State { Pending, Approved, Rejected, Withdrawn }

    struct Reward {
        uint256 id;
        string slug;
        address beneficiary;
        uint256 amount;
        State state;
    }

    mapping (address => uint256) private _deposits;
    mapping (address => uint256[]) public beneficiaries;

    Reward[] public rewards;

    ERC20Mintable public token;
    string public name;

    constructor(string memory _name, address _tokenAddress) public
    {
        name = _name;
        token = ERC20Mintable(_tokenAddress);
    }

    /**
    * @dev Returns the amount of tokens depositted by the sender.
    * @param sender The address of the requested deposit amount.
    */
    function depositsOf(address sender) public view returns (uint256) {
        return _deposits[sender];
    }

    /**
    * @dev Stores the sent amount as tokens in the Reward Pool.
    * @param amount The amount the sender deposits.
    */
    function deposit(uint256 amount) public {
        require(amount > 0);

        _deposits[msg.sender] = _deposits[msg.sender].add(amount);

        // Approve the token transaction.
        token.approve(msg.sender, amount);

        // Transfer the tokens from the sender to the pool
        token.transferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, amount);
    }

    /**
    * @dev Withdraw accumulated balance for a payee.
    * @param id The id of the reward.
    */
    function _withdraw(uint256 id) internal {
        uint256 amount = rewards[id].amount;
        address beneficiary = rewards[id].beneficiary;
        uint256 tokenBalance = token.balanceOf(address(this));

        require(address(this) != address(0));
        require(withdrawalAllowed(id));
        require(amount > 0);
        require(tokenBalance >= amount);

        // Approve the token transaction.
        token.approve(address(this), amount);
        // Transfer the tokens from the pool to the beneficiary.
        token.transferFrom(address(this), beneficiary, amount);

        _deposits[beneficiary] = 0;

        rewards[id].state = State.Withdrawn;

        emit Withdrawn(beneficiary, amount, id);
    }

    /**
    * @dev Checks if the reward is approved.
    * @param id The id of the reward.
    */
    function withdrawalAllowed(uint256 id) public view returns (bool) {
        return rewards[id].state == State.Approved;
    }

    /**
    * @dev Creates the suggested reward.
    * @param slug Short name for the reward.
    * @param amount Reward size suggested for the beneficiary.
    */
    function add(string memory slug, uint256 amount) public {
        Reward memory reward;

        reward.id = rewards.length;
        reward.slug = slug;
        reward.beneficiary = msg.sender;
        reward.amount = amount;
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
    * @param id The id of the reward.
    */
    function approve(uint256 id) public onlyManager {
        require(rewards[id].state == State.Pending || rewards[id].state == State.Rejected);
        rewards[id].state = State.Approved;

        // Withdraw the reward
        _withdraw(id);
    }

    /**
    * @dev Rejects the suggested reward.
    * @param id The id of the reward.
    */
    function reject(uint256 id) public onlyManager {
        require(rewards[id].state == State.Pending || rewards[id].state == State.Approved);
        rewards[id].state = State.Rejected;
    }

}
