const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const THXToken = contract.fromArtifact('THXToken');
const AssetPool = contract.fromArtifact('AssetPool');
const { REWARD_POLL_DURATION, VOTER, VOTER_PK, vote, timeTravel, finalize } = require('./shared.js');

describe('Rewards', function() {
    const [from] = accounts;

    let token,
        pool,
        poll = null;

    before(async () => {
        token = await THXToken.new({ from });
        pool = await AssetPool.new({ from });

        await pool.initialize(from, token.address);
    });

    it('expects voters to own tokens', async function() {
        const balance = web3.utils.toWei('1000', 'ether');

        await token.mint(from, balance, { from });
        await token.mint(accounts[1], balance, { from });
    });

    it('expects the initial duration to be 0', async function() {
        const duration = await pool.rewardPollDuration();

        expect(parseInt(duration, 10)).to.equal(0);
    });

    it('can set the reward poll duration to ' + REWARD_POLL_DURATION + ' seconds (3 minutes)', async function() {
        await pool.setRewardPollDuration(REWARD_POLL_DURATION, { from });

        const duration = await pool.rewardPollDuration();

        expect(parseInt(duration, 10)).to.equal(REWARD_POLL_DURATION);
    });

    it('can not create a reward when I am not a member', async function() {
        try {
            await pool.addReward({ from: accounts[1] });
        } catch (error) {
            expect(error).to.exist;
        }
    });

    it('can create a reward with size 50 as the pool owner', async function() {
        await pool.addReward(50, { from });

        const reward = await pool.rewards(0);

        expect(parseInt(reward.amount, 10)).to.equal(0);
        expect(parseInt(reward.state, 10)).to.equal(0);
    });

    it('can see the proposal in the poll contract', async function() {
        const reward = await pool.rewards(0);

        poll = contract.fromArtifact('RewardPoll', reward.poll);

        expect(poll.address).to.equal(reward.poll);

        const amount = await poll.amount();

        expect(parseInt(amount, 10)).to.equal(50);
    });
    it('non member cant vote for a reward proposal', async function() {
        const hash = web3.utils.soliditySha3(from, true, 1, poll.address);
        sig = await web3.eth.accounts.sign(hash, VOTER_PK);
        await expect(await vote(poll, VOTER, true, 1, sig['signature'])).to.be.revertedWith('NO_MEMBER');
    });
    it('can make ' + VOTER + 'a member', async function() {
        expect(await pool.isMember(VOTER)).to.equal(false);
        await pool.addMember(VOTER, { from });
        expect(await pool.isMember(VOTER)).to.equal(true);
    });
    it('can vote for a reward proposal', async function() {
        nonce = await poll.getLatestNonce(VOTER);
        expect(nonce.eq(0));

        await vote(poll, VOTER, true, 1, sig['signature']);

        nonce = await poll.getLatestNonce(VOTER);
        expect(nonce.eq(1));
    });

    it('can travel ' + REWARD_POLL_DURATION + 's in time', async () => timeTravel(REWARD_POLL_DURATION / 60));

    it('can finalize the reward reward poll', async () => finalize(poll));

    it('can read the enabled reward amount', async function() {
        const reward = await pool.rewards(0);

        expect(parseInt(reward.amount, 10)).to.equal(50);
        expect(parseInt(reward.state, 10)).to.equal(1);
    });

    it('can update the reward for a reward size of 100', async function() {
        let reward = await pool.rewards(0);

        await pool.updateReward(0, 100, { from });

        reward = await pool.rewards(0);

        expect(reward.poll).to.not.equal(poll.address);

        poll = contract.fromArtifact('RewardPoll', reward.poll);
    });

    it('can vote for a proposal', async function() {
        hash = web3.utils.soliditySha3(from, true, 1, poll.address);
        sig = await web3.eth.accounts.sign(hash, VOTER_PK);
        await vote(poll, VOTER, true, 1, sig['signature']);
    });

    it('can travel ' + REWARD_POLL_DURATION + 's in time', async () => timeTravel(REWARD_POLL_DURATION / 60));

    it('can finalize the reward poll', async () => finalize(poll));

    it('can read the enabled amount', async function() {
        const reward = await pool.rewards(0);

        expect(parseInt(reward.amount, 10)).to.equal(100);
        expect(parseInt(reward.state, 10)).to.equal(1);
    });

    it('can disable a reward', async function() {
        let reward = await pool.rewards(0);

        await pool.updateReward(0, 0, { from });

        reward = await pool.rewards(0);

        expect(reward.poll).to.not.equal(poll.address);

        poll = contract.fromArtifact('RewardPoll', reward.poll);
    });

    it('can vote for a proposal', async function() {
        hash = web3.utils.soliditySha3(from, true, 1, poll.address);
        sig = await web3.eth.accounts.sign(hash, VOTER_PK);
        await vote(poll, VOTER, true, 1, sig['signature']);
    });

    it('can travel ' + REWARD_POLL_DURATION + 's in time', async () => timeTravel(REWARD_POLL_DURATION / 60));

    it('can finalize the reward poll', async () => finalize(poll));

    it('can see that the reward is disabled', async function() {
        const reward = await pool.rewards(0);

        expect(parseInt(reward.state, 10)).to.equal(0);
    });
});
