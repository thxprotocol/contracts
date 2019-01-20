pragma solidity ^0.5.0;

import './access/roles/ManagerRole.sol';
import "./math/SafeMath.sol";
import './THXToken.sol';

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

    struct Transaction {
      uint id;
      address sender;
      address receiver;
      uint256 amount;
    }

    mapping (address => uint256[]) private _deposits;
    mapping (address => uint256[]) public beneficiaries;

    mapping (address => Transaction[]) public transactions;

    Reward[] public rewards;

    THXToken public token;
    string public name;

    constructor(string memory _name, address _tokenAddress) public
    {
        name = _name;
        token = THXToken(_tokenAddress);
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
    */
    function deposit(uint256 amount) public {
        require(token.balanceOf(msg.sender) > 0);
        require(amount > 0);

        _deposits[msg.sender] = _deposits[msg.sender].add(amount);

        // Approve the token transaction.
        token.approveDeposit(msg.sender, address(this), amount);
        // Transfer the tokens from the sender to the pool
        token.transferDeposit(msg.sender, address(this), amount);

        emit Deposited(msg.sender, amount);

        _register(msg.sender, address(this), amount);
    }

    function _register(address sender, address receiver, uint256 amount) internal {
      Transaction memory transaction;

      transaction.id = transactions[sender].length;
      transaction.sender = sender;
      transaction.receiver = receiver;
      transaction.amount = amount;

      transactions[sender].push(transaction);
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

        _register(address(this), rewards[id].beneficiary, amount);
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
    function countRewards() public view returns (uint256 rewardCount) {
        return rewards.length;
    }

    /**
    * @dev Counts the amount of transactions.
    */
    function countMyRewards() public view returns (uint256 beneficiaryRewardCount) {
        return beneficiaries[msg.sender].length;
    }

    /**
    * @dev Counts the amount of transactions.
    */
    function countMyTransactions() public view returns (uint256 transactionCount) {
        return transactions[msg.sender].length;
    }

    /**
    * @dev Approves the suggested reward.
    * @param id The id of the reward.
    */
    function approve(uint256 id) public onlyManager {
        require(rewards[id].state == State.Pending || rewards[id].state == State.Rejected);
        require(msg.sender != rewards[id].beneficiary);

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
