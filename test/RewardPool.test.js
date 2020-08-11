const { time } = require('@openzeppelin/test-helpers');
const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const { GATEWAY } = require('./config.js');
const THXToken = contract.fromArtifact('THXToken');
const RewardPool = contract.fromArtifact('RewardPool');

let token = null;
let pool = null;
let reward = null;

describe('Reward Pool', function() {
    const [from] = accounts;
    let owner;

    before(async () => {
        const amount = web3.utils.toWei('1000');

        token = await THXToken.new(GATEWAY, from, { from });
        pool = await RewardPool.new({ from });

        await pool.initialize(from, token.address, { from });
        await token.mint(from, amount, { from });
    });

    it('can set the owner to ' + from, async function() {
        owner = await pool.owner();
        expect(owner).to.equal(from);
    });

    it('can make a deposit of 1000 THX', async function() {
        const amount = web3.utils.toWei('5000');
        const oldBalance = web3.utils.fromWei(await token.balanceOf(pool.address));

        await token.mint(pool.address, amount, { from });

        const newBalance = web3.utils.fromWei(await token.balanceOf(pool.address));

        expect(parseInt(newBalance, 10)).to.be.above(parseInt(oldBalance, 10));
    });

    it('expects the initial duration to be 0', async function() {
        const duration = await pool.rewardPollDuration();

        expect(parseInt(duration, 10)).to.equal(0);
    });

    it('can set the reward poll duration to 180 seconds (3 minutes)', async function() {
        await pool.setRewardPollDuration(180, { from });

        const duration = await pool.rewardPollDuration();

        expect(parseInt(duration, 10)).to.equal(parseInt(duration, 10));
    });

    it('can propose a 100 THX reward for ' + accounts[1], async function() {
        const amount = web3.utils.toWei('100');

        expect(await pool.isMember(from)).to.equal(true);

        await pool.proposeReward(amount, accounts[1], { from });
    });

    it('member can see its rewards address', async function() {
        const rewardAddress = await pool.rewardsOf(accounts[1], 0);

        reward = contract.fromArtifact('RewardPoll', rewardAddress);

        expect(reward.address).to.equal(rewardAddress);
    });

    it('manager can vote on a reward', async function() {
        let vote = await reward.votesByAddress(from);

        expect(vote.time.toNumber()).to.equal(0);

        await reward.vote(from, true, { from });

        vote = await reward.votesByAddress(from);

        expect(vote.time.toNumber()).to.not.equal(0);
    });

    it('manager can travel 180s in time', async function() {
        const before = (await time.latest()).toNumber();

        await time.increase(time.duration.minutes(3));

        const after = (await time.latest()).toNumber();

        expect(after).to.be.above(before);
    });

    it('member can finalize the reward poll', async function() {
        expect(await reward.finalized()).to.equal(false);

        await reward.tryToFinalize({ from: accounts[1] });

        expect(await reward.finalized()).to.equal(true);
    });

    it('member can withdraw the reward', async function() {
        const oldBalance = web3.utils.fromWei(await token.balanceOf(accounts[1]));

        await reward.withdraw({ from: accounts[1] });

        const newBalance = web3.utils.fromWei(await token.balanceOf(accounts[1]));

        expect(parseInt(newBalance, 10)).to.be.above(parseInt(oldBalance, 10));
    });
});
