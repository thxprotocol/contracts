pragma solidity ^0.6.4;

import './access/roles/MemberRole.sol';
import './access/roles/ManagerRole.sol';
import './math/SafeMath.sol';
import './token/ERC20/IERC20.sol';
import './poll/polls/RulePoll.sol';
import './reward/Reward.sol';
import './THXToken.sol';

contract RewardPool is ManagerRole, MemberRole  {
    using SafeMath for uint256;

    enum RuleState { Active, Disabled }

    event Deposited(address indexed sender, uint256 amount);
    event Withdrawn(address indexed beneficiary, uint256 reward);
    event RewardPollCreated(uint256 id, address reward);
    event RewardPollFinished(uint256 id, address reward, bool approved);
    event RulePollCreated(uint256 id, uint256 proposedAmount, address sender);
    event RulePollFinished(uint256 id, bool approved, address sender);
    event RuleStateChanged(uint256 id, RuleState state, address sender);

    uint256 public constant RULE_POLL_DURATION = 1 minutes;
    uint256 public constant MAX_VOTED_TOKEN_PERC = 10;

    uint256 public minVotedTokensPerc = 0;
    THXToken public token;
    string public name;
    address public creator;

    Rule[] public rules;
    Reward[] public rewards;

    mapping (address => Deposit[]) public deposits;
    mapping (address => Withdrawel[]) public withdrawels;
    mapping (address => Reward[]) public rewardsOf;

    struct Rule {
        uint256 id;
        uint256 amount;
        RuleState state;
        RulePoll poll;
        address creator;
        uint256 created;
    }

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

    constructor(
        string memory _name,
        address _tokenAddress
    ) public {
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
    * @dev Counts the amount of Rewards.
    */
    function countRewardsOf(address beneficiary) public view returns (uint256) {
        return rewardsOf[beneficiary].length;
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
    * @param account Address of the beneficiary
    */
    function createReward(uint256 rule, address account) public {
        Reward reward = new Reward(rewards.length, rule, account, msg.sender, rules[rule].amount, address(token), address(this));

        emit RewardPollCreated(rewards.length, address(reward));

        rewards.push(reward);
        rewardsOf[account].push(reward);
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
        emit RewardPollFinished(id, address(rewards[id]), agree);
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

    /**
    * @dev Creates the initial reward rule.
    */
    function createRule() public onlyManager {
        Rule memory rule;

        rule.id = rules.length;
        rule.amount = 0;
        rule.state = RuleState.Disabled;
        rule.creator = msg.sender;
        rule.created = now;

        emit RuleStateChanged(rule.id, rule.state, msg.sender);

        rules.push(rule);
    }

    /**
    * @dev Vote for the suggested rule.
    * @param id reference to the rule that the poll runs for
    * @param agree Approve or reject rule.
    */
    function voteForRule(uint256 id, bool agree) public onlyMember {
        require(address(rules[id].poll) != address(0));

        rules[id].poll.vote(msg.sender, agree);
    }

    /**
    * @dev Vote for the suggested rule.
    * @param id reference to the rule that the poll runs for
    */
    function revokeVoteForRule(uint256 id) public onlyMember {
        require(address(rules[id].poll) != address(0));

        rules[id].poll.revokeVote(msg.sender);
    }

    /**
    * @dev Starts the rule poll for chaning the amount.
    * @param id The id of the rule.
    * @param id The new amount for the rule.
    */
    function startRulePoll(uint256 id, uint256 proposedAmount) public onlyMember {
        require(address(rules[id].poll) == address(0) || rules[id].poll.finalized());
        require(proposedAmount != rules[id].amount);

        uint256 startTime = now;
        uint256 endTime = startTime + RULE_POLL_DURATION;

        rules[id].poll = new RulePoll(id, proposedAmount, address(token), startTime, endTime, minVotedTokensPerc, address(this));

        emit RulePollCreated(id, proposedAmount, msg.sender);
    }

    /**
    * @dev Approves the suggested rule and sets its state to Active.
    * @param id The id of the rule.
    * @param id The new amount for the rule.
    */
    function _approve(uint256 id, uint256 proposedAmount) internal {
        if (proposedAmount == 0) {
            rules[id].state = RuleState.Disabled;
        }

        if (proposedAmount != 0 && rules[id].state == RuleState.Disabled) {
            rules[id].state = RuleState.Active;
        }

        rules[id].amount = proposedAmount;

        emit RuleStateChanged(rules[id].id, rules[id].state, msg.sender);
    }

    /**
    * @dev Rejects the rule and sets the state to Disabled.
    * @param id The id of the rule.
    */
    /* function _reject(uint256 id) internal {
        require(rules[id].state == RuleState.Pending || rules[id].state == RuleState.Active);
        rules[id].state = RuleState.Disabled;
    } */

    /**
     * @dev Update minVotedTokensPerc value after tap poll.
     * Set new value == 50% from current voted tokens amount
     */
    function updateMinVotedTokens(uint256 _minVotedTokensPerc) internal {
        uint256 newPerc = _minVotedTokensPerc.div(2);
        if(newPerc > MAX_VOTED_TOKEN_PERC) {
            minVotedTokensPerc = MAX_VOTED_TOKEN_PERC;
            return;
        }
        minVotedTokensPerc = newPerc;
    }

    /**
    * @dev Called when poll is finished
    * @param id Referenced reward rule
    * @param agree Bool for checking the result of the poll.
    * @param proposedAmount The proposed reward size.
    */
    function onRulePollFinish(uint256 id, bool agree, uint256 proposedAmount) external {
        require(msg.sender == address(rules[id].poll) && rules[id].poll.finalized());

        if(agree) {
            _approve(id, proposedAmount);
        }

        updateMinVotedTokens(rules[id].poll.getVotedTokensPerc());
        emit RulePollFinished(id, agree, msg.sender);

        delete rules[id].poll;
    }

    /**
    * @dev Counts the amount of rules.
    */
    function countRules() public view returns (uint256) {
        return rules.length;
    }
}
