const { time } = require('@openzeppelin/test-helpers');
const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const THXToken = contract.fromArtifact('THXToken');
const RewardPool = contract.fromArtifact('RewardPool');
const gateway = '0xF19D543f5ca6974b8b9b39Fcb923286dE4e9D975';

let token = null;
let pool = null;
let reward = null;

describe('RewardPool', function() {
    const [owner] = accounts;

    before(async () => {
        token = await THXToken.new(gateway, owner, { from: owner });
        pool = await RewardPool.new({ from: owner });

        await pool.initialize(owner, token.address);
    });

    it('can create a reward rule', async function() {
        await pool.addRewardRule({ from: owner });
    });
});
