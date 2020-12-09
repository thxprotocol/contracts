const { expect } = require('chai');
const { BigNumber } = require('ethers');
const { parseEther } = require('ethers/lib/utils');
const { helpSign } = require('./utils.js');

const RewardState = {
    Disabled: 0,
    Enabled: 1,
};

const ENABLE_REWARD = BigNumber.from('2').pow(250);
const DISABLE_REWARD = BigNumber.from('2').pow(251);
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

describe('Test AddReward', function () {
    let AssetPool;

    let gasStation;
    let owner;
    let voter;
    let token;
    let assetPool;
    let reward;
    let rewardPoll;
    let _beforeDeployment;

    let voteTx;
    let finalizeTx;

    before(
        (_beforeDeployment = async function () {
            [owner, voter] = await ethers.getSigners();
            const THXToken = await ethers.getContractFactory('THXToken');
            token = await THXToken.deploy(owner.getAddress(), parseEther('1000000'));

            const GasStation = await ethers.getContractFactory('GasStation');
            gasStation = await GasStation.deploy(owner.getAddress());

            AssetPool = await ethers.getContractFactory('AssetPool');
        }),
    );
    describe('Add reward', async function () {
        before(async function () {
            await _beforeDeployment;

            assetPool = await AssetPool.deploy(owner.getAddress(), gasStation.address, token.address);
            await assetPool.addManager(voter.getAddress());
            await assetPool.setProposeWithdrawPollDuration(180);
            await assetPool.setRewardPollDuration(180);

            await token.transfer(assetPool.address, parseEther('1000'));
        });
        it('ENABLE_REWARD magic number', async function () {
            await expect(assetPool.addReward(ENABLE_REWARD, 180)).to.be.revertedWith('NOT_VALID');
        });
        it('DISABLE_REWARD magic number', async function () {
            await expect(assetPool.addReward(DISABLE_REWARD, 180)).to.be.revertedWith('NOT_VALID');
        });
        it('Test setRewardPollDuration', async function () {
            await assetPool.setRewardPollDuration(300);
            tx = await assetPool.addReward(parseEther('1'), 200);
            rewardTimestamp = (await ethers.provider.getBlock(tx.blockNumber)).timestamp;
            reward = await assetPool.rewards(0);
            rewardPoll = await ethers.getContractAt('RewardPoll', reward.poll);

            expect(await rewardPoll.startTime()).to.be.eq(rewardTimestamp);
            expect(await rewardPoll.endTime()).to.be.eq(rewardTimestamp + 300);

            await assetPool.setRewardPollDuration(900);
            // does not affect current polls
            expect(await rewardPoll.startTime()).to.be.eq(rewardTimestamp);
            expect(await rewardPoll.endTime()).to.be.eq(rewardTimestamp + 300);

            tx = await assetPool.addReward(parseEther('1'), 200);
            rewardTimestamp = (await ethers.provider.getBlock(tx.blockNumber)).timestamp;
            reward = await assetPool.rewards(1);
            rewardPoll = await ethers.getContractAt('RewardPoll', reward.poll);

            expect(await rewardPoll.startTime()).to.be.eq(rewardTimestamp);
            expect(await rewardPoll.endTime()).to.be.eq(rewardTimestamp + 900);
        });
    });
    describe('Existing reward', async function () {
        before(async function () {
            await _beforeDeployment;

            assetPool = await AssetPool.deploy(owner.getAddress(), gasStation.address, token.address);
            await assetPool.addManager(voter.getAddress());
            await assetPool.setProposeWithdrawPollDuration(180);
            await assetPool.setRewardPollDuration(180);

            await token.transfer(assetPool.address, parseEther('1000'));

            tx = await assetPool.addReward(parseEther('5'), 180);
            rewardTimestamp = (await ethers.provider.getBlock(tx.blockNumber)).timestamp;
            reward = await assetPool.rewards(0);
            rewardPoll = await ethers.getContractAt('RewardPoll', reward.poll);
        });
        it('Verify reward storage', async function () {
            expect(reward.id).to.be.eq(0);
            expect(reward.withdrawAmount).to.be.eq(parseEther('0'));
            expect(reward.withdrawDuration).to.be.eq(0);
            expect(reward.state).to.be.eq(RewardState.Disabled);
        });
        it('Verify reward poll storage', async function () {
            expect(await rewardPoll.id()).to.be.eq(0);
            expect(await rewardPoll.withdrawAmount()).to.be.eq(parseEther('5'));
            expect(await rewardPoll.withdrawDuration()).to.be.eq(180);
        });
        it('Verify basepoll storage', async function () {
            expect(await rewardPoll.pool()).to.be.eq(assetPool.address);
            expect(await rewardPoll.gasStation()).to.be.eq(gasStation.address);
            expect(await rewardPoll.startTime()).to.be.eq(rewardTimestamp);
            expect(await rewardPoll.endTime()).to.be.eq(rewardTimestamp + 180);
            expect(await rewardPoll.yesCounter()).to.be.eq(0);
            expect(await rewardPoll.noCounter()).to.be.eq(0);
            expect(await rewardPoll.totalVoted()).to.be.eq(0);
            expect(await rewardPoll.bypassVotes()).to.be.eq(false);
        });
        it('Verify current approval state', async function () {
            expect(await rewardPoll.getCurrentApprovalState()).to.be.eq(false);
        });
        it('updateReward not possible', async function () {
            res = await helpSign(gasStation, assetPool, 'updateReward', [0, parseEther('5'), 180], voter);
            expect(res.error).to.be.eq('IS_NOT_FINALIZED');
        });
        it('claimReward not possible', async function () {
            res = await helpSign(gasStation, assetPool, 'claimReward', [0], voter);
            expect(res.error).to.be.eq('IS_NOT_ENABLED');
        });
        it('claimRewardFor not possible', async function () {
            await expect(assetPool.connect(owner).claimRewardFor(0, await voter.getAddress())).to.be.revertedWith(
                'IS_NOT_ENABLED',
            );
        });
    });
    describe('Vote reward', async function () {
        before(async function () {
            await _beforeDeployment;

            assetPool = await AssetPool.deploy(owner.getAddress(), gasStation.address, token.address);
            await assetPool.addManager(voter.getAddress());
            await assetPool.setProposeWithdrawPollDuration(180);
            await assetPool.setRewardPollDuration(180);

            await token.transfer(assetPool.address, parseEther('1000'));

            tx = await assetPool.addReward(parseEther('5'), 180);
            rewardTimestamp = (await ethers.provider.getBlock(tx.blockNumber)).timestamp;
            reward = await assetPool.rewards(0);
            rewardPoll = await ethers.getContractAt('RewardPoll', reward.poll);

            voteTx = await helpSign(gasStation, rewardPoll, 'vote', [true], voter);
        });
        it('Verify basepoll storage', async function () {
            expect(await rewardPoll.yesCounter()).to.be.eq(1);
            expect(await rewardPoll.noCounter()).to.be.eq(0);
            expect(await rewardPoll.totalVoted()).to.be.eq(1);
            expect(await rewardPoll.bypassVotes()).to.be.eq(false);

            const vote = await rewardPoll.votesByAddress(voter.getAddress());
            expect(vote.time).to.be.eq(voteTx.timestamp);
            expect(vote.weight).to.be.eq(1);
            expect(vote.agree).to.be.eq(true);
        });
        it('Verify current approval state', async function () {
            expect(await rewardPoll.getCurrentApprovalState()).to.be.eq(true);
        });
        it('Voting twice not possible', async function () {
            res = await helpSign(gasStation, rewardPoll, 'vote', [true], voter);
            expect(res.error).to.be.eq('HAS_VOTED');
        });
        it('Revoke vote', async function () {
            await helpSign(gasStation, rewardPoll, 'revokeVote', [], voter);
            expect(await rewardPoll.yesCounter()).to.be.eq(0);
            expect(await rewardPoll.noCounter()).to.be.eq(0);
            expect(await rewardPoll.totalVoted()).to.be.eq(0);
            expect(await rewardPoll.bypassVotes()).to.be.eq(false);

            const vote = await rewardPoll.votesByAddress(voter.getAddress());
            expect(vote.time).to.be.eq(0);
            expect(vote.weight).to.be.eq(0);
            expect(vote.agree).to.be.eq(false);
        });
        it('Revoke twice', async function () {
            await helpSign(gasStation, rewardPoll, 'revokeVote', [], voter);
            res = await helpSign(gasStation, rewardPoll, 'revokeVote', [], voter);
            expect(res.error).to.be.eq('HAS_NOT_VOTED');
        });
        it('Revoke + vote again(st)', async function () {
            await helpSign(gasStation, rewardPoll, 'revokeVote', [], voter);
            const voteTx2 = await helpSign(gasStation, rewardPoll, 'vote', [false], voter);
            expect(await rewardPoll.yesCounter()).to.be.eq(0);
            expect(await rewardPoll.noCounter()).to.be.eq(1);
            expect(await rewardPoll.totalVoted()).to.be.eq(1);
            expect(await rewardPoll.bypassVotes()).to.be.eq(false);

            const vote = await rewardPoll.votesByAddress(voter.getAddress());
            expect(vote.time).to.be.eq(voteTx2.timestamp);
            expect(vote.weight).to.be.eq(1);
            expect(vote.agree).to.be.eq(false);
        });
        it('Finalizing not possible', async function () {
            // if this one fails, please check timestmap first
            await expect(rewardPoll.finalize()).to.be.revertedWith('WRONG_STATE');
        });
    });
    describe('Finalize reward (approved)', async function () {
        beforeEach(async function () {
            await _beforeDeployment;

            assetPool = await AssetPool.deploy(owner.getAddress(), gasStation.address, token.address);
            await assetPool.addManager(voter.getAddress());
            await assetPool.setProposeWithdrawPollDuration(180);
            await assetPool.setRewardPollDuration(180);

            await token.transfer(assetPool.address, parseEther('1000'));

            tx = await assetPool.addReward(parseEther('5'), 250);

            reward = await assetPool.rewards(0);
            rewardPoll = await ethers.getContractAt('RewardPoll', reward.poll);

            voteTx = await helpSign(gasStation, rewardPoll, 'vote', [true], voter);
            await ethers.provider.send('evm_increaseTime', [180]);
            await rewardPoll.finalize();
            reward = await assetPool.rewards(0);
        });
        it('Verify basepoll storage', async function () {
            expect(await ethers.provider.getCode(rewardPoll.address)).to.be.eq('0x');
        });
        it('Verify reward storage', async function () {
            expect(reward.poll).to.be.eq(ZERO_ADDRESS);
            expect(reward.id).to.be.eq(0);
            expect(reward.withdrawAmount).to.be.eq(parseEther('5'));
            expect(reward.withdrawDuration).to.be.eq(250);
            expect(reward.state).to.be.eq(RewardState.Enabled);
        });
    });
    describe('Finalize reward (declined)', async function () {
        beforeEach(async function () {
            await _beforeDeployment;

            assetPool = await AssetPool.deploy(owner.getAddress(), gasStation.address, token.address);
            await assetPool.addManager(voter.getAddress());
            await assetPool.setProposeWithdrawPollDuration(180);
            await assetPool.setRewardPollDuration(180);

            await token.transfer(assetPool.address, parseEther('1000'));

            tx = await assetPool.addReward(parseEther('5'), 250);

            reward = await assetPool.rewards(0);
            rewardPoll = await ethers.getContractAt('RewardPoll', reward.poll);

            voteTx = await helpSign(gasStation, rewardPoll, 'vote', [false], voter);
            await ethers.provider.send('evm_increaseTime', [180]);
            await rewardPoll.finalize();

            reward = await assetPool.rewards(0);
        });
        it('Verify basepoll storage', async function () {
            expect(await ethers.provider.getCode(rewardPoll.address)).to.be.eq('0x');
        });
        it('Verify reward storage', async function () {
            expect(reward.poll).to.be.eq(ZERO_ADDRESS);
            expect(reward.id).to.be.eq(0);
            expect(reward.withdrawAmount).to.be.eq('0');
            expect(reward.withdrawDuration).to.be.eq(0);
            expect(reward.state).to.be.eq(RewardState.Disabled);
        });
    });
    describe('Bypass voting', async function () {
        beforeEach(async function () {
            await _beforeDeployment;

            assetPool = await AssetPool.deploy(owner.getAddress(), gasStation.address, token.address);
            await assetPool.addManager(voter.getAddress());
            await assetPool.setProposeWithdrawPollDuration(180);
            await assetPool.setRewardPollDuration(0);

            await token.transfer(assetPool.address, parseEther('1000'));

            tx = await assetPool.addReward(parseEther('5'), 250);
            rewardTimestamp = (await ethers.provider.getBlock(tx.blockNumber)).timestamp;

            reward = await assetPool.rewards(0);
            rewardPoll = await ethers.getContractAt('RewardPoll', reward.poll);
        });
        it('Verify reward storage', async function () {
            expect(reward.id).to.be.eq(0);
            expect(reward.withdrawAmount).to.be.eq(parseEther('0'));
            expect(reward.withdrawDuration).to.be.eq(0);
            expect(reward.state).to.be.eq(RewardState.Disabled);
        });
        it('Verify reward poll storage', async function () {
            expect(await rewardPoll.id()).to.be.eq(0);
            expect(await rewardPoll.withdrawAmount()).to.be.eq(parseEther('5'));
            expect(await rewardPoll.withdrawDuration()).to.be.eq(250);
        });
        it('Verify basepoll storage', async function () {
            expect(await rewardPoll.pool()).to.be.eq(assetPool.address);
            expect(await rewardPoll.gasStation()).to.be.eq(gasStation.address);
            expect(await rewardPoll.startTime()).to.be.eq(rewardTimestamp);
            expect(await rewardPoll.endTime()).to.be.eq(rewardTimestamp);
            expect(await rewardPoll.yesCounter()).to.be.eq(0);
            expect(await rewardPoll.noCounter()).to.be.eq(0);
            expect(await rewardPoll.totalVoted()).to.be.eq(0);
            expect(await rewardPoll.bypassVotes()).to.be.eq(true);
        });
        it('Verify current approval state', async function () {
            expect(await rewardPoll.getCurrentApprovalState()).to.be.eq(true);
        });
        it('Finalize + Verify basepoll storage', async function () {
            await rewardPoll.finalize();
            expect(await ethers.provider.getCode(rewardPoll.address)).to.be.eq('0x');
        });
        it('Finalize + Verify reward storage', async function () {
            await rewardPoll.finalize();
            reward = await assetPool.rewards(0);
            expect(reward.poll).to.be.eq(ZERO_ADDRESS);
            expect(reward.id).to.be.eq(0);
            expect(reward.withdrawAmount).to.be.eq(parseEther('5'));
            expect(reward.withdrawDuration).to.be.eq(250);
            expect(reward.state).to.be.eq(RewardState.Enabled);
        });
    });
});
