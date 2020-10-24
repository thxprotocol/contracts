const { expect } = require("chai");
const { parseEther } = require("ethers/lib/utils");
const { helpSign } = require('./utils.js');

// testing which function are public
describe("Test auth", async function() {
    let AssetPool;

    let gasStation;
    let owner;
    let manager;
    let member;
    let nonuser;
    let token;
    let assetPool;

    before(async function () {
      [owner, manager, member, nonuser] = await ethers.getSigners();
      const THXToken = await ethers.getContractFactory("THXToken");
      token = await THXToken.deploy(owner.getAddress(), parseEther("1000000"));

      const GasStation = await ethers.getContractFactory("GasStation");
      gasStation = await GasStation.deploy(owner.getAddress());

      AssetPool = await ethers.getContractFactory("AssetPool")
      assetPool = await AssetPool.deploy(owner.getAddress(), gasStation.address, token.address);
      await assetPool.addReward(parseEther("5"), 180);
      await assetPool.addManager(manager.getAddress());
      await assetPool.addMember(member.getAddress());
    });
    describe.only("AssetPool", async function() {
        it("setProposeWithdrawPollDuration", async function () {
            await assetPool.connect(owner).setProposeWithdrawPollDuration(180)
            await assetPool.connect(manager).setProposeWithdrawPollDuration(180)
            await expect(assetPool.connect(member).setProposeWithdrawPollDuration(180)).to.be.revertedWith("NOT_MANAGER")
            // gas station
            tx = await helpSign(gasStation, assetPool, "setProposeWithdrawPollDuration", [180], owner)
            expect(tx.error).to.be.eq("NOT_MANAGER");
        })
        it("setRewardPollDuration", async function () {
            await assetPool.connect(owner).setRewardPollDuration(180)
            await assetPool.connect(manager).setRewardPollDuration(180)
            await expect(assetPool.connect(member).setRewardPollDuration(180)).to.be.revertedWith("NOT_MANAGER")
            // gas station
            tx = await helpSign(gasStation, assetPool, "setRewardPollDuration", [180], owner)
            expect(tx.error).to.be.eq("NOT_MANAGER");
        })
        it("addReward", async function () {
            await assetPool.connect(owner).addReward(parseEther("5"), 10)
            await expect(assetPool.connect(manager).addReward(parseEther("5"), 10)).to.be.revertedWith("NOT_OWNER")
            await expect(assetPool.connect(member).addReward(parseEther("5"), 10)).to.be.revertedWith("NOT_OWNER")
            // gas station
            tx = await helpSign(gasStation, assetPool, "addReward", [parseEther("5"), 10], owner)
            expect(tx.error).to.be.eq("NOT_OWNER");
        })
        it("updateReward", async function () {
            await expect(assetPool.connect(owner).updateReward(0, parseEther("5"), 10)).to.be.revertedWith("NOT_GASSTATION")
            await expect(assetPool.connect(manager).updateReward(0, parseEther("5"), 10)).to.be.revertedWith("NOT_GASSTATION")
            await expect(assetPool.connect(member).updateReward(0, parseEther("5"), 10)).to.be.revertedWith("NOT_GASSTATION")
            // gas station
            tx = await helpSign(gasStation, assetPool, "updateReward", [0, parseEther("5"), 10], owner)
            expect(tx.error).to.be.eq("IS_NOT_FINALIZED");

            tx = await helpSign(gasStation, assetPool, "updateReward", [0, parseEther("5"), 10], manager)
            expect(tx.error).to.be.eq("IS_NOT_FINALIZED");

            tx = await helpSign(gasStation, assetPool, "updateReward", [0, parseEther("5"), 10], member)
            expect(tx.error).to.be.eq("IS_NOT_FINALIZED");

            tx = await helpSign(gasStation, assetPool, "updateReward", [0, parseEther("5"), 10], nonuser)
            expect(tx.error).to.be.eq("NOT_MEMBER");
        })
        it("claimRewardFor", async function () {
            await expect(assetPool.connect(owner).claimRewardFor(0, await owner.getAddress())).to.be.revertedWith("NOT_GASSTATION")
            await expect(assetPool.connect(manager).claimRewardFor(0, await owner.getAddress())).to.be.revertedWith("NOT_GASSTATION")
            await expect(assetPool.connect(member).claimRewardFor(0, await owner.getAddress())).to.be.revertedWith("NOT_GASSTATION")
            // gas station
            tx = await helpSign(gasStation, assetPool, "claimRewardFor", [0, await member.getAddress()], owner)
            expect(tx.error).to.be.eq("IS_NOT_ENABLED");

            tx = await helpSign(gasStation, assetPool, "claimRewardFor", [0, await member.getAddress()], manager)
            expect(tx.error).to.be.eq("IS_NOT_ENABLED");

            tx = await helpSign(gasStation, assetPool, "claimRewardFor", [0, await member.getAddress()], member)
            expect(tx.error).to.be.eq("IS_NOT_ENABLED");

            tx = await helpSign(gasStation, assetPool, "claimRewardFor", [0, await member.getAddress()], nonuser)
            expect(tx.error).to.be.eq("NOT_MEMBER");

            // for non member
            tx = await helpSign(gasStation, assetPool, "claimRewardFor", [0, await nonuser.getAddress()], member)
            expect(tx.error).to.be.eq("NOT_MEMBER");
        })
        it("claimReward", async function () {
            await expect(assetPool.connect(owner).claimReward(0)).to.be.revertedWith("NOT_GASSTATION")
            await expect(assetPool.connect(manager).claimReward(0)).to.be.revertedWith("NOT_GASSTATION")
            await expect(assetPool.connect(member).claimReward(0)).to.be.revertedWith("NOT_GASSTATION")
            // gas station
            tx = await helpSign(gasStation, assetPool, "claimReward", [0], owner)
            expect(tx.error).to.be.eq("IS_NOT_ENABLED");

            tx = await helpSign(gasStation, assetPool, "claimReward", [0], manager)
            expect(tx.error).to.be.eq("IS_NOT_ENABLED");

            tx = await helpSign(gasStation, assetPool, "claimReward", [0], member)
            expect(tx.error).to.be.eq("IS_NOT_ENABLED");

            tx = await helpSign(gasStation, assetPool, "claimReward", [0], nonuser)
            expect(tx.error).to.be.eq("NOT_MEMBER");
        })
        it("proposeWithdraw", async function () {
            await expect(assetPool.connect(owner).proposeWithdraw(0, await nonuser.getAddress())).to.be.revertedWith("NOT_GASSTATION")
            await expect(assetPool.connect(manager).proposeWithdraw(0, await nonuser.getAddress())).to.be.revertedWith("NOT_GASSTATION")
            await expect(assetPool.connect(member).proposeWithdraw(0, await nonuser.getAddress())).to.be.revertedWith("NOT_GASSTATION")
            // gas station
            tx = await helpSign(gasStation, assetPool, "proposeWithdraw", [0, await member.getAddress()], owner)
            expect(tx.error).to.be.eq(null);

            tx = await helpSign(gasStation, assetPool, "proposeWithdraw", [0, await member.getAddress()], manager)
            expect(tx.error).to.be.eq(null);

            tx = await helpSign(gasStation, assetPool, "proposeWithdraw", [0, await member.getAddress()], member)
            expect(tx.error).to.be.eq(null);

            tx = await helpSign(gasStation, assetPool, "proposeWithdraw", [0, await member.getAddress()], nonuser)
            expect(tx.error).to.be.eq("NOT_MEMBER");

            // for non member
            tx = await helpSign(gasStation, assetPool, "proposeWithdraw", [0, await nonuser.getAddress()], member)
            expect(tx.error).to.be.eq("NOT_MEMBER");
        })
        it("_createWithdrawPoll", async function () {
            expect(
                () => assetPool._createWithdrawPoll(
                    0, 180, nonuser.getAddress()
                )
            ).to.be.throw("assetPool._createWithdrawPoll is not a function")
        })
        it("_createRewardPoll", async function () {
            expect(
                () => assetPool._createRewardPoll(
                    0, 180, 5
                )
            ).to.be.throw("assetPool._createRewardPoll is not a function")
        })
        it("onRewardPollFinish", async function () {
            await expect(assetPool.connect(owner).onRewardPollFinish(0, 180, 5, false)).to.be.revertedWith("NOT_POLL")
            await expect(assetPool.connect(manager).onRewardPollFinish(0, 180, 5, false)).to.be.revertedWith("NOT_POLL")
            await expect(assetPool.connect(member).onRewardPollFinish(0, 180, 5, false)).to.be.revertedWith("NOT_POLL")
          // gas station
            tx = await helpSign(gasStation, assetPool, "onRewardPollFinish", [0, 180, 5, false], owner)
            expect(tx.error).to.be.eq("NOT_POLL");

        })
        it("onWithdrawal", async function () {
            await expect(assetPool.connect(owner).onWithdrawal(await owner.getAddress(), 1)).to.be.revertedWith("NOT_POLL")
            await expect(assetPool.connect(manager).onWithdrawal(await owner.getAddress(), 1)).to.be.revertedWith("NOT_POLL")
            await expect(assetPool.connect(member).onWithdrawal(await owner.getAddress(), 1)).to.be.revertedWith("NOT_POLL")
          // gas station
            tx = await helpSign(gasStation, assetPool, "onWithdrawal", [await owner.getAddress(), 1], owner)
            expect(tx.error).to.be.eq("NOT_POLL");

        })
    })

})