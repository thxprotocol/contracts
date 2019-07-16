pragma solidity ^0.5.0;

import './access/roles/ManagerRole.sol';
import "./math/SafeMath.sol";
import './THXToken.sol';

contract RewardPool is ManagerRole {
    using SafeMath for uint256;

    struct Reward {
        uint256 id;
        string key;
        string slug;
        address beneficiary;
        uint256 amount;
        RewardState state;
        uint256 created;
    }

    struct Rule {
        uint256 id;
        string key;
        string slug;
        uint256 amount;
        RuleState state;
        address creator;
        uint256 created;
    }

    struct Transaction {
      uint256 id;
      address sender;
      address receiver;
      uint256 amount;
      uint256 created;
    }

    event Deposited(address indexed sender, uint256 amount, uint256 created);
    event Withdrawn(address indexed beneficiary, uint256 amount, uint256 id, uint256 created);

    event RewardStateChanged(uint256 id, string key, string slug, address beneficiary, uint256 amount, RewardState state, uint256 created);
    event RuleStateChanged(uint256 id, string key, string slug, uint256 amount, RuleState state, address creator, uint256 created);

    enum RewardState { Pending, Approved, Rejected, Withdrawn }
    enum RuleState { Pending, Active, Disabled }

    mapping (address => uint256[]) public deposits;
    mapping (address => uint256[]) public withdrawels;
    mapping (address => uint256[]) public beneficiaries;

    Transaction[] public transactions;
    Reward[] public rewards;
    Rule[] public rules;

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

        emit Deposited(msg.sender, amount, now);

        uint256 tid = _registerTransaction(msg.sender, address(this), amount, now);
        deposits[msg.sender].push(tid);
    }

    /**
    * @dev Checks if the reward is approved.
    * @param id The id of the reward.
    */
    function withdrawalAllowed(uint256 id) public view returns (bool) {
        return rewards[id].state == RewardState.Approved;
    }

    /**
    * @dev Creates the initial reward rule.
    * @param key Database reference for rule metadata.
    * @param slug Short readable description of rule.
    * @param amount Reward size suggested for the beneficiary.
    */
    function addRule(string memory key, string memory slug, uint256 amount) public {
        Rule memory rule;

        rule.id = rules.length;
        rule.key = key;
        rule.slug = slug;
        rule.amount = amount;
        rule.state = RuleState.Pending;
        rule.creator = msg.sender;
        rule.created = now;

        emit RuleStateChanged(rule.id, rule.key, rule.slug, rule.amount, rule.state, rule.creator, rule.created);

        rules.push(rule);
    }

    /**
    * @dev Updates the pool name set initially through the constructor.
    * @param value The new pool name.
    */
    function updatePoolName(string memory value) public onlyManager {
        name = value;
    }

    /**
    * @dev Approves the suggested reward rule and sets its state to Active.
    * @param id The id of the reward.
    */
    function approveRule(uint256 id) public onlyManager {
        require(rules[id].state == RuleState.Pending || rules[id].state == RuleState.Disabled);
        rules[id].state = RuleState.Active;

        emit RuleStateChanged(rules[id].id, rules[id].key, rules[id].slug, rules[id].amount, rules[id].state, rules[id].creator, rules[id].created);
    }

    /**
    * @dev Rejects the suggested reward and sets the state to Disabled.
    * @param id The id of the reward.
    */
    function rejectRule(uint256 id) public onlyManager {
        require(rules[id].state == RuleState.Pending || rules[id].state == RuleState.Active);

        rules[id].state = RuleState.Disabled;
    }

    /**
    * @dev Counts the amount of rules.
    */
    function countRules() public view returns (uint256) {
        return rules.length;
    }

    /**
    * @dev Creates the suggested reward.
    * @param key Database reference for reward metadata.
    * @param slug Short readable description of reward.
    * @param amount Reward size suggested for the beneficiary.
    */
    function addReward(string memory key, string memory slug, uint256 amount) public {
        Reward memory reward;

        reward.id = rewards.length;
        reward.key = key;
        reward.slug = slug;
        reward.beneficiary = msg.sender;
        reward.amount = amount;
        reward.state = RewardState.Pending;
        reward.created = now;

        emit RewardStateChanged(reward.id, reward.key, reward.slug, reward.beneficiary, reward.amount, reward.state, reward.created);

        rewards.push(reward);
    }

    /**
    * @dev Approves the suggested reward.
    * @param id The id of the reward.
    */
    function approveReward(uint256 id) public onlyManager {
        require(rewards[id].state == RewardState.Pending || rewards[id].state == RewardState.Rejected);
        require(msg.sender != rewards[id].beneficiary);

        rewards[id].state = RewardState.Approved;

        // Withdraw the reward
        _withdraw(id);

        emit RewardStateChanged(rewards[id].id, rewards[id].key, rewards[id].slug, rewards[id].beneficiary, rewards[id].amount, rewards[id].state, rewards[id].created);
    }

    /**
    * @dev Rejects the suggested reward.
    * @param id The id of the reward.
    */
    function rejectReward(uint256 id) public onlyManager {
        require(rewards[id].state == RewardState.Pending || rewards[id].state == RewardState.Approved);

        rewards[id].state = RewardState.Rejected;

        emit RewardStateChanged(rewards[id].id, rewards[id].key, rewards[id].slug, rewards[id].beneficiary, rewards[id].amount, rewards[id].state, rewards[id].created);
    }

    /**
    * @dev Counts the amount of rewards.
    */
    function countRewards() public view returns (uint256) {
        return rewards.length;
    }

    /**
    * @dev Counts the amount of rewards.
    */
    function countTransactions() public view returns (uint256) {
        return transactions.length;
    }

    /**
    * @dev Counts the amount of rewards for a certain Beneficiary.
    */
    function countRewardsOf(address sender) public view returns (uint256) {
        return beneficiaries[sender].length;
    }

    /**
    * @dev Counts the amount of deposits.
    */
    function countDepositsOf(address sender) public view returns (uint256) {
        return deposits[sender].length;
    }

    /**
    * @dev Counts the amount of withdrawels.
    */
    function countWithdrawelsOf(address sender) public view returns (uint256) {
        return withdrawels[sender].length;
    }

    /**
    * @dev Registers a transaction.
    * @param sender The address of the sender.
    * @param receiver The address of the receiver.
    * @param amount The amount the sender sent to the receiver.
    */
    function _registerTransaction(address sender, address receiver, uint256 amount, uint256 created) internal returns (uint256) {
        Transaction memory transaction;

        transaction.id = transactions.length;
        transaction.sender = sender;
        transaction.receiver = receiver;
        transaction.amount = amount;
        transaction.created = created;

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

        rewards[id].state = RewardState.Withdrawn;

        emit Withdrawn(beneficiary, amount, id, now);

        beneficiaries[beneficiary].push(id);

        uint256 tid = _registerTransaction(address(this), beneficiary, amount, now);
        withdrawels[beneficiary].push(tid);
    }
}
