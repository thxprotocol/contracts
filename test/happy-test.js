const { expect } = require("chai");
const { parseEther } = require("ethers/lib/utils");
const { helpSign } = require('./utils.js');

describe("Happy flow", function() {
  let owner;
  let token;
  let assetPool;
  let voter;
  let withdrawPoll;
  let gasStation;

  before(async function () {
    [owner, voter] = await ethers.getSigners();

    const THXToken = await ethers.getContractFactory("THXToken");
    token = await THXToken.deploy(owner.getAddress(), parseEther("1000"));

    const GasStation = await ethers.getContractFactory("GasStation");
    gasStation = await GasStation.deploy(owner.getAddress());

    const AssetPool = await ethers.getContractFactory("AssetPool");
    assetPool = await AssetPool.deploy(owner.getAddress(), gasStation.address, token.address);
  });

  it("Setup token", async function() {
    expect(await token.balanceOf(assetPool.address)).to.be.eq(parseEther("0"));
    await token.transfer(assetPool.address, parseEther("1000"));
    expect(await token.balanceOf(assetPool.address)).to.be.eq(parseEther("1000"));
  });
  it('Configure poll durations', async function() {
    expect(await assetPool.proposeWithdrawPollDuration()).to.be.eq(0);
    expect(await assetPool.rewardPollDuration()).to.be.eq(0);

    await assetPool.setProposeWithdrawPollDuration(180);
    await assetPool.setRewardPollDuration(180);

    expect(await assetPool.proposeWithdrawPollDuration()).to.be.eq(180);
    expect(await assetPool.rewardPollDuration()).to.be.eq(180);
  });
  it('Create reward', async function() {
    // todo check storage

    await assetPool.addReward(parseEther("5"), 180);

  })
  it('Add manager', async function() {
    expect(await assetPool.isManager(voter.getAddress())).to.equal(false);
    await assetPool.addManager(voter.getAddress());
    expect(await assetPool.isManager(voter.getAddress())).to.equal(true);
  })
  it('Vote reward', async function() {
    const reward = await assetPool.rewards(0);
    let poll = await ethers.getContractAt("RewardPoll", reward.poll);
    await helpSign(gasStation, poll, "vote", [true], voter)
  })
  it('Finalize reward', async function() {
    await ethers.provider.send("evm_increaseTime", [180])
    await ethers.provider.send("evm_mine")
    let reward = await assetPool.rewards(0);

    let poll = await ethers.getContractAt("RewardPoll", reward.poll);
    await poll.finalize();
    reward = await assetPool.rewards(0);


    // todo check storage
  })
  it('Post withdraw claim for a reward', async function() {
    const tx = await helpSign(gasStation, assetPool, "claimReward", [0], voter)
    withdrawPoll = await tx.logs[0].args.poll
    const withdraw = await ethers.getContractAt("WithdrawPoll", withdrawPoll);

    const beneficiary = await withdraw.beneficiary();
    const amount = await withdraw.amount();
    expect(beneficiary).to.equal(await voter.getAddress());
    expect(amount).to.equal(parseEther("5"));
  })
  it('Vote for withdraw claim', async function() {
    withdraw = await ethers.getContractAt("WithdrawPoll", await withdrawPoll);
    await helpSign(gasStation, withdraw, "vote", [true], voter)
  })
  it('Finalize withdraw claim', async function() {
    await ethers.provider.send("evm_increaseTime", [180])
    await ethers.provider.send("evm_mine")

    const withdraw = await ethers.getContractAt("WithdrawPoll", withdrawPoll);
    tx = await withdraw.finalize();
  })
  it('Execute withdraw claim', async function() {
    expect(await token.balanceOf(voter.getAddress())).to.be.eq(0);
    expect(await token.balanceOf(assetPool.address)).to.be.eq(parseEther("1000"));

    const withdraw = await ethers.getContractAt("WithdrawPoll", withdrawPoll);
    tx = await helpSign(gasStation, withdraw, "withdraw", [], voter)
    // this one is currently failing as the withdraw() is executed after the contract is finalized
    // which selfdestructs the contract.
    // TODO execute withdraw logic on finalize
    expect(await token.balanceOf(voter.getAddress())).to.be.eq(parseEther("5"));
    expect(await token.balanceOf(assetPool.address)).to.be.eq(parseEther("995"));
  })
});
