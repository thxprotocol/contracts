const { time } = require('@openzeppelin/test-helpers');
const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const THXToken = contract.fromArtifact('THXToken');
const RewardPool = contract.fromArtifact('RewardPool');
const gateway = '0xF19D543f5ca6974b8b9b39Fcb923286dE4e9D975';

let token = null;
let pool = null;
let reward = null;

describe('RewardPool', function() {
    const [owner] = accounts;

    before(async () => {
        const amount = web3.utils.toWei('1000');

        token = await THXToken.new(gateway, owner, { from: owner });
        pool = await RewardPool.new({ from: owner });

        await pool.initialize(owner, token.address);

        await token.mint(owner, amount, { from: owner });
    });

    it('can set the owner to ' + owner, async function() {
        expect(await pool.owner()).to.equal(owner);
    });

    it('can make a deposit of 1000 THX', async function() {
        const amount = web3.utils.toWei('5000');
        const oldBalance = web3.utils.fromWei(await token.balanceOf(pool.address));

        await token.mint(pool.address, amount, { from: owner });

        const newBalance = web3.utils.fromWei(await token.balanceOf(pool.address));

        expect(parseInt(newBalance, 10)).to.be.above(parseInt(oldBalance, 10));
    });

    it('can propose a 100 THX reward for ' + accounts[1], async function() {
        const amount = web3.utils.toWei('100');

        expect(await pool.isMember(owner)).to.equal(true);

        await pool.proposeReward(amount, accounts[1], { from: owner });
    });

    it('member can see its rewards address', async function() {
        const rewardAddress = await pool.rewardsOf(accounts[1], 0);

        reward = contract.fromArtifact('RewardPoll', rewardAddress);

        expect(reward.address).to.equal(rewardAddress);
    });

    it('manager can vote on a reward', async function() {
        let vote = await reward.votesByAddress(owner);

        expect(vote.time.toNumber()).to.equal(0);

        await reward.vote(owner, true, { from: owner });

        vote = await reward.votesByAddress(owner);

        expect(vote.time.toNumber()).to.not.equal(0);
    });

    it('manager can travel 180s in time', async function() {
        const before = (await time.latest()).toNumber();

        await time.increase(time.duration.minutes(5));

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
