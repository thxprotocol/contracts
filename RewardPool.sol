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
      uint256 id;
      address sender;
      address receiver;
      uint256 amount;
    }

    mapping (address => uint256[]) public deposits;
    mapping (address => uint256[]) public withdrawels;

    Transaction[] public transactions;
    Reward[] public rewards;

    THXToken public token;
    string public name;

    constructor(string memory _name, address _tokenAddress) public
    {
        name = _name;
        token = THXToken(_tokenAddress);
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

        emit Deposited(msg.sender, amount);

        uint256 tid = _registerTransaction(msg.sender, address(this), amount);
        deposits[msg.sender].push(tid);
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

        rewards.push(reward);
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

    /**
    * @dev Counts the amount of rewards.
    */
    function countRewards() public view returns (uint256 rewardCount) {
        return rewards.length;
    }

    /**
    * @dev Counts the amount of rewards.
    */
    function countTransactions() public view returns (uint256 transactionCount) {
        return transactions.length;
    }

    /**
    * @dev Counts the amount of transactions.
    */
    function countSenderDeposits() public view returns (uint256 senderDepositCount) {
        return deposits[msg.sender].length;
    }

    /**
    * @dev Counts the amount of transactions.
    */
    function countSenderWithdrawels() public view returns (uint256 senderWithdrawelCount) {
        return withdrawels[msg.sender].length;
    }

    /**
    * @dev Registers a transaction.
    * @param sender The address of the sender.
    * @param receiver The address of the receiver.
    * @param amount The amount the sender sent to the receiver.
    */
    function _registerTransaction(address sender, address receiver, uint256 amount) internal returns (uint256) {
        Transaction memory transaction;

        transaction.id = transactions.length;
        transaction.sender = sender;
        transaction.receiver = receiver;
        transaction.amount = amount;

        transactions.push(transaction);

        return transaction.id;
    }

    /**
    * @dev Withdraw accumulated balance for a beneficiary.
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

        rewards[id].state = State.Withdrawn;

        emit Withdrawn(beneficiary, amount, id);

        uint256 tid = _registerTransaction(address(this), beneficiary, amount);
        withdrawels[beneficiary].push(tid);
    }
}
