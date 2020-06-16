const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const RewardPool = contract.fromArtifact('RewardPool');
let pool = null;

describe('RewardPool', function() {
    const [owner] = accounts;

    before(async () => {
        pool = await RewardPool.new({ from: owner });

        await pool.initialize(owner);
    });

    it('can set the owner to ' + owner, async function() {
        expect(await pool.owner()).to.equal(owner);
    });
});
