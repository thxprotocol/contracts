const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { parseEther } = require("ethers/lib/utils");
const { helpSign } = require('./utils.js');

const RewardState = {
  Disabled: 0,
  Enabled: 1
}

const ENABLE_REWARD = BigNumber.from("2").pow(250);
const DISABLE_REWARD = BigNumber.from("2").pow(251);
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

describe("Test ClaimReward(for), storage/access", function() {
    let AssetPool;

    let gasStation;
    let owner;
    let voter;
    let token;
    let assetPool;
    let reward;
    let rewardPoll;
    let _beforeDeployment;

    let withdrawPoll;
    let withdrawTimestamp;
    before(_beforeDeployment = async function () {
        [owner, voter] = await ethers.getSigners();
        const THXToken = await ethers.getContractFactory("THXToken");
        token = await THXToken.deploy(owner.getAddress(), parseEther("1000000"));

        const GasStation = await ethers.getContractFactory("GasStation");
        gasStation = await GasStation.deploy(owner.getAddress());

        AssetPool = await ethers.getContractFactory("AssetPool")
        assetPool = await AssetPool.deploy(owner.getAddress(), gasStation.address, token.address);
        await assetPool.setProposeWithdrawPollDuration(180);
        await assetPool.setRewardPollDuration(0);

        await assetPool.addReward(parseEther("1"), 200)
        reward = await assetPool.rewards(0);
        rewardPoll = await ethers.getContractAt("RewardPoll", reward.poll);
        await rewardPoll.finalize()
    });
    it("Test claimReward", async function() {
        tx = await helpSign(gasStation, assetPool, "claimReward", [0], owner)
        withdrawTimestamp = tx.timestamp;
        const member = tx.logs[0].args.member
        withdrawPoll = await ethers.getContractAt("WithdrawPoll", tx.logs[0].args.poll);
        expect(member).to.be.eq(await owner.getAddress())
    })
    it("withdrawPoll storage", async function() {
        expect(await withdrawPoll.beneficiary()).to.be.eq(await owner.getAddress())
        expect(await withdrawPoll.amount()).to.be.eq(parseEther("1"))
    })
    it("basepoll storage", async function() {
        expect(await withdrawPoll.pool()).to.be.eq(assetPool.address);
        expect(await withdrawPoll.gasStation()).to.be.eq(gasStation.address);
        expect(await withdrawPoll.startTime()).to.be.eq(withdrawTimestamp);
        expect(await withdrawPoll.endTime()).to.be.eq(withdrawTimestamp + 200);
        expect(await withdrawPoll.yesCounter()).to.be.eq(0);
        expect(await withdrawPoll.noCounter()).to.be.eq(0);
        expect(await withdrawPoll.totalVoted()).to.be.eq(0);
        expect(await withdrawPoll.bypassVotes()).to.be.eq(false);
    })
    it("Verify current approval state", async function() {
        expect(await withdrawPoll.getCurrentApprovalState()).to.be.eq(false);
    });
    it("Claim reward as non member", async function() {
        tx = await helpSign(gasStation, assetPool, "claimReward", [0], voter)
        expect(tx.error).to.be.eq("NOT_MEMBER")
    });
    it("Claim rewardFor non member", async function() {
        tx = await helpSign(gasStation, assetPool, "claimRewardFor", [0, await voter.getAddress()], owner)
        expect(tx.error).to.be.eq("NOT_MEMBER")
    });
    it("Claim rewardFor member as non member", async function() {
        tx = await helpSign(gasStation, assetPool, "claimRewardFor", [0, await voter.getAddress()], voter)
        expect(tx.error).to.be.eq("NOT_MEMBER")
    });
    it("Claim non reward", async function() {
        tx = await helpSign(gasStation, assetPool, "claimReward", [1], owner)
        // returning no tx data
        expect(tx.error).to.be.eq("")
    });
    it("Claim disabled reward", async function() {
        await helpSign(gasStation, assetPool, "updateReward", [0, DISABLE_REWARD, 0], owner)
        reward = await assetPool.rewards(0);
        rewardPoll = await ethers.getContractAt("RewardPoll", reward.poll);
        await rewardPoll.finalize()

        tx = await helpSign(gasStation, assetPool, "claimReward", [0], owner)
        expect(tx.error).to.be.eq("IS_NOT_ENABLED")
    });
})


describe("Test ClaimReward(for), flow", function() {
    // only testing rewardpoll (not basepoll)
    let AssetPool;

    let gasStation;
    let owner;
    let voter;
    let token;
    let assetPool;
    let reward;
    let rewardPoll;
    let _beforeDeployment;

    let withdrawPoll;
    let withdrawTimestamp;
    beforeEach(_beforeDeployment = async function () {
        [owner, holder, voter] = await ethers.getSigners();
        const THXToken = await ethers.getContractFactory("THXToken");
        token = await THXToken.deploy(holder.getAddress(), parseEther("1000000"));

        const GasStation = await ethers.getContractFactory("GasStation");
        gasStation = await GasStation.deploy(owner.getAddress());

        AssetPool = await ethers.getContractFactory("AssetPool")
        assetPool = await AssetPool.deploy(owner.getAddress(), gasStation.address, token.address);

        await token.connect(holder).transfer(assetPool.address, parseEther("1000"))
        await assetPool.setProposeWithdrawPollDuration(180);
        await assetPool.setRewardPollDuration(0);
        await assetPool.addMember(await voter.getAddress());

        await assetPool.addReward(parseEther("1"), 200)
        reward = await assetPool.rewards(0);
        rewardPoll = await ethers.getContractAt("RewardPoll", reward.poll);
        await rewardPoll.finalize()

        tx = await helpSign(gasStation, assetPool, "claimReward", [0], owner)
        withdrawPoll = await ethers.getContractAt("WithdrawPoll", tx.logs[0].args.poll);
    });
    it("Claim reward, no manager", async function() {
        voteTx = await helpSign(gasStation, withdrawPoll, "vote", [true], voter)
        expect(voteTx.error).to.be.eq("NO_MANAGER")
    });
    it("Claim reward", async function() {
        await helpSign(gasStation, withdrawPoll, "vote", [true], owner)
        await ethers.provider.send("evm_increaseTime", [210]);
        await withdrawPoll.finalize()
        expect(await token.balanceOf(await owner.getAddress())).to.be.eq(parseEther("1"))
        expect(await token.balanceOf(await assetPool.address)).to.be.eq(parseEther("999"))
        expect(await ethers.provider.getCode(withdrawPoll.address)).to.be.eq("0x");
    });
    it("Claim reward rejected", async function() {
        await helpSign(gasStation, withdrawPoll, "vote", [false], owner)
        await ethers.provider.send("evm_increaseTime", [210]);
        await withdrawPoll.finalize()
        expect(await token.balanceOf(await owner.getAddress())).to.be.eq(parseEther("0"))
        expect(await token.balanceOf(await assetPool.address)).to.be.eq(parseEther("1000"));
        expect(await ethers.provider.getCode(withdrawPoll.address)).to.be.eq("0x");
    });
})