const Web3 = require('web3');
const { ZWeb3, ProxyAdminProject, Contracts } = require('@openzeppelin/upgrades');
const gateway = '0xF19D543f5ca6974b8b9b39Fcb923286dE4e9D975';

const web3 = new Web3('http://localhost:7545');

async function main() {
    // Set up web3 object, connected to the local development network, initialize the Upgrades library
    ZWeb3.initialize(web3.currentProvider);

    // Take the first account ganache returns as the from account.
    const accounts = await ZWeb3.eth.getAccounts();
    const [from] = await ZWeb3.eth.getAccounts();
    const amount = web3.utils.toWei('1000');

    // Create the token contract
    const TokenContract = Contracts.getFromLocal('THXToken');
    const tokenContract = new ZWeb3.eth.Contract(TokenContract.schema.abi);

    const token = await tokenContract
        .deploy({ data: TokenContract.schema.bytecode, arguments: [gateway, from] })
        .send({ from, gas: 5000000, gasPrice: 5e9 });

    // Mint THX for owner
    await token.methods.mint(from, amount).send({ from });

    // Create an Admin project
    const rewardPoolProject = new ProxyAdminProject('RewardPoolProject', null, null, {
        from,
        gas: 5000000,
        gasPrice: 5e9,
    });

    // Deploy an instance of RewardPool
    const PoolContract = Contracts.getFromLocal('RewardPool');
    const RewardPollContract = Contracts.getFromLocal('RewardPoll');
    // Make a change on the contract, and compile it.
    const PoolContractUpgraded = Contracts.getFromLocal('RewardPool2');

    // Create a proxy for the first contract.
    const poolProxy = await rewardPoolProject.createProxy(PoolContract, {
        from,
        initArgs: [from, token.options.address],
    });

    // // Create a proxy for the upgraded contract.
    const rewardProxy = await rewardPoolProject.createProxy(RewardPollContract, {
        from,
        initArgs: [accounts[1], amount, 180, token.options.address, poolProxy.options.address],
    });

    await poolProxy.methods.proposeReward(rewardProxy.options.address).send({ from });

    await poolProxy.methods.setRewardPollDuration(180).send({ from });
    await printProxy('RewardPool', poolProxy);

    await rewardPoolProject.upgradeProxy(poolProxy.options.address, PoolContractUpgraded, {
        from,
    });

    await poolProxy.methods.setRewardPollDuration(180).send({ from });
    await printProxy('RewardPoolUpgraded', poolProxy);
}

// We're abusing the fact that the implementation address is always stored in the same storage address.
// You could also call the admin-contracts
async function getImplementationAddress(proxyAddress) {
    return web3.eth.getStorageAt(proxyAddress, `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`);
}

async function printProxy(name, proxy) {
    console.log(name, 'proxy address:', proxy.options.address);
    console.log(name, 'implementation address:', await getImplementationAddress(proxy.options.address));
    console.log(name, 'reward config ', await proxy.methods.rewardPollDuration().call());
    console.log(name, 'stored reward  ', await proxy.methods.rewards(0).call());
}

main();
