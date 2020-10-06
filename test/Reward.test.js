const { expect, use } = require('chai');
const { solidity } = require('ethereum-waffle');
use(solidity);
const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const {
    REWARD_POLL_DURATION,
    PROPOSE_WITHDRAW_POLL_DURATION,
    WITHDRAW_AMOUNT,
    MINT_AMOUNT,
    DEPOSIT_AMOUNT,
    VOTER,
    VOTER_PK,
    withdrawPollCreatedEvent,
    vote,
    timeTravel,
    finalize,
} = require('./shared.js');
const THXToken = contract.fromArtifact('THXToken');
const AssetPool = contract.fromArtifact('AssetPool');

describe('Reward with voting', function() {
    const [from] = accounts;
    let owner;
    let token,
        pool,
        reward,
        sig = null;

    before(async () => {
        const amount = web3.utils.toWei('1000');

        token = await THXToken.new({ from });
        pool = await AssetPool.new({ from });

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
        await token.transfer(pool.address, depositAmount, { from });

        const newBalance = web3.utils.fromWei(await token.balanceOf(pool.address));

        expect(parseInt(newBalance, 10)).to.be.above(parseInt(oldBalance, 10));
    });

    it('can configure the reward and reward poll durations', async function() {
        await pool.setProposeWithdrawPollDuration(PROPOSE_WITHDRAW_POLL_DURATION, { from });
        await pool.setRewardPollDuration(REWARD_POLL_DURATION, { from });

        expect(parseInt(await pool.proposeWithdrawPollDuration(), 10)).to.equal(PROPOSE_WITHDRAW_POLL_DURATION);
        expect(parseInt(await pool.rewardPollDuration(), 10)).to.equal(REWARD_POLL_DURATION);
    });

    it('can create a reward with size ' + WITHDRAW_AMOUNT, async function() {
        const withdrawAmount = web3.utils.toWei(WITHDRAW_AMOUNT, 'ether');

        await pool.addReward(withdrawAmount, 180, { from });

        const reward = await pool.rewards(0);

        expect(reward.withdrawAmount.toString()).to.equal('0');
        expect(reward.withdrawDuration.toString()).to.equal('0');
        expect(reward.state.toString()).to.equal('0');
    });

    it('can see the proposal in the poll contract', async function() {
        const reward = await pool.rewards(0);

        poll = contract.fromArtifact('RewardPoll', reward.poll);

        expect(poll.address).to.equal(reward.poll);

        let amount = await poll.withdrawAmount();
        amount = web3.utils.fromWei(amount);
        expect(amount).to.equal('50');

        let duration = await poll.withdrawDuration();
        expect(duration.toString()).to.equal('180');
    });
    it('non member cant vote for a reward proposal', async function() {
        const hash = web3.utils.soliditySha3(from, true, 1, poll.address);
        sig = await web3.eth.accounts.sign(hash, VOTER_PK);
        await expect(vote(poll, VOTER, true, 1, sig['signature'])).to.be.revertedWith('NO_MEMBER');
    });
    it('can make ' + VOTER + 'a member', async function() {
        expect(await pool.isMember(VOTER)).to.equal(false);
        await pool.addMember(VOTER, { from });
        expect(await pool.isMember(VOTER)).to.equal(true);
    });
    it('member can vote for a reward proposal', async function() {
        await vote(poll, VOTER, true, 1, sig['signature']);
    });
    it('admin cant publish twice', async function() {
        await expect(poll.vote(VOTER, true, 1, sig['signature'], { from })).to.be.revertedWith('INVALID_NONCE');
    });
    it('admin cant publish twice', async function() {
        await expect(poll.vote(VOTER, true, 2, sig['signature'], { from })).to.be.revertedWith('WRONG_SIG');
    });
    it('non-admin is not able to publish vote', async function() {
        await expect(poll.vote(VOTER, true, 2, sig['signature'], { from: accounts[2] })).to.be.revertedWith(
            'caller is not the voteAdmin',
        );
    });

    it('can travel ' + REWARD_POLL_DURATION + 's in time', async () => timeTravel(REWARD_POLL_DURATION / 60));

    it('can finalize the reward poll', async () => finalize(poll));

    it('can read the enabled reward amount', async function() {
        const reward = await pool.rewards(0);

        expect(web3.utils.fromWei(reward.withdrawAmount)).to.equal(WITHDRAW_AMOUNT);
        expect(reward.withdrawDuration.toString()).to.equal('180');
        expect(reward.state.toString()).to.equal('1');
    });

    it('can claim a withdraw for reward 0', async function() {
        expect(await pool.isMember(from)).to.equal(true);
        nonce = await pool.getLatestNonce(VOTER);
        nonce = parseInt(nonce) + 1;

        hash = web3.utils.soliditySha3(from, 0, nonce, pool.address);
        sig = await web3.eth.accounts.sign(hash, VOTER_PK);
        await pool.claimWithdraw(0, VOTER, nonce, sig['signature'], { from });
        const [withdrawPollAddress] = await withdrawPollCreatedEvent(pool, VOTER);
        reward = contract.fromArtifact('WithdrawPoll', withdrawPollAddress);

        const beneficiary = await reward.beneficiary();
        const amount = await reward.amount();

        expect(beneficiary).to.equal(VOTER);
        expect(web3.utils.fromWei(amount)).to.equal(WITHDRAW_AMOUNT);
    });
    it('can vote for a withdraw claim', async function() {
        nonce = await pool.getLatestNonce(VOTER);
        nonce = parseInt(nonce) + 1;
        hash = web3.utils.soliditySha3(from, true, nonce, reward.address);
        sig = await web3.eth.accounts.sign(hash, VOTER_PK);
        await vote(reward, VOTER, true, nonce, sig['signature']);
    });
    it('can travel ' + PROPOSE_WITHDRAW_POLL_DURATION + 's in time', async () =>
        timeTravel(PROPOSE_WITHDRAW_POLL_DURATION / 60),
    );
    it('can finalize the reward poll', async () => finalize(reward));
    it('can withdraw the reward', async function() {
        const oldBeneficiaryBalance = await token.balanceOf(VOTER);
        const oldAssetPoolBalance = await token.balanceOf(pool.address);

        await reward.withdraw({ from });

        const newBeneficiaryBalance = await token.balanceOf(VOTER);
        const newAssetPoolBalance = await token.balanceOf(pool.address);

        expect(parseInt(newAssetPoolBalance, 10)).to.lessThan(parseInt(oldAssetPoolBalance, 10));
        expect(parseInt(newBeneficiaryBalance, 10)).to.greaterThan(parseInt(oldBeneficiaryBalance, 10));
    });
});

describe('Reward without voting', function() {
    const [from] = accounts;
    let owner;

    before(async () => {
        const amount = web3.utils.toWei('1000');

        token = await THXToken.new({ from });
        pool = await AssetPool.new({ from });
        await pool.initialize(from, token.address, { from });
        await token.mint(from, amount, { from });
        await pool.addMember(VOTER, { from });
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
        await token.transfer(pool.address, depositAmount, { from });

        const newBalance = web3.utils.fromWei(await token.balanceOf(pool.address));

        expect(parseInt(newBalance, 10)).to.be.above(parseInt(oldBalance, 10));
    });

    it('can configure the reward and reward poll durations', async function() {
        await pool.setProposeWithdrawPollDuration(0, { from });
        await pool.setRewardPollDuration(0, { from });

        expect(parseInt(await pool.proposeWithdrawPollDuration(), 10)).to.equal(0);
        expect(parseInt(await pool.rewardPollDuration(), 10)).to.equal(0);
    });

    it('can create a reward with size ' + WITHDRAW_AMOUNT, async function() {
        const withdrawAmount = web3.utils.toWei(WITHDRAW_AMOUNT, 'ether');

        await pool.addReward(withdrawAmount, 0, { from });

        const reward = await pool.rewards(0);

        expect(reward.withdrawAmount.toString()).to.equal('0');
        expect(reward.withdrawDuration.toString()).to.equal('0');
        expect(reward.state.toString()).to.equal('0');
    });

    it('can see the proposal in the poll contract', async function() {
        const reward = await pool.rewards(0);

        poll = contract.fromArtifact('RewardPoll', reward.poll);

        expect(poll.address).to.equal(reward.poll);

        const amount = await poll.withdrawAmount();
        expect(web3.utils.fromWei(amount)).to.equal('50');

        const duration = await poll.withdrawDuration();
        expect(duration.toString()).to.equal('0');
    });

    it('can finalize the reward poll', async () => finalize(poll));

    it('can read the enabled reward amount', async function() {
        const reward = await pool.rewards(0);

        expect(web3.utils.fromWei(reward.withdrawAmount)).to.equal(WITHDRAW_AMOUNT);
        expect(reward.withdrawDuration.toString()).to.equal('0');
        expect(reward.state.toString()).to.equal('1');
    });

    it('can claim a withdraw for reward 0', async function() {
        expect(await pool.isMember(from)).to.equal(true);
        nonce = await pool.getLatestNonce(VOTER);
        nonce = parseInt(nonce) + 1;

        hash = web3.utils.soliditySha3(from, 0, nonce, pool.address);
        sig = await web3.eth.accounts.sign(hash, VOTER_PK);
        await pool.claimWithdraw(0, VOTER, nonce, sig['signature'], { from });

        const [withdrawPollAddress] = await withdrawPollCreatedEvent(pool, VOTER);

        reward = contract.fromArtifact('WithdrawPoll', withdrawPollAddress);

        const beneficiary = await reward.beneficiary();
        const amount = await reward.amount();

        expect(beneficiary).to.equal(VOTER);
        expect(web3.utils.fromWei(amount)).to.equal(WITHDRAW_AMOUNT);
    });

    it('can finalize the reward poll', async () => finalize(reward));
    it('can withdraw the reward', async function() {
        const oldBeneficiaryBalance = await token.balanceOf(from);
        const oldAssetPoolBalance = await token.balanceOf(pool.address);

        await reward.withdraw({ from });

        const newBeneficiaryBalance = await token.balanceOf(from);
        const newAssetPoolBalance = await token.balanceOf(pool.address);

        expect(parseInt(newAssetPoolBalance, 10)).to.lessThan(parseInt(oldAssetPoolBalance, 10));
        expect(parseInt(newBeneficiaryBalance, 10)).to.greaterThan(parseInt(oldBeneficiaryBalance, 10));
    });
});
