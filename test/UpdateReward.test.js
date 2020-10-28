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


describe("Test UpdateReward", function() {
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
    let updateReward = async(gasStation, assetPool, args, account, pass) => {
      tx = await helpSign(gasStation, assetPool, "updateReward", args, account)
      if (tx.error !== null ) {
        return {
          data: null,
          error: tx.error
        }
      }
      reward = await assetPool.rewards(0);
      rewardPoll = await ethers.getContractAt("RewardPoll", reward.poll);
      tx = await helpSign(gasStation, rewardPoll, "vote", [pass], account)
      if (tx.error !== null) {
        return {
          data: null,
          error: tx.error
        }
      }
      await ethers.provider.send("evm_increaseTime", [180]);
      await rewardPoll.finalize()
      return {
        data: await assetPool.rewards(0),
        error: null
      }
    }

    beforeEach(async function () {
        [owner, voter] = await ethers.getSigners();
        const THXToken = await ethers.getContractFactory("THXToken");
        token = await THXToken.deploy(owner.getAddress(), parseEther("1000000"));

        const GasStation = await ethers.getContractFactory("GasStation");
        gasStation = await GasStation.deploy(owner.getAddress());

        AssetPool = await ethers.getContractFactory("AssetPool")
        assetPool = await AssetPool.deploy(owner.getAddress(), gasStation.address, token.address);
        await assetPool.addManager(voter.getAddress());
        await assetPool.setProposeWithdrawPollDuration(180);
        await assetPool.setRewardPollDuration(180);

        await token.transfer(assetPool.address, parseEther("1000"));
        // addreawrd
        tx = await assetPool.addReward(parseEther("5"), 250);

        reward = await assetPool.rewards(0);
        rewardPoll = await ethers.getContractAt("RewardPoll", reward.poll);

        voteTx = await helpSign(gasStation, rewardPoll, "vote", [true], voter)
        await ethers.provider.send("evm_increaseTime", [180]);
        await rewardPoll.finalize()
        reward = await assetPool.rewards(0);
        // update reward
    });
    it("Verify updateReward storage contract", async function() {
      expect(reward.poll).to.be.eq(ZERO_ADDRESS)
      tx = await helpSign(gasStation, assetPool, "updateReward", [0, parseEther("10"), 300], voter)
      reward = await assetPool.rewards(0);
      expect(reward.poll).to.not.be.eq(ZERO_ADDRESS)
      rewardPoll = await ethers.getContractAt("RewardPoll", reward.poll);

      expect(await rewardPoll.id()).to.be.eq(0);
      expect(await rewardPoll.withdrawAmount()).to.be.eq(parseEther("10"));
      expect(await rewardPoll.withdrawDuration()).to.be.eq(300);
      expect(await rewardPoll.pool()).to.be.eq(assetPool.address);
      expect(await rewardPoll.gasStation()).to.be.eq(gasStation.address);
      expect(await rewardPoll.startTime()).to.be.eq(tx.timestamp);
      expect(await rewardPoll.endTime()).to.be.eq(tx.timestamp + 180);
      expect(await rewardPoll.yesCounter()).to.be.eq(0);
      expect(await rewardPoll.noCounter()).to.be.eq(0);
      expect(await rewardPoll.totalVoted()).to.be.eq(0);
      expect(await rewardPoll.bypassVotes()).to.be.eq(false);
      expect(await rewardPoll.getCurrentApprovalState()).to.be.eq(false);
    });
    it("approve", async function() {
      res = await updateReward(gasStation, assetPool, [0, parseEther("10"), 300], voter, true)
      reward = res.data

      expect(reward.poll).to.be.eq(ZERO_ADDRESS)
      expect(reward.id).to.be.eq(0);
      expect(reward.withdrawAmount).to.be.eq(parseEther("10"));
      expect(reward.withdrawDuration).to.be.eq(300);
      expect(reward.state).to.be.eq(RewardState.Enabled);
    })
    it("Decline", async function() {
      res = await updateReward(gasStation, assetPool, [0, parseEther("10"), 300], voter, false)
      reward = res.data
      // Expect original withdrawAmount & withdrawDuration
      expect(reward.poll).to.be.eq(ZERO_ADDRESS)
      expect(reward.id).to.be.eq(0);
      expect(reward.withdrawAmount).to.be.eq(parseEther("5"));
      expect(reward.withdrawDuration).to.be.eq(250);
      expect(reward.state).to.be.eq(RewardState.Enabled);
    });
    it("Initial values", async function() {
      result = await updateReward(gasStation, assetPool, [0, 0, 0], voter, false)
      expect(result.error).to.be.eq("NOT_ALLOWED")
    });
    it("Partial initial values", async function() {
      result = await updateReward(gasStation, assetPool, [0, 1, 0], voter, false)
      expect(result.error).to.be.eq(null)

      result = await updateReward(gasStation, assetPool, [0, 1, 1], voter, false)
      expect(result.error).to.be.eq(null)
    });
    it("revert ENABLE reward", async function() {
      result = await updateReward(gasStation, assetPool, [0, ENABLE_REWARD, 0], voter, false)
      expect(result.error).to.be.eq("ALREADY_ENABLED")
    });
    it("DISABLE reward", async function() {
      result = await updateReward(gasStation, assetPool, [0, DISABLE_REWARD, 0], voter, true)
      expect(result.error).to.be.eq(null)
      reward = result.data

      expect(reward.poll).to.be.eq(ZERO_ADDRESS)
      expect(reward.id).to.be.eq(0);
      expect(reward.withdrawAmount).to.be.eq(parseEther("5"));
      expect(reward.withdrawDuration).to.be.eq(250);
      expect(reward.state).to.be.eq(RewardState.Disabled);

    })
    it("revert DISABLE reward", async function() {
      result = await updateReward(gasStation, assetPool, [0, DISABLE_REWARD, 0], voter, true)
      expect(result.error).to.be.eq(null)

      result = await updateReward(gasStation, assetPool, [0, DISABLE_REWARD, 0], voter, false)
      expect(result.error).to.be.eq("ALREADY_DISABLED")
    });
    it("revert equal params", async function() {
      result = await updateReward(gasStation, assetPool, [0, parseEther("5"), 250], voter, false)
      expect(result.error).to.be.eq("IS_EQUAL")
    });
    it("DISABLE + ENABLE reward", async function() {
      await updateReward(gasStation, assetPool, [0, DISABLE_REWARD, 0], voter, true)
      result = await updateReward(gasStation, assetPool, [0, ENABLE_REWARD, 60], voter, true)
      expect(result.error).to.be.eq(null)
      reward = result.data

      expect(reward.poll).to.be.eq(ZERO_ADDRESS)
      expect(reward.id).to.be.eq(0);
      expect(reward.withdrawAmount).to.be.eq(parseEther("5"));
      expect(reward.withdrawDuration).to.be.eq(250);
      expect(reward.state).to.be.eq(RewardState.Enabled);

    })
    it("Update disabled reward", async function() {
      await updateReward(gasStation, assetPool, [0, DISABLE_REWARD, 0], voter, true)
      result = await updateReward(gasStation, assetPool, [0, parseEther("50"), 120], voter, true)
      expect(result.error).to.be.eq(null)
      reward = result.data

      expect(reward.poll).to.be.eq(ZERO_ADDRESS)
      expect(reward.id).to.be.eq(0);
      expect(reward.withdrawAmount).to.be.eq(parseEther("50"));
      expect(reward.withdrawDuration).to.be.eq(120);
      expect(reward.state).to.be.eq(RewardState.Disabled);

    })
    it("Update reward bypass votes", async function() {
      await assetPool.setRewardPollDuration(0);

      err = await helpSign(gasStation, assetPool, "updateReward", [0, parseEther("500"), 1200], owner)
      reward = await assetPool.rewards(0);
      rewardPoll = await ethers.getContractAt("RewardPoll", reward.poll);
      await rewardPoll.finalize()
      reward = await assetPool.rewards(0);
      expect(reward.poll).to.be.eq(ZERO_ADDRESS)
      expect(reward.id).to.be.eq(0);
      expect(reward.withdrawAmount).to.be.eq(parseEther("500"));
      expect(reward.withdrawDuration).to.be.eq(1200);
      expect(reward.state).to.be.eq(RewardState.Enabled);

    })
})