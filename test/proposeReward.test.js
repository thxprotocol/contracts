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

describe("Test proposeWithdraw, storage/access", function() {
    let AssetPool;

    let gasStation;
    let owner;
    let voter;
    let poolMember;
    let token;
    let assetPool;
    let reward;
    let rewardPoll;
    let _beforeDeployment;

    let withdrawPoll;
    let withdrawTimestamp;
    before(_beforeDeployment = async function () {
        [owner, poolMember, voter] = await ethers.getSigners();
        const THXToken = await ethers.getContractFactory("THXToken");
        token = await THXToken.deploy(owner.getAddress(), parseEther("1000000"));

        const GasStation = await ethers.getContractFactory("GasStation");
        gasStation = await GasStation.deploy(owner.getAddress());


        AssetPool = await ethers.getContractFactory("AssetPool")
        assetPool = await AssetPool.deploy(owner.getAddress(), gasStation.address, token.address);
        await assetPool.addMember(await poolMember.getAddress())
        await assetPool.setProposeWithdrawPollDuration(180);
        await assetPool.setRewardPollDuration(0);

    });
    it("Test proposeWithdraw", async function() {
        tx = await helpSign(gasStation, assetPool, "proposeWithdraw", [parseEther("1"), await poolMember.getAddress()], owner)
        withdrawTimestamp = tx.timestamp;
        const member = tx.logs[0].args.member
        withdrawPoll = await ethers.getContractAt("WithdrawPoll", tx.logs[0].args.poll);
        expect(member).to.be.eq(await poolMember.getAddress())
    })
    it("withdrawPoll storage", async function() {
        expect(await withdrawPoll.beneficiary()).to.be.eq(await poolMember.getAddress())
        expect(await withdrawPoll.amount()).to.be.eq(parseEther("1"))
    })
    it("basepoll storage", async function() {
        expect(await withdrawPoll.pool()).to.be.eq(assetPool.address);
        expect(await withdrawPoll.gasStation()).to.be.eq(gasStation.address);
        expect(await withdrawPoll.startTime()).to.be.eq(withdrawTimestamp);
        expect(await withdrawPoll.endTime()).to.be.eq(withdrawTimestamp + 180);
        expect(await withdrawPoll.yesCounter()).to.be.eq(0);
        expect(await withdrawPoll.noCounter()).to.be.eq(0);
        expect(await withdrawPoll.totalVoted()).to.be.eq(0);
        expect(await withdrawPoll.bypassVotes()).to.be.eq(false);
    })
    it("Verify current approval state", async function() {
        expect(await withdrawPoll.getCurrentApprovalState()).to.be.eq(false);
    });
    it("propose reward as non member", async function() {
        tx = await helpSign(gasStation, assetPool, "proposeWithdraw", [0, await owner.getAddress()], voter)
        expect(tx.error).to.be.eq("NOT_MEMBER")
    });
    it("propose rewardFor non member", async function() {
        tx = await helpSign(gasStation, assetPool, "proposeWithdraw", [0, await voter.getAddress()], owner)
        expect(tx.error).to.be.eq("NOT_MEMBER")
    });
    it("propose rewardFor member as non member", async function() {
        tx = await helpSign(gasStation, assetPool, "proposeWithdraw", [0, await voter.getAddress()], voter)
        expect(tx.error).to.be.eq("NOT_MEMBER")
    });

})
