const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const THXToken = contract.fromArtifact('THXToken');
const RewardPool = contract.fromArtifact('RewardPool');
const { REWARD_RULE_POLL_DURATION, vote, timeTravel, finalize } = require('./shared.js');

let token = null;
let pool = null;
let poll = null;

describe('Reward Rules', function() {
    const [from] = accounts;

    before(async () => {
        token = await THXToken.new({ from });
        pool = await RewardPool.new({ from });

        await pool.initialize(from, token.address);
    });

    it('expects voters to own tokens', async function() {
        const balance = web3.utils.toWei('1000', 'ether');

        await token.mint(from, balance, { from });
        await token.mint(accounts[1], balance, { from });
    });

    it('expects the initial duration to be 0', async function() {
        const duration = await pool.rewardRulePollDuration();

        expect(parseInt(duration, 10)).to.equal(0);
    });

    it(
        'can set the reward rule poll duration to ' + REWARD_RULE_POLL_DURATION + ' seconds (3 minutes)',
        async function() {
            await pool.setRewardRulePollDuration(REWARD_RULE_POLL_DURATION, { from });

            const duration = await pool.rewardRulePollDuration();

            expect(parseInt(duration, 10)).to.equal(REWARD_RULE_POLL_DURATION);
        },
    );

    it('can set the reward rule poll min tokens percentage to 0', async function() {
        await pool.setMinRewardRulePollTokensPerc(0, { from });

        const minTokensPerc = await pool.minRewardRulePollTokensPerc();

        expect(parseInt(minTokensPerc, 10)).to.equal(0);
    });

    it('can not create a reward rule when I am not a member', async function() {
        try {
            await pool.addRewardRule({ from: accounts[1] });
        } catch (error) {
            expect(error).to.exist;
        }
    });

    it('can create a reward rule with size 50 as the pool owner', async function() {
        await pool.addRewardRule(50, { from });

        const rule = await pool.rewardRules(0);

        expect(parseInt(rule.amount, 10)).to.equal(0);
        expect(parseInt(rule.state, 10)).to.equal(0);
    });

    it('can see the proposal in the poll contract', async function() {
        const rule = await pool.rewardRules(0);

        poll = contract.fromArtifact('RewardRulePoll', rule.poll);

        expect(poll.address).to.equal(rule.poll);

        const proposal = await poll.proposal();

        expect(parseInt(proposal, 10)).to.equal(50);
    });

    it('can vote for a rule proposal', async () => vote(poll, true));

    it('can travel ' + REWARD_RULE_POLL_DURATION + 's in time', async () => timeTravel(REWARD_RULE_POLL_DURATION / 60));

    it('can finalize the reward rule poll', async () => finalize(poll));

    it('can read the enabled rule amount', async function() {
        const rule = await pool.rewardRules(0);

        expect(parseInt(rule.amount, 10)).to.equal(50);
        expect(parseInt(rule.state, 10)).to.equal(1);
    });

    it('can update the reward rule for a reward size of 100', async function() {
        let rule = await pool.rewardRules(0);

        await pool.updateRewardRule(0, 100, { from });

        rule = await pool.rewardRules(0);

        expect(rule.poll).to.not.equal(poll.address);

        poll = contract.fromArtifact('RewardRulePoll', rule.poll);
    });

    it('can vote for a rule proposal', async () => vote(poll, true));

    it('can travel ' + REWARD_RULE_POLL_DURATION + 's in time', async () => timeTravel(REWARD_RULE_POLL_DURATION / 60));

    it('can finalize the reward rule poll', async () => finalize(poll));

    it('can read the enabled rule amount', async function() {
        const rule = await pool.rewardRules(0);

        expect(parseInt(rule.amount, 10)).to.equal(100);
        expect(parseInt(rule.state, 10)).to.equal(1);
    });

    it('can disable a reward rule', async function() {
        let rule = await pool.rewardRules(0);

        await pool.updateRewardRule(0, 0, { from });

        rule = await pool.rewardRules(0);

        expect(rule.poll).to.not.equal(poll.address);

        poll = contract.fromArtifact('RewardRulePoll', rule.poll);
    });

    it('can vote for a rule proposal', async () => vote(poll, true));

    it('can travel ' + REWARD_RULE_POLL_DURATION + 's in time', async () => timeTravel(REWARD_RULE_POLL_DURATION / 60));

    it('can finalize the reward rule poll', async () => finalize(poll));

    it('can see that the rule is disabled', async function() {
        const rule = await pool.rewardRules(0);

        expect(parseInt(rule.state, 10)).to.equal(0);
    });
});
