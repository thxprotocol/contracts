const { expect } = require("chai");
const { parseEther } = require("ethers/lib/utils");
const { helpSign } = require('./utils.js');


describe("AddReward", function() {

    let gasStation;
    let owner;
    let voter;
    let token;
    let assetPool;
    let reward;

    beforeEach(async function () {
      [owner, voter] = await ethers.getSigners();

      const THXToken = await ethers.getContractFactory("THXToken");
      token = await THXToken.deploy(owner.getAddress(), parseEther("1000"));

      const GasStation = await ethers.getContractFactory("GasStation");
      gasStation = await GasStation.deploy(owner.getAddress());

      const AssetPool = await ethers.getContractFactory("AssetPool");
      assetPool = await AssetPool.deploy(owner.getAddress(), gasStation.address, token.address);

      await assetPool.addManager(voter.getAddress());
      await token.transfer(assetPool.address, parseEther("1000"));
      await assetPool.setProposeWithdrawPollDuration(180);
      await assetPool.setRewardPollDuration(180);
      await assetPool.addReward(parseEther("5"), 180);
      reward = await assetPool.rewards(0);

    });
    it("updateReward not possible", async function() {
        res = await helpSign(gasStation, assetPool, "updateReward", [0, parseEther("5"), 180], voter)
        expect(res.error).to.be.eq("IS_NOT_FINALIZED")
    });
  })