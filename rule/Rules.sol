pragma solidity ^0.5.0;

import '../access/roles/MemberRole.sol';
import '../access/roles/ManagerRole.sol';
import '../math/SafeMath.sol';
import '../token/ERC20/IERC20.sol';
import '../poll/polls/RulePoll.sol';

contract Rules is ManagerRole, MemberRole {
    using SafeMath for uint256;

    struct Rule {
        uint256 id;
        string slug;
        uint256 amount;
        RuleState state;
        address creator;
        uint256 created;
    }

    enum RuleState { Pending, Approved, Rejected }

    event RulePollCreated(uint256 id, uint256 proposedAmount);
    event RulePollFinished(uint256 id, bool approved);
    event RuleStateChanged(uint256 id, RuleState state);

    mapping (address => uint256[]) public voters;

    uint256 public constant RULE_POLL_DURATION = 7 days;
    uint256 public constant MAX_VOTED_TOKEN_PERC = 10;

    IERC20 public token;
    RulePoll public rulePoll;
    uint256 public minVotedTokensPerc = 0;

    Rule[] public rules;

    constructor(address _tokenAddress) public {
        token = IERC20(_tokenAddress);
    }

    /**
    * @dev Creates the initial reward rule.
    * @param slug Short readable description of rule.
    * @param amount Reward size suggested for the beneficiary.
    */
    function createRule(string memory slug, uint256 amount) public onlyManager {
        Rule memory rule;

        rule.id = rules.length;
        rule.slug = slug;
        rule.amount = amount;
        rule.state = RuleState.Pending;
        rule.creator = msg.sender;
        rule.created = now;

        emit RuleStateChanged(rule.id, rule.state);
        rules.push(rule);

        startRulePoll(rule.id, rule.amount);
    }

    /**
    * @dev Vote for the suggested rule.
    * @param agree Approve or reject rule.
    */
    function voteForRule(bool agree) public onlyMember {
        require(address(rulePoll) != address(0));

        rulePoll.vote(msg.sender, agree);
    }

    /**
    * @dev Vote for the suggested rule.
    */
    function revokeVoteForRule() public onlyMember {
        require(address(rulePoll) != address(0));

        rulePoll.revokeVote(msg.sender);
    }

    /**
    * @dev Starts the rule poll for chaning the amount.
    */
    function startRulePoll(uint256 id, uint256 proposedAmount) public onlyMember {
        require(address(rulePoll) == address(0) || rulePoll.finalized());

        uint256 startTime = now;
        uint256 endTime = startTime + RULE_POLL_DURATION;

        rulePoll = new RulePoll(id, proposedAmount, address(token), startTime, endTime, minVotedTokensPerc, address(this));

        emit RulePollCreated(id, proposedAmount);
    }

    /**
    * @dev Approves the suggested rule and sets its state to Active.
    * @param id The id of the rule.
    */
    function _approve(uint256 id, uint256 proposedAmount) internal {
        require(rules[id].state == RuleState.Pending || rules[id].state == RuleState.Rejected);
        rules[id].amount = proposedAmount;
        rules[id].state = RuleState.Approved;

        emit RuleStateChanged(rules[id].id, rules[id].state);
    }

    /**
    * @dev Rejects the rule and sets the state to Disabled.
    * @param id The id of the rule.
    */
    /* function _reject(uint256 id) internal {
        require(rules[id].state == RuleState.Pending || rules[id].state == RuleState.Approved);
        rules[id].state = RuleState.Rejected;
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
        require(msg.sender == address(rulePoll) && rulePoll.finalized());

        if(agree) {
            _approve(id, proposedAmount);
        }
        /* else {
            _reject(id);
        } */

        updateMinVotedTokens(rulePoll.getVotedTokensPerc());
        emit RulePollFinished(id, agree);

        delete rulePoll;
    }

    /**
    * @dev Counts the amount of rules.
    */
    function countRules() public view returns (uint256) {
        return rules.length;
    }

}
