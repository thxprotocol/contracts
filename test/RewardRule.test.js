const { time } = require('@openzeppelin/test-helpers');
const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const THXToken = contract.fromArtifact('THXToken');
const RewardPool = contract.fromArtifact('RewardPool');
const { GATEWAY, REWARD_RULE_POLL_DURATION } = require('./config.js');

let token = null;
let pool = null;
let poll = null;

describe('Reward Rules', function() {
    const [from] = accounts;

    before(async () => {
        token = await THXToken.new(GATEWAY, from, { from });
        pool = await RewardPool.new({ from });

        await pool.initialize(from, token.address);
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
        await pool.setMinRewardRulePollTokensPerc(10, { from });

        const minTokensPerc = await pool.minRewardRulePollTokensPerc();

        expect(parseInt(minTokensPerc, 10)).to.equal(10);
    });

    it('can not create a reward rule when I am not a member', async function() {
        try {
            await pool.addRewardRule({ from: accounts[1] });
        } catch (error) {
            expect(error).to.exist;
        }
    });

    it('can create a reward rule when I am a manager', async function() {
        await pool.addRewardRule(50, { from });

        const rule = await pool.rewardRules(0);

        expect(parseInt(rule.amount, 10)).to.equal(50);
    });

    it('can see the state of the reward rule poll contract state', async function() {
        const rule = await pool.rewardRules(0);

        poll = contract.fromArtifact('RewardRulePoll', rule.poll);

        expect(poll.address).to.equal(rule.poll);

        const proposal = await poll.proposal();

        expect(parseInt(proposal, 10)).to.equal(50);
    });

    it('can vote for a rule proposal', async function() {
        let vote = await poll.votesByAddress(from);

        expect(vote.time.toNumber()).to.equal(0);

        await poll.vote(from, true, { from });

        vote = await poll.votesByAddress(from);

        expect(vote.time.toNumber()).to.not.equal(0);
    });

    it('can travel 180s in time', async function() {
        const before = (await time.latest()).toNumber();

        await time.increase(time.duration.minutes(3));

        const after = (await time.latest()).toNumber();

        expect(after).to.be.above(before);
    });

    it('can finalize the reward rule poll', async function() {
        expect(await poll.finalized()).to.equal(false);

        await poll.tryToFinalize({ from: accounts[1] });

        expect(await poll.finalized()).to.equal(true);
    });

    it('can read the new rule amount', async function() {
        const rule = await pool.rewardRules(0);

        expect(parseInt(rule.amount, 10)).to.not.equal(100);
    });

    it('can update the reward rule for a reward size of 100', async function() {
        let rule = await pool.rewardRules(0);

        await pool.updateRewardRule(0, 100, { from });

        rule = await pool.rewardRules(0);

        expect(rule.poll).to.not.equal(poll.address);
    });
});
