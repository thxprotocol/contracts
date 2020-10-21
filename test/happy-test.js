const { expect } = require("chai");
const { parseEther } = require("ethers/lib/utils");

let gasStation;

async function HelpSign(object, name, args, account) {
  nonce = await gasStation.getLatestNonce(account.getAddress());
  nonce = parseInt(nonce) + 1;
  const call = object.interface.encodeFunctionData(name, args);
  const hash = web3.utils.soliditySha3(call, object.address, gasStation.address, nonce)
  const sig = await account.signMessage(ethers.utils.arrayify(hash))
  tx = await gasStation.call(call, object.address, nonce, sig);
  return tx.wait()
}

describe("Greeter", function() {
  let owner;
  let token;
  let assetPool;
  let voter;
  let withdrawPoll;


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
    await HelpSign(poll, "vote", [true], voter)
  })
  it('Finalize reward', async function() {
    await ethers.provider.send("evm_increaseTime", [180])
    await ethers.provider.send("evm_mine")
    let reward = await assetPool.rewards(0);

    let poll = await ethers.getContractAt("RewardPoll", reward.poll);
    await poll.tryToFinalize();
    reward = await assetPool.rewards(0);


    // todo check storage
  })
  it('Post withdraw claim for a reward', async function() {
    const tx = await HelpSign(assetPool, "claimReward", [0], voter)
    const event =  await assetPool.interface.parseLog(tx.logs[0])
    withdrawPoll = await event.args.poll
    const withdraw = await ethers.getContractAt("WithdrawPoll", withdrawPoll);

    const beneficiary = await withdraw.beneficiary();
    const amount = await withdraw.amount();
    expect(beneficiary).to.equal(await voter.getAddress());
    expect(amount).to.equal(parseEther("5"));
  })
  it('Vote for withdraw claim', async function() {
    withdraw = await ethers.getContractAt("WithdrawPoll", await withdrawPoll);
    await HelpSign(withdraw, "vote", [true], voter)
  })
  it('Finalize withdraw claim', async function() {
    await ethers.provider.send("evm_increaseTime", [180])
    await ethers.provider.send("evm_mine")

    const withdraw = await ethers.getContractAt("WithdrawPoll", withdrawPoll);
    await withdraw.tryToFinalize();
  })
  it('Execute withdraw claim', async function() {
    expect(await token.balanceOf(voter.getAddress())).to.be.eq(0);
    expect(await token.balanceOf(assetPool.address)).to.be.eq(parseEther("1000"));

    const withdraw = await ethers.getContractAt("WithdrawPoll", withdrawPoll);
    await HelpSign(withdraw, "withdraw", [], voter)

    expect(await token.balanceOf(voter.getAddress())).to.be.eq(parseEther("5"));
    expect(await token.balanceOf(assetPool.address)).to.be.eq(parseEther("995"));
  })
});
