const { ZWeb3, ProxyAdminProject, Contracts } = require('@openzeppelin/upgrades');
const Web3 = require('web3');
const web3 = new Web3('http://localhost:7545'); // Asumes you have Ganache running on this port

ZWeb3.initialize(web3.currentProvider);

// Logs asset pool proxy details to confirm a successfull upgrade
async function log(name, proxy) {
    function getImplementationAddress(proxyAddress) {
        // We're abusing the fact that the implementation address is always stored in the same storage address.
        // You could also call the admin-contracts
        return web3.eth.getStorageAt(
            proxyAddress,
            `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`,
        );
    }

    console.log('====== START PROXY LOG ======');
    console.log(name, 'proxy address: ', proxy.options.address);
    console.log(name, 'implementation address:', await getImplementationAddress(proxy.options.address));
    console.log(name, 'reward poll duration: ', await proxy.methods.withdrawPollDuration().call());
    console.log(name, 'has stored withdrawal: ', await proxy.methods.withdraws(0).call());
    console.log('====== END PROXY LOG ======');
}

// Deploys the token
async function deployToken(accounts) {
    const [from] = accounts;
    const options = { from, gas: 5e6, gasPrice: 1e9 };
    const Token = Contracts.getFromLocal('THXToken');
    const tokenContract = new ZWeb3.eth.Contract(Token.schema.abi);

    return await tokenContract.deploy({ data: Token.schema.bytecode }).send(options);
}

// Deploys the asset pool
async function deployPool(accounts, token) {
    const [from] = accounts;
    const options = { from, gas: 6e6, gasPrice: 1e9 };
    const project = new ProxyAdminProject('AssetPoolProject', null, null, options);
    console.log('Asset Pool Admin Project is created');

    const PoolContract = Contracts.getFromLocal('AssetPool');

    // Create a proxy for the first contract.
    const instance = await project.createProxy(PoolContract, {
        from,
        initArgs: [from, token.options.address],
    });

    return { instance, project };
}

// Upgrades the given instance
async function upgradePool(accounts, project, instance) {
    const [from] = accounts;

    // Make a change in the AssetPool contract logic (multiply the value of
    // setWithdrawPollDuration method by 2), change the contract name to
    // AssetPoolV2 and compile it.
    const PoolContractUpgraded = Contracts.getFromLocal('AssetPoolV2');
    console.log('Asset Pool Contract is being upgraded...');

    await project.upgradeProxy(instance.options.address, PoolContractUpgraded, {
        from,
    });
    console.log('Asset Pool Contract is upgraded successfully!');
}

// Runs an upgrade test and checks if reward storage is kept
async function run() {
    const accounts = await ZWeb3.eth.getAccounts();
    const [from] = accounts;
    const options = { from, gas: 5e6, gasPrice: 1e9 };
    const token = await deployToken(accounts);
    const { instance, project } = await deployPool(accounts, token);
    console.log('Asset Pool Proxy is created');

    await token.methods.mint(instance.options.address, web3.utils.toWei('5000')).send(options);
    console.log('Asset Pool Proxy receives 5000');

    await instance.methods.setWithdrawPollDuration(180).send(options);
    console.log('Set withdrawPollDuration to 180');

    await instance.methods.addMember(accounts[1]).send(options);
    console.log('Adds member ' + accounts[1]);

    await instance.methods.proposeWithdraw(web3.utils.toWei('100'), accounts[1]).send(options);
    console.log('A reward is proposed for ' + accounts[1] + ' by ' + from);

    await log('* Asset Pool', instance);
    await upgradePool(accounts, project, instance);

    await instance.methods.setWithdrawPollDuration(180).send(options);
    console.log('Set withdrawPollDuration to 180');

    await log('* Asset Pool (Upgraded)', instance);
}

run();
