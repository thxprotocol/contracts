const Web3 = require('web3');
const { ZWeb3, ProxyAdminProject, Contracts } = require('@openzeppelin/upgrades');
const gateway = '0xF19D543f5ca6974b8b9b39Fcb923286dE4e9D975';

const web3 = new Web3('http://localhost:7545');

async function main() {
    // Set up web3 object, connected to the local development network, initialize the Upgrades library
    ZWeb3.initialize(web3.currentProvider);

    // Take the first account ganache returns as the from account.
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
    console.log('Reward Pool Admin Project is created');

    // Deploy an instance of RewardPool
    const PoolContract = Contracts.getFromLocal('RewardPool');
    // Make a change on the contract, and compile it.
    const PoolContractUpgraded = Contracts.getFromLocal('RewardPool2');

    // Create a proxy for the first contract.
    const poolProxy = await rewardPoolProject.createProxy(PoolContract, {
        from,
        initArgs: [from, token.options.address],
    });
    console.log('Reward Pool Proxy is created');

    await poolProxy.methods.proposeReward(from).send({ from });
    console.log('A reward is proposed for ', from);

    await poolProxy.methods.setRewardPollDuration(180).send({ from });
    console.log('Set rewardPollDuration to 180');
    await printProxy('* Reward Pool', poolProxy);

    console.log('Reward Pool Contract is being upgraded...');
    await rewardPoolProject.upgradeProxy(poolProxy.options.address, PoolContractUpgraded, {
        from,
    });
    console.log('Reward Pool Contract is upgraded successfully!');

    await poolProxy.methods.setRewardPollDuration(180).send({ from });
    console.log('Set rewardPollDuration to 180');
    await printProxy('* Reward Pool (Upgraded)', poolProxy);
}

// We're abusing the fact that the implementation address is always stored in the same storage address.
// You could also call the admin-contracts
async function getImplementationAddress(proxyAddress) {
    return web3.eth.getStorageAt(proxyAddress, `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`);
}

async function printProxy(name, proxy) {
    console.log('====== START PROXY LOG ======');
    console.log(name, 'proxy address: ', proxy.options.address);
    console.log(name, 'implementation address:', await getImplementationAddress(proxy.options.address));
    console.log(name, 'reward poll duration: ', await proxy.methods.rewardPollDuration().call());
    console.log(name, 'has stored reward: ', await proxy.methods.rewards(0).call());
    console.log('====== END PROXY LOG ======');

    /* --- Example output ---
    RewardPool proxy address: 0x1D9D098C28D539F71EBbB70a36d427d2f3616719
    RewardPool implementation address: 0x39d0f164bdf889c43fff8b0fb6f62841b85aedfd
    RewardPool reward config  180
    RewardPool stored reward   0x73d40EeeF625A3338ED4f85183A81C190d0A07eb
    RewardPoolUpgraded proxy address: 0x1D9D098C28D539F71EBbB70a36d427d2f3616719
    RewardPoolUpgraded implementation address: 0x9791be80c6e84c6a644138feb3082231ef7f7ef8
    RewardPoolUpgraded reward config  360
    RewardPoolUpgraded stored reward   0x73d40EeeF625A3338ED4f85183A81C190d0A07eb
    */
}

main();
