const { expect } = require('chai');
const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const {
    REWARD_RULE_POLL_DURATION,
    REWARD_POLL_DURATION,
    REWARD_RULE_AMOUNT,
    MINT_AMOUNT,
    DEPOSIT_AMOUNT,
    vote,
    timeTravel,
    finalize,
} = require('./shared.js');
const THXToken = contract.fromArtifact('THXToken');
const RewardPool = contract.fromArtifact('RewardPool');

let token = null;
let pool = null;
let reward = null;

describe('Reward with voting', function() {
    const [from] = accounts;
    let owner;

    before(async () => {
        const amount = web3.utils.toWei('1000');

        token = await THXToken.new({ from });
        pool = await RewardPool.new({ from });

        await pool.initialize(from, token.address, { from });
        await token.mint(from, amount, { from });
    });

    it('can set the owner to ' + from, async function() {
        owner = await pool.owner();
        expect(owner).to.equal(from);
    });

    it('can make a deposit of ' + DEPOSIT_AMOUNT + ' THX', async function() {
        const mintAmount = web3.utils.toWei(MINT_AMOUNT, 'ether');
        const depositAmount = web3.utils.toWei(DEPOSIT_AMOUNT, 'ether');
        const oldBalance = web3.utils.fromWei(await token.balanceOf(pool.address));

        await token.mint(from, mintAmount, { from });

        await token.approve(pool.address, depositAmount, { from });
        await pool.deposit(depositAmount, { from });

        const newBalance = web3.utils.fromWei(await token.balanceOf(pool.address));

        expect(parseInt(newBalance, 10)).to.be.above(parseInt(oldBalance, 10));
    });

    it('can configure the reward and reward rule poll durations', async function() {
        await pool.setWithdrawPollDuration(REWARD_POLL_DURATION, { from });
        await pool.setRewardRulePollDuration(REWARD_RULE_POLL_DURATION, { from });

        expect(parseInt(await pool.withdrawPollDuration(), 10)).to.equal(REWARD_POLL_DURATION);
        expect(parseInt(await pool.rewardRulePollDuration(), 10)).to.equal(REWARD_RULE_POLL_DURATION);
    });

    it('can create a reward rule with size ' + REWARD_RULE_AMOUNT, async function() {
        const rewardRuleAmount = web3.utils.toWei(REWARD_RULE_AMOUNT, 'ether');

        await pool.addRewardRule(rewardRuleAmount, { from });

        const rule = await pool.rewardRules(0);

        expect(rule.amount.toString()).to.equal('0');
        expect(rule.state.toString()).to.equal('0');
    });

    it('can see the proposal in the poll contract', async function() {
        const rule = await pool.rewardRules(0);

        poll = contract.fromArtifact('RewardRulePoll', rule.poll);

        expect(poll.address).to.equal(rule.poll);

        let amount = await poll.amount();
        amount = web3.utils.fromWei(amount);

        expect(amount).to.equal('50');
    });

    it('can vote for a rule proposal', async () => vote(poll, true));

    it('can travel ' + REWARD_RULE_POLL_DURATION + 's in time', async () => timeTravel(REWARD_RULE_POLL_DURATION / 60));

    it('can finalize the reward rule poll', async () => finalize(poll));

    it('can read the enabled rule amount', async function() {
        const rule = await pool.rewardRules(0);

        expect(web3.utils.fromWei(rule.amount)).to.equal(REWARD_RULE_AMOUNT);
        expect(rule.state.toString()).to.equal('1');
    });

    it('can claim a withdraw for rule 0', async function() {
        expect(await pool.isMember(from)).to.equal(true);

        await pool.claimWithdraw(0, { from });

        const withdrawPollAddress = await pool.withdrawalPollsOf(from, 0, { from });

        reward = contract.fromArtifact('WithdrawPoll', withdrawPollAddress);

        const beneficiary = await reward.beneficiary();
        const amount = await reward.amount();

        expect(beneficiary).to.equal(from);
        expect(web3.utils.fromWei(amount)).to.equal(REWARD_RULE_AMOUNT);
    });

    it('can vote for a withdraw claim', async () => vote(reward, true));
    it('can travel ' + REWARD_POLL_DURATION + 's in time', async () => timeTravel(REWARD_POLL_DURATION / 60));
    it('can finalize the reward poll', async () => finalize(reward));
    it('can withdraw the reward', async function() {
        const oldBeneficiaryBalance = await token.balanceOf(from);
        const oldRewardPoolBalance = await token.balanceOf(pool.address);

        await reward.withdraw({ from });

        const newBeneficiaryBalance = await token.balanceOf(from);
        const newRewardPoolBalance = await token.balanceOf(pool.address);

        expect(parseInt(newRewardPoolBalance, 10)).to.lessThan(parseInt(oldRewardPoolBalance, 10));
        expect(parseInt(newBeneficiaryBalance, 10)).to.greaterThan(parseInt(oldBeneficiaryBalance, 10));
    });
});

describe('Reward without voting', function() {
    const [from] = accounts;
    let owner;

    before(async () => {
        const amount = web3.utils.toWei('1000');

        token = await THXToken.new({ from });
        pool = await RewardPool.new({ from });

        await pool.initialize(from, token.address, { from });
        await token.mint(from, amount, { from });
    });

    it('can set the owner to ' + from, async function() {
        owner = await pool.owner();
        expect(owner).to.equal(from);
    });

    it('can make a deposit of ' + DEPOSIT_AMOUNT + ' THX', async function() {
        const mintAmount = web3.utils.toWei(MINT_AMOUNT, 'ether');
        const depositAmount = web3.utils.toWei(DEPOSIT_AMOUNT, 'ether');
        const oldBalance = web3.utils.fromWei(await token.balanceOf(pool.address));

        await token.mint(from, mintAmount, { from });

        await token.approve(pool.address, depositAmount, { from });
        await pool.deposit(depositAmount, { from });

        const newBalance = web3.utils.fromWei(await token.balanceOf(pool.address));

        expect(parseInt(newBalance, 10)).to.be.above(parseInt(oldBalance, 10));
    });

    it('can configure the reward and reward rule poll durations', async function() {
        await pool.setWithdrawPollDuration(0, { from });
        await pool.setRewardRulePollDuration(0, { from });

        expect(parseInt(await pool.withdrawPollDuration(), 10)).to.equal(0);
        expect(parseInt(await pool.rewardRulePollDuration(), 10)).to.equal(0);
    });

    it('can create a reward rule with size ' + REWARD_RULE_AMOUNT, async function() {
        const rewardRuleAmount = web3.utils.toWei(REWARD_RULE_AMOUNT, 'ether');

        await pool.addRewardRule(rewardRuleAmount, { from });

        const rule = await pool.rewardRules(0);

        expect(rule.amount.toString()).to.equal('0');
        expect(rule.state.toString()).to.equal('0');
    });

    it('can see the proposal in the poll contract', async function() {
        const rule = await pool.rewardRules(0);

        poll = contract.fromArtifact('RewardRulePoll', rule.poll);

        expect(poll.address).to.equal(rule.poll);

        const amount = await poll.amount();

        expect(web3.utils.fromWei(amount)).to.equal('50');
    });

    it('can finalize the reward rule poll', async () => finalize(poll));

    it('can read the enabled rule amount', async function() {
        const rule = await pool.rewardRules(0);

        expect(web3.utils.fromWei(rule.amount)).to.equal(REWARD_RULE_AMOUNT);
        expect(rule.state.toString()).to.equal('1');
    });

    it('can claim a withdraw for rule 0', async function() {
        expect(await pool.isMember(from)).to.equal(true);

        await pool.claimWithdraw(0, { from });

        const withdrawPollAddress = await pool.withdrawalPollsOf(from, 0, { from });

        reward = contract.fromArtifact('WithdrawPoll', withdrawPollAddress);

        const beneficiary = await reward.beneficiary();
        const amount = await reward.amount();

        expect(beneficiary).to.equal(from);
        expect(web3.utils.fromWei(amount)).to.equal(REWARD_RULE_AMOUNT);
    });

    it('can finalize the reward poll', async () => finalize(reward));
    it('can withdraw the reward', async function() {
        const oldBeneficiaryBalance = await token.balanceOf(from);
        const oldRewardPoolBalance = await token.balanceOf(pool.address);

        await reward.withdraw({ from });

        const newBeneficiaryBalance = await token.balanceOf(from);
        const newRewardPoolBalance = await token.balanceOf(pool.address);

        expect(parseInt(newRewardPoolBalance, 10)).to.lessThan(parseInt(oldRewardPoolBalance, 10));
        expect(parseInt(newBeneficiaryBalance, 10)).to.greaterThan(parseInt(oldBeneficiaryBalance, 10));
    });
});
